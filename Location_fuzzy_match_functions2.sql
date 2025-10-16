-- Updated rpc_match_program_current function
--
-- This function now returns a single row containing both the result items
-- and metadata (pagination, sorting, and filter details) rather than just
-- returning the result table. Replace the contents of the `base` CTE with
-- your actual query logic that produces the program rows.

create or replace function rpc_match_program_current(
  p_deal_id   bigint,
  p_filters   jsonb  default '{}'::jsonb,
  p_sort_by   text   default 'updated',
  p_sort_dir  text   default 'desc',
  p_page      int    default 1,
  p_limit     int    default 50
)
returns table (
  items        jsonb,
  total_count  int,
  page         int,
  per_page     int,
  sort_by      text,
  sort_dir     text,
  filters      jsonb,
  has_more     boolean
)
language plpgsql
as $$
declare
  v_offset   int := greatest((p_page - 1) * p_limit, 0);
  v_sort_by  text := lower(p_sort_by);
  v_sort_dir text := case when lower(p_sort_dir) = 'asc' then 'asc' else 'desc' end;
  v_items    jsonb;
  v_total    int;
  sql        text;
begin
  -- Whitelist sortable columns and map to actual column names in your query
  -- Extend this list with any additional fields you support for sorting.
  if v_sort_by = 'updated' then
    v_sort_by := 'updated_at';
  elsif v_sort_by = 'score' then
    v_sort_by := 'match_score';
  elsif v_sort_by = 'rate' then
    v_sort_by := 'rate';
  else
    v_sort_by := 'updated_at';
  end if;

  -- Build the dynamic SQL to slice, order and aggregate the results
  sql := format($q$
    with base as (
      -- =============================================================
      -- Replace this CTE with your actual selection logic. It should
      -- return all columns required for the UI, without any LIMIT or
      -- OFFSET, and should apply filtering based on p_filters as needed.
      select
        p.program_id,
        p.program_name,
        p.organization_id,
        p.organization_name,
        p.match_score,
        p.matched,
        p.match_reasons,
        p.recourse,
        p.typical_amortization,
        p.minimum_check_size,
        p.maximum_check_size,
        p.capital_stack,
        p.updated_at
      from your_source_view_or_join p
      where p.deal_id = $1
        -- optionally parse p_filters here or call helper predicates
    ),
    counted as (
      select b.*, count(*) over() as __total
      from base b
    ),
    sliced as (
      select *
      from counted
      order by %1$I %2$s, (program_id) asc
      limit $2 offset $3
    )
    select
      coalesce(jsonb_agg(to_jsonb(s) - '__total'), '[]'::jsonb) as items,
      coalesce(max(s.__total), 0)                             as total_count
    from sliced s
  $q$, v_sort_by, v_sort_dir);

  execute sql using p_deal_id, p_limit, v_offset into v_items, v_total;

  return query
  select
    coalesce(v_items, '[]'::jsonb)             as items,
    coalesce(v_total, 0)                       as total_count,
    p_page                                     as page,
    p_limit                                    as per_page,
    lower(p_sort_by)                           as sort_by,
    v_sort_dir                                 as sort_dir,
    coalesce(p_filters, '{}'::jsonb)           as filters,
    (v_offset + p_limit) < coalesce(v_total,0) as has_more;
end;
$$;

--
-- Wrapper function preserving original rpc_match_programs
-- This returns JSON items plus pagination + sorting + filters info.
create or replace function rpc_match_programs_paginated (
  p_deal_id    bigint,
  p_filters    jsonb  default '{}'::jsonb,
  p_sort_by    text   default 'updated',
  p_sort_dir   text   default 'desc',
  p_page       int    default 1,
  p_per_page   int    default 50,
  p_match_only boolean default true
)
returns table (
  items       jsonb,
  total_count int,
  page        int,
  per_page    int,
  sort_by     text,
  sort_dir    text,
  filters     jsonb,
  has_more    boolean
)
language plpgsql
as $$
declare
  v_offset int := greatest((p_page - 1) * p_per_page, 0);
  v_items jsonb;
  v_total int;
begin
  -- Pull the items for the current page
  select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
    into v_items
  from rpc_match_programs(
    p_deal_id,
    p_filters,
    p_sort_by,
    p_match_only,
    p_per_page,
    v_offset
  ) as t;

  -- Compute total matching rows by calling the original without pagination
  select count(*)
    into v_total
  from rpc_match_programs(
    p_deal_id,
    p_filters,
    p_sort_by,
    p_match_only,
    NULL,
    0
  ) as t;

  return query
  select
    v_items,
    coalesce(v_total, 0)                                as total_count,
    p_page                                              as page,
    p_per_page                                          as per_page,
    lower(p_sort_by)                                    as sort_by,
    lower(p_sort_dir)                                   as sort_dir,
    coalesce(p_filters, '{}'::jsonb)                    as filters,
    (v_offset + p_per_page) < coalesce(v_total, 0)      as has_more;
end;
$$;

-- End of updated function

--
-- helper: location_matches_address_structured
--
-- This function performs smarter location matching by first normalising the
-- free‑form property address into a space‑delimited, lower‑cased string and
-- then looking for exact word matches against the lists of states, counties
-- and metros supplied in the JSON parameter.  It avoids spurious matches
-- (e.g. "ny" matching "sunnyvale") by requiring word‑boundary matches.  A
-- trigram similarity check is also included as a fallback for cases where
-- the address may not exactly match the canonical value.  If all three
-- arrays in p_target_locs are empty, the function returns TRUE to indicate
-- there is no location filtering.
--
-- Parameters:
--   p_property_address : text   – the full free‑form address to be tested
--   p_target_locs      : jsonb  – object with keys "states", "counties",
--                                 and "metros", each containing an array of
--                                 strings to compare against
--   p_threshold        : real   – similarity threshold (0–1) used when
--                                 falling back to trigram matching
--
-- Returns: boolean indicating whether the address matches any of the
-- supplied locations.
--
create or replace function public.location_matches_address_structured(
  p_property_address    text,
  p_target_locs         jsonb,
  p_threshold           real default 0.6
)
returns boolean
language plpgsql
stable
as $$
declare
  v_states   text[] := coalesce(
    (select array_agg(lower(value::text)) from jsonb_array_elements_text(p_target_locs->'states')),
    array[]::text[]
  );
  v_counties text[] := coalesce(
    (select array_agg(lower(value::text)) from jsonb_array_elements_text(p_target_locs->'counties')),
    array[]::text[]
  );
  v_metros   text[] := coalesce(
    (select array_agg(lower(value::text)) from jsonb_array_elements_text(p_target_locs->'metros')),
    array[]::text[]
  );
  loc text;
  clean_address text;
begin
  -- normalise the address by converting to lowercase, replacing all
  -- non‑alphanumeric characters with spaces and collapsing runs of
  -- whitespace into a single space.  Surround with spaces to allow
  -- word‑boundary matching at the start/end of the string.
  clean_address := regexp_replace(lower(p_property_address), '[^a-z0-9]+', ' ', 'g');
  clean_address := ' ' || regexp_replace(clean_address, '\s+', ' ', 'g') || ' ';

  -- if no location filters are provided, treat as match
  if coalesce(array_length(v_states,1),0) = 0
     and coalesce(array_length(v_counties,1),0) = 0
     and coalesce(array_length(v_metros,1),0) = 0 then
    return true;
  end if;

  -- check for state matches
  foreach loc in array v_states loop
    if clean_address like '%' || ' ' || loc || ' ' || '%'
       or similarity(p_property_address, loc) >= p_threshold then
      return true;
    end if;
  end loop;

  -- check for county matches
  foreach loc in array v_counties loop
    if clean_address like '%' || ' ' || loc || ' ' || '%'
       or similarity(p_property_address, loc) >= p_threshold then
      return true;
    end if;
  end loop;

  -- check for metro matches
  foreach loc in array v_metros loop
    if clean_address like '%' || ' ' || loc || ' ' || '%'
       or similarity(p_property_address, loc) >= p_threshold then
      return true;
    end if;
  end loop;
  return false;
end;
$$;

--
-- helper: sponsor_location_matches_fuzzy
--
-- Performs a straightforward comparison between two free‑form sponsor location
-- strings.  It returns TRUE if the required location is a substring of the
-- deal's sponsor location or if the trigram similarity between the two
-- strings meets or exceeds the provided threshold.  If the required
-- location is NULL or empty, the function returns TRUE to indicate the
-- program does not filter on sponsor location.
--
-- Parameters:
--   p_deal_sponsor_location     text – sponsor location from the deal
--   p_required_sponsor_location text – location requirement from the program
--   p_threshold                 real – similarity threshold for fallback
--
-- Returns: boolean
--
create or replace function public.sponsor_location_matches_fuzzy(
  p_deal_sponsor_location     text,
  p_required_sponsor_location text,
  p_threshold                 real default 0.4
)
returns boolean
language sql
stable
as $$
  select coalesce(
    (
      lower(p_required_sponsor_location) is null or lower(p_required_sponsor_location) = ''
      or strpos(lower(p_deal_sponsor_location), lower(p_required_sponsor_location)) > 0
      or similarity(p_deal_sponsor_location, p_required_sponsor_location) >= p_threshold
    ), true
  );
$$;
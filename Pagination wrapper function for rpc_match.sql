-- Pagination wrapper function for rpc_match_programs
-- Adds total count, pagination metadata, and enhanced filtering/sorting

create or replace function rpc_match_programs_paginated(
  p_deal_id bigint,
  p_filters jsonb default '{}'::jsonb,   -- UI filters (recourse, amortization, cltc_pct, tpe_pct, etc.)
  p_sort_by text default 'updated',      -- 'updated'|'rate'|'score'|'name'|'organization'
  p_match_only boolean default true,     -- if true, only return programs that fully match all criteria
  p_page int default 1,                  -- page number (1-based)
  p_page_size int default 100            -- items per page
)
returns jsonb
language plpgsql
SECURITY DEFINER
stable
as $$
declare
  v_offset int;
  v_total_count int;
  v_total_pages int;
  v_has_next_page boolean;
  v_has_prev_page boolean;
  v_results jsonb;
  v_programs jsonb[];
  v_program_record record;
begin
  -- Calculate offset
  v_offset := (p_page - 1) * p_page_size;
  
  -- Validate inputs
  if p_page < 1 then
    p_page := 1;
    v_offset := 0;
  end if;
  
  if p_page_size < 1 then
    p_page_size := 100;
  end if;
  
  if p_page_size > 10000 then
    p_page_size := 10000; -- Max page size limit
  end if;

  -- Get total count first (without pagination)
  select count(*)
  into v_total_count
  from rpc_match_programs(
    p_deal_id := p_deal_id,
    p_filters := p_filters,
    p_sort_by := p_sort_by,
    p_match_only := p_match_only,
    p_limit := 9999999,  -- Large number to get all results for counting
    p_offset := 0
  );

  -- Calculate pagination metadata
  v_total_pages := ceil(v_total_count::numeric / p_page_size::numeric)::int;
  v_has_next_page := p_page < v_total_pages;
  v_has_prev_page := p_page > 1;

  -- Get the actual paginated results
  v_programs := array[]::jsonb[];
  
  for v_program_record in
    select *
    from rpc_match_programs(
      p_deal_id := p_deal_id,
      p_filters := p_filters,
      p_sort_by := p_sort_by,
      p_match_only := p_match_only,
      p_limit := p_page_size,
      p_offset := v_offset
    )
    order by p_sort_by
  loop
    v_programs := v_programs || jsonb_build_object(
      'program_id', v_program_record.program_id,
      'program_name', v_program_record.program_name,
      'organization_id', v_program_record.organization_id,
      'organization_name', v_program_record.organization_name,
      'organization_hq_location', v_program_record.organization_hq_location,
      'match_score', v_program_record.match_score,
      'matched', v_program_record.matched,
      'match_reasons', v_program_record.match_reasons,
      'recourse', v_program_record.recourse,
      'typical_amortization', v_program_record.typical_amortization,
      'minimum_check_size', v_program_record.minimum_check_size,
      'maximum_check_size', v_program_record.maximum_check_size,
      'capital_stack', v_program_record.capital_stack,
      'updated_at', v_program_record.updated_at,
      'extra', v_program_record.extra
    );
  end loop;

  -- Build the final response
  v_results := jsonb_build_object(
    'data', v_programs,
    'pagination', jsonb_build_object(
      'page', p_page,
      'page_size', p_page_size,
      'total_count', v_total_count,
      'total_pages', v_total_pages,
      'has_next_page', v_has_next_page,
      'has_prev_page', v_has_prev_page,
      'offset', v_offset
    ),
    'filters', jsonb_build_object(
      'applied_filters', p_filters,
      'sort_by', p_sort_by,
      'match_only', p_match_only
    ),
    'meta', jsonb_build_object(
      'deal_id', p_deal_id,
      'generated_at', now(),
      'matched_count', (
        select count(*) 
        from unnest(v_programs) as program_json
        where (program_json->>'matched')::boolean = true
      ),
      'total_candidates', v_total_count
    )
  );

  return v_results;
end;
$$;

SELECT rpc_match_programs_paginated(
  p_deal_id := 26,
  p_filters := '{}'::jsonb,
  p_sort_by := 'updated',
  p_match_only := true,
  p_page := 1,
  p_page_size := 20
);

-- Companion function to get just pagination metadata (useful for UI)
create or replace function rpc_match_programs_pagination_info(
  p_deal_id bigint,
  p_filters jsonb default '{}'::jsonb,
  p_match_only boolean default true,
  p_page int default 1,
  p_page_size int default 100
)
returns jsonb
language plpgsql
SECURITY DEFINER
stable
as $$
declare
  v_total_count bigint;
  v_total_pages int;
  v_matched_count bigint;
begin
  -- Validate inputs
  if p_page < 1 then p_page := 1; end if;
  if p_page_size < 1 then p_page_size := 100; end if;
  if p_page_size > 1000 then p_page_size := 1000; end if;

  -- Get total count
  select count(*)
  into v_total_count
  from rpc_match_programs(
    p_deal_id := p_deal_id,
    p_filters := p_filters,
    p_sort_by := 'updated',
    p_match_only := p_match_only,
    p_limit := 999999,
    p_offset := 0
  );

  -- Get matched count (if showing all candidates)
  if not p_match_only then
    select count(*)
    into v_matched_count
    from rpc_match_programs(
      p_deal_id := p_deal_id,
      p_filters := p_filters,
      p_sort_by := 'updated',
      p_match_only := true,
      p_limit := 999999,
      p_offset := 0
    );
  else
    v_matched_count := v_total_count;
  end if;

  v_total_pages := ceil(v_total_count::numeric / p_page_size::numeric)::int;

  return jsonb_build_object(
    'total_count', v_total_count,
    'matched_count', v_matched_count,
    'total_pages', v_total_pages,
    'current_page', p_page,
    'page_size', p_page_size,
    'has_next_page', p_page < v_total_pages,
    'has_prev_page', p_page > 1,
    'offset', (p_page - 1) * p_page_size,
    'showing_matches_only', p_match_only
  );
end;
$$;

-- Grant permissions
-- GRANT EXECUTE ON FUNCTION rpc_match_programs_with_pagination TO authenticated;
-- GRANT EXECUTE ON FUNCTION rpc_match_programs_pagination_info TO authenticated;

-- Example usage:
/*
-- Get paginated results with metadata in each row
SELECT * FROM rpc_match_programs_with_pagination(
  p_deal_id := 123,
  p_filters := '{"recourse": ["Full Recourse"]}'::jsonb,
  p_sort_by := 'score',
  p_sort_order := 'desc',
  p_page := 1,
  p_page_size := 20
);

-- Get just pagination info (useful for UI pagination controls)
SELECT rpc_match_programs_pagination_info(
  p_deal_id := 123,
  p_filters := '{"recourse": ["Full Recourse"]}'::jsonb,
  p_match_only := true,
  p_page := 1,
  p_page_size := 20
);
*/

create or replace function rpc_match_programs(
  p_deal_id bigint,
  p_filters jsonb default '{}'::jsonb,   -- UI filters (recourse, amortization, cltc_pct, tpe_pct, etc.)
  p_sort_by text default 'updated',      -- 'updated'|'rate'|'score'
  p_match_only boolean default true,  -- if true, only return programs that fully match all criteria; if false, return all candidates with match score
  p_limit int default 100
)
returns table (
  program_id            bigint,
  program_name          text,
  organization_id       bigint,
  organization_name     text,
  organization_hq_location     text,
  match_score           numeric,
  matched               boolean,
  match_reasons         jsonb,
  recourse              text,
  typical_amortization  text[],
  minimum_check_size    numeric,
  maximum_check_size    numeric,
  capital_stack         text[],
  updated_at            timestamptz,
  extra                 jsonb
)
language sql
stable
as $$
with
-- load the deal
deal as (
  select d.*
  from deals d
  where d.id = p_deal_id
),

-- simple filter extraction from UI
filters as (
  select
    (p_filters ->> 'recourse')     as recourse_filter,
    (p_filters ->> 'amortization') as amortization_filter,
    nullif(trim(coalesce(p_filters ->> 'cltc_pct', '')), '')::numeric  as cltc_pct,  -- fraction, e.g. 0.25
    nullif(trim(coalesce(p_filters ->> 'tpe_pct', '')), '')::numeric   as tpe_pct
),

-- candidates: attach program row + program_extra JSON, and map deal columns with safe aliases
candidates as (
  select
    p.id                                       as p_id,
    p.name                                     as p_name,
    p.organization_id                          as p_org_id,
    o.name                                     as p_org_name,
    o.hq_location                              as p_org_location,
    p.recourse                                 as p_recourse,
    p.typical_amortization                     as p_typical_amortization,
    p.minimum_check_size                       as p_minimum_check_size,
    p.maximum_check_size                       as p_maximum_check_size,
    p.capital_stack                            as p_capital_stack,
    p.updated_at                               as p_updated_at,

    -- program fields used by rules (adjust names if your schema differs)
    coalesce(p.transaction_types, ARRAY[]::text[])          as p_transaction_types,
    coalesce(p.target_property_locations, '{}'::jsonb)      as p_target_property_locations,
    -- coalesce(p.program_asset_types, ARRAY[]::text[])     as p_program_asset_types,  -- this is actually a many-to-many link table in program_asset_types table TODO
    p.investment_strategy                                   as p_investment_strategy,
    p.commercial_tenancy                                    as p_commercial_tenancy,
    p.hotel_flag_required                                   as p_hotel_flag_required,
    p.hotel_flag_list                                       as p_hotel_flag_list,
    p.guarantor_type                                        as p_guarantor_type,
    p.sponsor_location_req                                  as p_sponsor_location_req,
    p.sponsor_experience_level                              as p_sponsor_experience_level,
    p.min_net_worth                                         as p_min_net_worth,
    p.min_net_worth_ratio                                   as p_min_net_worth_ratio,
    p.min_liquidity                                         as p_min_liquidity,
    p.min_liquidity_ratio                                   as p_min_liquidity_ratio,
    p.maximum_ltc                                           as p_maximum_ltc,
    p.sponsor_aum_req                                       as p_sponsor_aum_req,
    p.min_credit_score                                      as p_min_credit_score,
    p.us_citizenship_required                               as p_us_citizenship_required,
 
    pe.extra as p_extra,

    -- deal fields (explicit aliases)
    d.financing_type            as d_financing_type,          -- text[]
    d.property_address          as d_property_address,
    d.asset_type                as d_asset_type,              -- text[]
    d.investment_strategy       as d_investment_strategy,
    d.tenancy                   as d_tenancy,
    d.hotel_type                as d_hotel_type,
    d.guarantor_type            as d_guarantor_type,
    d.sponsor_location          as d_sponsor_location,
    d.experience_level          as d_experience_level,
    d.net_worth                 as d_net_worth,
    d.value                     as d_value,
    d.liquidity                 as d_liquidity,
    d.assets_under_management   as d_assets_under_management,
    d.credit_score              as d_credit_score,
    d.us_citizenship            as d_us_citizenship,

    -- previously-defined UI filters
    f.recourse_filter,
    f.amortization_filter,
    f.cltc_pct,
    f.tpe_pct

  from programs p
  left join organizations o on p.organization_id = o.id
  left join program_extra pe on pe.id = p.id
  cross join deal d
  cross join filters f
)

select
  c.p_id                   as program_id,
  c.p_name                 as program_name,
  c.p_org_id               as organization_id,
  c.p_org_name             as organization_name,
  c.p_org_location         as organization_hq_location,
  
  -- MATCH SCORE: count of true booleans among the checks (raw integer count; there are 17 checks)
  (
    (case when c.recourse_ok then 1 else 0 end)
  + (case when c.amortization_ok then 1 else 0 end)
  + (case when c.fits_cltc and c.sizing_filter_provided then 1 else 0 end)
  + (case when c.fits_tpe and c.sizing_filter_provided then 1 else 0 end)
----------------------- END of FILTERS, BEGIN RULES -----------------------
  + (case when c.financing_ok then 1 else 0 end)
  + (case when c.location_ok then 1 else 0 end)
  + (case when c.asset_type_ok then 1 else 0 end)
  + (case when c.investment_strategy_ok then 1 else 0 end)
  + (case when c.tenancy_ok then 1 else 0 end)
  + (case when c.hotel_ok then 1 else 0 end)
  + (case when c.guarantor_ok then 1 else 0 end)
  + (case when c.sponsor_location_ok then 1 else 0 end)
  + (case when c.experience_ok then 1 else 0 end)
  + (case when c.net_worth_ok then 1 else 0 end)
  + (case when c.liquidity_ok then 1 else 0 end)
  + (case when c.liquidity_ratio_ok then 1 else 0 end)
  + (case when c.aum_ok then 1 else 0 end)
  + (case when c.credit_ok then 1 else 0 end)
  + (case when c.us_citizenship_ok then 1 else 0 end)
  )::numeric as match_score,

  -- final matched decision: must satisfy all boolean checks below (plus recourse/amortization)
  (
    c.recourse_ok
    and c.amortization_ok
    and (
      -- if the UI supplied either sizing pct, require at least one sizing path to match
      (not c.sizing_filter_provided) OR (c.fits_cltc OR c.fits_tpe)
    )
----------------------- END of FILTERS, BEGIN RULES -----------------------
    and c.financing_ok
    and c.location_ok
    and c.asset_type_ok
    and c.investment_strategy_ok
    and c.tenancy_ok
    and c.hotel_ok
    and c.guarantor_ok
    and c.sponsor_location_ok
    and c.experience_ok
    and c.net_worth_ok
    and c.liquidity_ok
    and c.liquidity_ratio_ok
    and c.aum_ok
    and c.credit_ok
    and c.us_citizenship_ok
  ) as matched,

  -- structured reasons: each boolean below is spelled out for the UI
  jsonb_build_object(
    'recourse_ok',             c.recourse_ok,
    'amortization_ok',         c.amortization_ok,
    'fits_cltc',               c.fits_cltc,
    'fits_tpe',                c.fits_tpe,
----------------------- END of FILTERS, BEGIN RULES -----------------------
    'financing_ok',            c.financing_ok,
    'location_ok',             c.location_ok,
    'asset_type_ok',           c.asset_type_ok,
    'investment_strategy_ok',  c.investment_strategy_ok,
    'tenancy_ok',              c.tenancy_ok,
    'hotel_ok',                c.hotel_ok,
    'guarantor_ok',            c.guarantor_ok,
    'sponsor_location_ok',     c.sponsor_location_ok,
    'experience_ok',           c.experience_ok,
    'net_worth_ok',            c.net_worth_ok,
    'liquidity_ok',            c.liquidity_ok,
    'liquidity_ratio_ok',      c.liquidity_ratio_ok,
    'aum_ok',                  c.aum_ok,
    'credit_ok',               c.credit_ok,
    'us_citizenship_ok',       c.us_citizenship_ok
  ) as match_reasons,

  c.p_recourse              as recourse,
  c.p_typical_amortization  as typical_amortization,
  c.p_minimum_check_size    as minimum_check_size,
  c.p_maximum_check_size    as maximum_check_size,
  c.p_capital_stack         as capital_stack,
  c.p_updated_at            as updated_at,
  -- use the prebuilt JSON blob from program_extra view (contains the program fields you listed)
  c.p_extra                 as extra

from (
  -- compute every boolean here so the outer select stays tidy
  select
    *,
    -- program filters from UI
    -- recourse filter exact-match (if provided array)
    (case
      when recourse_filter is null then true
      else lower(coalesce(p_recourse, '')) = ANY(
        ARRAY(
          SELECT lower(x)
          FROM jsonb_array_elements_text(recourse_filter::jsonb) x
        )
      )
    end) as recourse_ok,

    -- amortization exact-match (if provided)
    (case
       when amortization_filter is null then true
       else (lower(amortization_filter) = any(array(select lower(x) from unnest(coalesce(p_typical_amortization, ARRAY[]::text[])) x)))
    end) as amortization_ok,

    -- sizing: computed amounts and booleans
    (coalesce(cltc_pct,0) * coalesce(d_value,0)) as calculated_cltc_amount,
    (coalesce(tpe_pct,0)  * coalesce(d_value,0)) as calculated_tpe_amount,

    -- whether user supplied any sizing filter
    (cltc_pct IS NOT NULL OR tpe_pct IS NOT NULL) as sizing_filter_provided,

    -- fits CLTC if user provided a cltc_pct AND program has Senior AND check fits within min/max
    (
      CASE
        WHEN cltc_pct IS NULL THEN
          (coalesce(d_value, 0) > coalesce(p_minimum_check_size, 0)
           AND coalesce(d_value, 0) < coalesce(p_maximum_check_size, 0))
        ELSE
          (cltc_pct IS NOT NULL)
          AND ('Senior' = ANY(coalesce(p_capital_stack, ARRAY[]::text[])))
          AND (coalesce(p_maximum_check_size, 0) >= (coalesce(cltc_pct, 0) * coalesce(d_value, 0)))
          AND (coalesce(p_minimum_check_size, 0) <= (coalesce(cltc_pct, 0) * coalesce(d_value, 0)))
          -- CLTC value itself should be less than or equal to the program's given LTC if that program is matching on a Senior position.
          AND (coalesce(cltc_pct, 0) <= coalesce(p_maximum_ltc, 0))
      END
    ) as fits_cltc,

    -- fits Third Party Equity if user provided tpe_pct AND program has Equity AND check fits
    (
      (tpe_pct IS NOT NULL)
      AND ('Equity' = ANY(coalesce(p_capital_stack, ARRAY[]::text[])))
      AND (coalesce(p_maximum_check_size, 0) >= (coalesce(tpe_pct,0)  * coalesce(d_value,0)))
      AND (coalesce(p_minimum_check_size, 0) <= (coalesce(tpe_pct,0)  * coalesce(d_value,0)))
    ) as fits_tpe,

----------------------- END of FILTERS, BEGIN RULES -----------------------

    -- financing_type: if p_transaction_types is empty or null, the program matches all financing types; otherwise, arrays must overlap
    (
      (p_transaction_types IS NULL OR cardinality(p_transaction_types) = 0)
      OR (d_financing_type IS NULL OR cardinality(d_financing_type) = 0)
      OR (coalesce(d_financing_type, ARRAY[]::text[]) && coalesce(p_transaction_types, ARRAY[]::text[]))
    ) as financing_ok,

   -- property location: if program target list empty -> match, otherwise check city OR county OR state
    (
      (jsonb_array_length(coalesce(p_target_property_locations, '[]'::jsonb)) = 0)
      OR true  -- IGNORE location matching for now TODO
      -- This needs much better logic since p_target_property_locations is a JSONB array of objects with city/county/state fields
      -- OR (
      --    (coalesce(d_property_city,'') <> '' AND lower(coalesce(d_property_city,'')) = any (array(select lower(x) from unnest(coalesce(p_target_property_locations, ARRAY[]::text[])) x)))
      --    OR (coalesce(d_property_county,'') <> '' AND lower(coalesce(d_property_county,'')) = any (array(select lower(x) from unnest(coalesce(p_target_property_locations, ARRAY[]::text[])) x)))
      --    OR (coalesce(d_property_state,'') <> '' AND lower(coalesce(d_property_state,'')) = any (array(select lower(x) from unnest(coalesce(p_target_property_locations, ARRAY[]::text[])) x)))
      -- )
    ) as location_ok,

    -- asset type: this is actually a many-to-many link table in program_asset_types table, so we skip this rule for now, since table is still empty TODO
    true as asset_type_ok,
    -- asset_type: program empty => match, otherwise any overlap
    -- (
    --   (array_length(coalesce(p_program_asset_types, ARRAY[]::text[]),1) = 0)
    --   OR (coalesce(d_asset_type, ARRAY[]::text[]) && coalesce(p_program_asset_types, ARRAY[]::text[]))
    -- ) as asset_type_ok,

    -- investment strategy: match if either side empty OR exact equality
    (
      (coalesce(p_investment_strategy,'') = '')
      OR (coalesce(d_investment_strategy,'') = '')
      OR (lower(p_investment_strategy) = lower(d_investment_strategy))
    ) as investment_strategy_ok,

    -- tenancy: program empty => match, otherwise equality to any allowed tenancy
    (
      (coalesce(p_commercial_tenancy,'') = '')
      OR (lower(coalesce(p_commercial_tenancy,'')) = 'any') 
      OR (coalesce(d_tenancy,'') = '')
      OR (lower(p_commercial_tenancy) = lower(d_tenancy))
    ) as tenancy_ok,

    -- hotel rule: if program requires hotel_flag and deal hotel_type is 'Boutique' => fail
    (
      (p_hotel_flag_required IS NOT TRUE) -- flag not required -> OK
      OR (coalesce(lower(d_hotel_type),'') <> 'boutique') -- not boutique -> OK
    ) as hotel_ok,

    -- guarantor rule: if deal is Corporation require program to include Corporation (string search tolerant)
    (
      (lower(coalesce(d_guarantor_type,'')) <> 'corporation')
      OR (
        lower(coalesce(d_guarantor_type,'')) = 'corporation'
        AND (coalesce(p_guarantor_type::text,'') ~~* '%corporation%') -- ~~* is an ILIKE match (case insensitive, substring)
      )
    ) as guarantor_ok,

    -- sponsor location: if program blank => match, else check sponsor city/county/state against sponsor_location_req
    (
      true  -- IGNORE sponsor location matching for now TODO
      -- This needs much better logic since p_sponsor_location_req is a JSONB array of objects with city/county/state fields
      -- OR (
      --    (coalesce(d_sponsor_city,'') <> '' AND lower(coalesce(d_sponsor_city,'')) = any(array(select lower(x) from unnest(coalesce(p_sponsor_location_req, ARRAY[]::text[])) x)))
      --    OR (coalesce(d_sponsor_county,'') <> '' AND lower(coalesce(d_sponsor_county,'')) = any(array(select lower(x) from unnest(coalesce(p_sponsor_location_req, ARRAY[]::text[])) x)))
      --    OR (coalesce(d_sponsor_state,'') <> '' AND lower(coalesce(d_sponsor_state,'')) = any(array(select lower(x) from unnest(coalesce(p_sponsor_location_req, ARRAY[]::text[])) x)))
      -- )
    ) as sponsor_location_ok,

    -- experience level: if program blank => match, if deal blank => match, else exact match
    (
      (coalesce(p_sponsor_experience_level,'') = '')
      OR (coalesce(d_experience_level,'') = '')
      OR (p_sponsor_experience_level = d_experience_level)
    ) as experience_ok,

    -- net worth: if deal.net_worth is null => match. Else enforce both absolute and ratio if program requires them.
    (
      (d_net_worth IS NULL)
        OR (
          (p_min_net_worth IS NULL OR (coalesce(parse_money_to_numeric(d_net_worth), 0) >= p_min_net_worth))
          AND (p_min_net_worth_ratio IS NULL OR ((coalesce(parse_money_to_numeric(d_net_worth), 0) * coalesce(d_value,0)) >= coalesce(parse_money_to_numeric(p_min_net_worth_ratio), 0)))
        )
    ) as net_worth_ok,

    -- liquidity absolute: if either side null => match, else require liquidity > min
    (
      (d_liquidity IS NULL) OR (p_min_liquidity IS NULL) OR (coalesce(parse_money_to_numeric(d_liquidity), 0) > p_min_liquidity)
    ) as liquidity_ok,

    -- liquidity ratio: if either side null => match, else require liquidity * value > min ratio
    (
      (d_liquidity IS NULL) OR (p_min_liquidity_ratio IS NULL) OR ( (coalesce(parse_money_to_numeric(d_liquidity), 0) * coalesce(d_value,0)) > coalesce(parse_money_to_numeric(p_min_liquidity_ratio), 0))
    ) as liquidity_ratio_ok,

    -- assets under management (AUM)
    (
      (d_assets_under_management IS NULL) OR (p_sponsor_aum_req IS NULL) OR (d_assets_under_management > coalesce(parse_money_to_numeric(p_sponsor_aum_req), 0))
    ) as aum_ok,

    -- credit score: if deal null => match; else require >= min_credit_score if set
    (
      (d_credit_score IS NULL) OR (p_min_credit_score IS NULL) OR (coalesce(parse_money_to_numeric(d_credit_score), 0) >= p_min_credit_score)
    ) as credit_ok,

    -- US citizenship: if deal.us_citizenship = false then program must not require US citizenship
    (
      (d_us_citizenship IS NULL)  -- deal not specified -> OK
      OR (d_us_citizenship::boolean = false AND coalesce(p_us_citizenship_required, false) = false)  -- deal false -> program must be false or null
    ) as us_citizenship_ok

  from candidates
) c

where
  -- only return programs that satisfy the filtering boolean set (you can remove this WHERE to return near-misses)
  (
    c.recourse_ok
    and c.amortization_ok
    and (
      -- if the UI supplied either sizing pct, require at least one sizing path to match
      (not c.sizing_filter_provided) OR (c.fits_cltc OR c.fits_tpe)
    )
    and c.financing_ok
    and c.location_ok
    and c.asset_type_ok
    and c.investment_strategy_ok
    and c.tenancy_ok
    and c.hotel_ok
    and c.guarantor_ok
    and c.sponsor_location_ok
    and c.experience_ok
    and c.net_worth_ok
    and c.liquidity_ok
    and c.liquidity_ratio_ok
    and c.aum_ok
    and c.credit_ok
    and c.us_citizenship_ok
  ) or (not p_match_only)  -- if p_match_only is false, return all candidates

order by

  -- then sort by updated (MVP), newest first
  case when true then -- p_sort_by = 'updated'
    (
      (case when c.recourse_ok then 1 else 0 end)
    + (case when c.amortization_ok then 1 else 0 end)
    + (case when c.fits_cltc and c.sizing_filter_provided then 1 else 0 end)
    + (case when c.fits_tpe and c.sizing_filter_provided then 1 else 0 end)

    + (case when c.financing_ok then 1 else 0 end)
    + (case when c.location_ok then 1 else 0 end)
    + (case when c.asset_type_ok then 1 else 0 end)
    + (case when c.investment_strategy_ok then 1 else 0 end)
    + (case when c.tenancy_ok then 1 else 0 end)
    + (case when c.hotel_ok then 1 else 0 end)
    + (case when c.guarantor_ok then 1 else 0 end)
    + (case when c.sponsor_location_ok then 1 else 0 end)
    + (case when c.experience_ok then 1 else 0 end)
    + (case when c.net_worth_ok then 1 else 0 end)
    + (case when c.liquidity_ok then 1 else 0 end)
    + (case when c.liquidity_ratio_ok then 1 else 0 end)
    + (case when c.aum_ok then 1 else 0 end)
    + (case when c.credit_ok then 1 else 0 end)
    + (case when c.us_citizenship_ok then 1 else 0 end)
    ) end desc nulls last,
  
  c.p_updated_at desc nulls last,

  c.p_id
limit p_limit;
$$;

-- select
--   *
-- from
--   deals d
--   cross join lateral rpc_match_programs (d.id)
-- order by
--   d.id,
--   program_id;

select * from rpc_match_programs(30);

-- select * 
-- from rpc_match_programs(
--   p_deal_id := 26,
--   p_filters := '{"recourse":"Non-Recourse","amortization":"25"}',
--   p_sort_by := 'updated',
--   p_limit := 100
-- );


create or replace function parse_money_to_numeric(txt text)
returns numeric
language plpgsql
immutable
as $$
declare
  s text;
  part text;
  num text;
  multiplier numeric := 1;
  res numeric;
begin
  if txt is null then
    return null;
  end if;

  -- Normalize dashes (en/em) to ASCII hyphen and remove common currency/chars
  s := txt;
  s := regexp_replace(s, E'\\u2013|\\u2014', '-', 'g');   -- en/em dash -> hyphen
  s := regexp_replace(s, '[\$\£\€\₹,]', '', 'g');        -- remove currency symbols and commas
  s := lower(trim(s));

  -- If it's a range, take the left/lowest bound (policy choice; change if you prefer average)
  if s ~ '-' then
    part := split_part(s, '-', 1);
  elsif s ~ '\sto\s' then
    part := split_part(s, ' to ', 1);
  else
    part := s;
  end if;

  part := trim(part);

  -- Handle words like "million" "bn" "k" as suffixes
  -- Normalize long words into single-letter suffixes
  part := regexp_replace(part, '\s*million\b', 'm', 'gi');
  part := regexp_replace(part, '\s*billion\b', 'b', 'gi');
  part := regexp_replace(part, '\s*thousand\b', 'k', 'gi');

  -- detect multiplier suffix (k,m,b)
  if part ~ '[kmbr]$' then
    case right(part,1)
      when 'k' then multiplier := 1000;
      when 'm' then multiplier := 1000000;
      when 'b' then multiplier := 1000000000;
      when 'r' then multiplier := 1; -- in case a weird suffix; keep as-is
      else multiplier := 1;
    end case;
    part := left(part, char_length(part) - 1);
  end if;

  -- Remove any non-digit / non-dot left
  num := regexp_replace(part, '[^0-9\.]', '', 'g');

  if num = '' then
    return null;
  end if;

  -- Try convert; return null on failure
  begin
    res := (num::numeric) * multiplier;
    return res;
  exception when others then
    return null;
  end;

end;
$$;


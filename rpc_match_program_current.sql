-- v2: safe, backward-compatible variant of rpc_match_programs with improved null/empty handling,
-- asset_type id-based matching, open-ended sizing constraints, US citizenship permissive when unknown,
-- amortization/recourse edge cases, parsing guards, and p_sort_by implementation.
-- Original comments and structure retained; changes are annotated with -- [v2 change: ...]
create or replace function rpc_match_programs(
  p_deal_id bigint,
  p_filters jsonb default '{}'::jsonb,   -- UI filters (recourse, amortization, capital stack sliders, etc.)
  p_sort_by text default 'updated',      -- 'updated'|'score'|'check_size'|'soft_spot'
  p_match_only boolean default true,     -- if true, only return programs that fully match all criteria; if false, return all candidates with match score
  p_limit int default 100,
  p_offset int default 0
)
returns table (
  program_id            bigint,
  program_name          text,
  organization_id       bigint,
  organization_name     text,
  organization_hq_location     text,
  match_score           integer,
  matched               boolean,
  match_reasons         jsonb,
  d_asset_type          text[],           -- from deal (kept for backward compatibility; informational)
  p_program_asset_types text[],           -- from program (kept for backward compatibility; informational)
  recourse              text,
  typical_amortization  text[],
  minimum_check_size    numeric,
  maximum_check_size    numeric,
  capital_stack         text[],
  updated_at            timestamptz,
  extra                 jsonb
)
language sql
security definer
stable
as $$
/* NOTE: This function is based on the original rpc_match_programs with the following v2 improvements:
   - [v2 change] Robust handling of NULL/empty filters and program values (sizing, amortization, LTC, etc.)
   - [v2 change] Asset type matching now uses asset_types IDs via deal_asset_types and program_asset_types (no string matching)
   - [v2 change] Sizing comparisons are open-ended when program min/max are NULL (ignore missing bound)
   - [v2 change] US citizenship logic is permissive when unknown
   - [v2 change] Money parsing avoids forcing 0 on parse failures; use permissive logic explicitly
   - [v2 change] Implement p_sort_by: 'updated' (default), 'score', 'check_size', and 'soft_spot' (starter heuristic)
   - [v2 change] Keep original comments; added v2 comments where changes were applied
*/

with
-- load the deal
deal as (
  select d.*
  from deals d
  where d.id = p_deal_id
),

-- [v2 change] Normalize filters once; treat NULL p_filters as '{}'
params as (
  select coalesce(p_filters, '{}'::jsonb) as pf
),

-- simple filter extraction from UI
filters as (
  select
    (pf -> 'recourse')::jsonb                         as recourse_filter_json,   -- may be array or null
    (pf ->> 'amortization')                           as amortization_filter,
    -- [v3 change] New capital stack slider inputs (percentages as integers, e.g. 46 = 46%)
    nullif(trim(coalesce(pf ->> 'Senior_input', '')), '')::numeric       as senior_pct,
    nullif(trim(coalesce(pf ->> 'Subordinate_input', '')), '')::numeric  as subordinate_pct,
    nullif(trim(coalesce(pf ->> 'Equity_input', '')), '')::numeric       as equity_pct,
    -- [v3 change] Toggle flags for each capital stack type
    coalesce((pf ->> 'Senior_toggle')::boolean, false)      as senior_toggle,
    coalesce((pf ->> 'Subordinate_toggle')::boolean, false) as subordinate_toggle,
    coalesce((pf ->> 'Equity_toggle')::boolean, false)      as equity_toggle,
    -- [v3 change] Checkbox flags for specific capital stack types
    -- Each checkbox is independently controllable; if not provided, defaults to false
    coalesce((pf ->> 'Senior_Line_of_Credit_checkbox')::boolean, false) as senior_loc_cb,
    coalesce((pf ->> 'Senior_Senior_Commercial_Mortgage_checkbox')::boolean, false) as senior_scm_cb,
    coalesce((pf ->> 'Subordinate_Mezzanine_checkbox')::boolean, false) as sub_mezz_cb,
    coalesce((pf ->> 'Subordinate_Preferred_Equity_checkbox')::boolean, false) as sub_pref_cb,
    coalesce((pf ->> 'Equity_Co-GP_Equity_checkbox')::boolean, false) as eq_cogp_cb,
    coalesce((pf ->> 'Equity_LP_Equity_checkbox')::boolean, false) as eq_lp_cb,
    coalesce((pf ->> 'Equity_PACE_checkbox')::boolean, false) as eq_pace_cb,
    coalesce((pf ->> 'Equity_Ground_Lease_Buyer_checkbox')::boolean, false) as eq_glb_cb
  from params
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
    coalesce(p.transaction_types, ARRAY[]::text[])     as p_transaction_types,
    coalesce(p.target_property_locations, '{}'::jsonb) as p_target_property_locations,

    -- [v2 change] Keep original string array for backward compatibility in output (p_program_asset_types),
    -- but we will use id-based arrays for matching below.
    (
      SELECT coalesce(array_agg(at.name)::text[], ARRAY[]::text[])
      FROM program_asset_types pat
      JOIN asset_types at ON pat.asset_type_id = at.id
      where pat.program_id = p.id
    )                                                 as p_program_asset_types,

    -- [v2 change] Asset type IDs for program (used for matching)
    (
      select coalesce(array_agg(pat.asset_type_id)::int2[], ARRAY[]::int2[])
      from program_asset_types pat
      where pat.program_id = p.id
    )                                                 as p_program_asset_type_ids,

    p.investment_strategy                             as p_investment_strategy,
    p.commercial_tenancy                              as p_commercial_tenancy,
    p.hotel_flag_required                             as p_hotel_flag_required,
    p.hotel_flag_list                                 as p_hotel_flag_list,
    p.guarantor_type                                  as p_guarantor_type,
    p.sponsor_location_req                            as p_sponsor_location_req,
    p.sponsor_experience_level                        as p_sponsor_experience_level,
    p.min_net_worth                                   as p_min_net_worth,
    p.min_net_worth_ratio                             as p_min_net_worth_ratio,
    p.min_liquidity                                   as p_min_liquidity,
    p.min_liquidity_ratio                             as p_min_liquidity_ratio,
    p.maximum_ltc                                     as p_maximum_ltc,
    p.sponsor_aum_req                                 as p_sponsor_aum_req,
    p.min_credit_score                                as p_min_credit_score,
    p.us_citizenship_required                         as p_us_citizenship_required,
    pe.extra                                          as p_extra,

    -- deal fields (explicit aliases)
    coalesce(d.financing_type, ARRAY[]::text[])             as d_financing_type,  -- text[]
    d.property_address                                      as d_property_address,
    d.city_town_village_locality_of_property_address        as d_city_town_village_locality_of_property_address,
    d.state_county_of_property_address                      as d_state_county_of_property_address,
    d.region_of_property_address                            as d_region_of_property_address,
    d.zip_postal_code_of_property_address                   as d_zip_postal_code_of_property_address,
    d.sponsor_location                                      as d_sponsor_location,
    d.city_town_village_locality_of_sponsor_location        as d_city_town_village_locality_of_sponsor_location,
    d.state_county_of_sponsor_location                      as d_state_county_of_sponsor_location,
    d.region_of_sponsor_location                            as d_region_of_sponsor_location,
    d.zip_postal_code_of_sponsor_location                   as d_zip_postal_code_of_sponsor_location,
    coalesce(d.asset_type, ARRAY[]::text[])                 as d_asset_type,  -- text[] (legacy informational)
    -- [v2 change] Asset type IDs for deal (used for matching)
    (
      select coalesce(array_agg(dat.asset_type_id)::int2[], ARRAY[]::int2[])
      from deal_asset_types dat
      where dat.deal_id = d.id
    )                                                     as d_asset_type_ids,

    d.investment_strategy                                   as d_investment_strategy,
    d.tenancy                                               as d_tenancy,
    d.hotel_type                                            as d_hotel_type,
    d.guarantor_type                                        as d_guarantor_type,
    d.experience_level                                      as d_experience_level,
    d.net_worth                                             as d_net_worth,
    d.net_worth_num                                         as d_net_worth_num,
    d.value                                                 as d_value,
    d.liquidity                                             as d_liquidity,
    d.liquidity_num                                         as d_liquidity_num,
    d.assets_under_management                               as d_assets_under_management,
    d.credit_score                                          as d_credit_score,
    d.credit_score_num                                      as d_credit_score_num,
    d.us_citizenship                                        as d_us_citizenship,

    -- previously-defined UI filters
    -- [v2 change] Keep JSON for recourse so we can detect empty array vs null
    f.recourse_filter_json,
    f.amortization_filter,
    -- [v3 change] New capital stack filter values
    f.senior_pct,
    f.subordinate_pct,
    f.equity_pct,
    f.senior_toggle,
    f.subordinate_toggle,
    f.equity_toggle,
    f.senior_loc_cb,
    f.senior_scm_cb,
    f.sub_mezz_cb,
    f.sub_pref_cb,
    f.eq_cogp_cb,
    f.eq_lp_cb,
    f.eq_pace_cb,
    f.eq_glb_cb

  from programs p
  left join organizations o on p.organization_id = o.id
  left join program_extra pe on pe.id = p.id
  cross join deal d
  cross join filters f
),

-- compute booleans and match_score as before, in a raw_results CTE
raw_results as (
  select
    c.p_id                   as program_id,
    c.p_name                 as program_name,
    c.p_org_id               as organization_id,
    c.p_org_name             as organization_name,
    c.p_org_location         as organization_hq_location,
    c.p_recourse             as recourse,
    c.d_asset_type           as d_asset_type,
    c.p_program_asset_types  as p_program_asset_types,
    c.p_typical_amortization as typical_amortization,
    c.p_minimum_check_size   as minimum_check_size,
    c.p_maximum_check_size   as maximum_check_size,
    c.p_capital_stack        as capital_stack,
    c.p_updated_at           as updated_at,
    c.p_extra                as extra,

    -- compute booleans and score inlined (kept mostly the same as your original SELECT logic)
    -- NOTE: we compute match_score and matched here so we can rank per-organization below
    (
      (case when recourse_ok then 1 else 0 end)
    + (case when amortization_ok then 1 else 0 end)
    -- [v3 change] Updated to use new capital stack filters (Senior, Subordinate, Equity)
    + (case when (not sizing_filter_provided) or (fits_senior and sizing_filter_provided) then 1 else 0 end)
    + (case when (not sizing_filter_provided) or (fits_subordinate and sizing_filter_provided) then 1 else 0 end)
    + (case when (not sizing_filter_provided) or (fits_equity and sizing_filter_provided) then 1 else 0 end)
----------------------- END of FILTERS, BEGIN RULES -----------------------
    + (case when sizing_ok then 1 else 0 end)
    + (case when financing_ok then 1 else 0 end)
    + (case when location_ok then 1 else 0 end)
    + (case when asset_type_ok then 1 else 0 end)
    + (case when investment_strategy_ok then 1 else 0 end)
    + (case when tenancy_ok then 1 else 0 end)
    + (case when hotel_ok then 1 else 0 end)
    + (case when guarantor_ok then 1 else 0 end)
    + (case when sponsor_location_ok then 1 else 0 end)
    + (case when experience_ok then 1 else 0 end)
    + (case when net_worth_ok then 1 else 0 end)
    + (case when liquidity_ok then 1 else 0 end)
    + (case when liquidity_ratio_ok then 1 else 0 end)
    + (case when aum_ok then 1 else 0 end)
    + (case when credit_ok then 1 else 0 end)
    + (case when us_citizenship_ok then 1 else 0 end)
    -- 21.0  -- total number of boolean checks (now 3 capital stack filters + 18 other checks)
    )::integer as match_score,
  -- final matched decision: must satisfy all boolean checks below (plus recourse/amortization)
    (
      recourse_ok
      and amortization_ok
      and (
        -- [v3 change] A program matches if it matches ANY of the enabled capital stack types
        (not sizing_filter_provided) OR (fits_senior OR fits_subordinate OR fits_equity)
      )
----------------------- END of FILTERS, BEGIN RULES -----------------------
      and sizing_ok
      and financing_ok
      and location_ok
      and asset_type_ok
      and investment_strategy_ok
      and tenancy_ok
      and hotel_ok
      and guarantor_ok
      and sponsor_location_ok
      and experience_ok
      and net_worth_ok
      and liquidity_ok
      and liquidity_ratio_ok
      and aum_ok
      and credit_ok
      and us_citizenship_ok
    ) as matched,

  -- structured reasons: each boolean below is spelled out for the UI
    (select jsonb_object_agg(key, value)
      from (
             values
             ('recourse_ok',             recourse_ok),
             ('amortization_ok',         amortization_ok),
             ('sizing_filter_provided',  sizing_filter_provided),
             ('capital_stack_ok',        (not sizing_filter_provided) OR (fits_senior OR fits_subordinate OR fits_equity)),
             ('fits_senior',             (NOT coalesce(senior_toggle, false)) OR fits_senior),
             ('fits_subordinate',        (NOT coalesce(subordinate_toggle, false)) OR fits_subordinate),
             ('fits_equity',             (NOT coalesce(equity_toggle, false)) OR fits_equity),
             ('sizing_ok',               sizing_ok),
             ('financing_ok',            financing_ok),
             ('location_ok',             location_ok),
             ('asset_type_ok',           asset_type_ok),
             ('investment_strategy_ok',  investment_strategy_ok),
             ('tenancy_ok',              tenancy_ok),
             ('hotel_ok',                hotel_ok),
             ('guarantor_ok',            guarantor_ok),
             ('sponsor_location_ok',     sponsor_location_ok),
             ('experience_ok',           experience_ok),
             ('net_worth_ok',            net_worth_ok),
             ('liquidity_ok',            liquidity_ok),
             ('liquidity_ratio_ok',      liquidity_ratio_ok),
             ('aum_ok',                  aum_ok),
             ('credit_ok',               credit_ok),
             ('us_citizenship_ok',       us_citizenship_ok)
           ) as t(key, value)
      where value <> true
    ) as match_reasons,

    -- [v2 change] Provide computed helper values for sorting (not exposed in result set)
    -- check_size_diff: distance from deal value to program range center (smaller is better)
    -- soft_spot_score is computed in the next CTE so it can reference the matched alias safely
    -- These are used only in ORDER BY below.
    (case
       when c.p_minimum_check_size is null and c.p_maximum_check_size is null then null
       when c.p_minimum_check_size is null then abs(coalesce(c.d_value,0) - c.p_maximum_check_size)
       when c.p_maximum_check_size is null then abs(coalesce(c.d_value,0) - c.p_minimum_check_size)
       else abs(coalesce(c.d_value,0) - ((c.p_minimum_check_size + c.p_maximum_check_size)/2.0))
     end) as check_size_diff,
    recency_rank
  from (
    -- inner-most: compute every boolean as in your previous implementation
    select
      c.*,

      -- [v2 change] Provide a simple recency rank per entire candidate set for soft_spot
      row_number() over (order by c.p_updated_at desc nulls last, c.p_id) as recency_rank,

    -- program filters from UI
    -- recourse filter exact-match (if provided array)
      (case
        -- [v2 change] Treat NULL or empty array as no filter
        when c.recourse_filter_json is null
          or jsonb_typeof(c.recourse_filter_json) <> 'array'
          or jsonb_array_length(c.recourse_filter_json) = 0
        then true
        else lower(coalesce(c.p_recourse, '')) = ANY(
          ARRAY(
            SELECT lower(x)
            FROM jsonb_array_elements_text(c.recourse_filter_json) x
          )
        )
      end) as recourse_ok,

    -- amortization exact-match (if provided)
      (case
         when c.amortization_filter is null then true
         -- [v2 change] if program side empty and filter provided, do not match
         when cardinality(coalesce(c.p_typical_amortization, ARRAY[]::text[])) = 0 then false
         else (
           lower(c.amortization_filter) = any(
             array(select lower(x) from unnest(coalesce(c.p_typical_amortization, ARRAY[]::text[])) x)
           )
         )
      end) as amortization_ok,

    -- [v3 change] New capital stack matching logic with toggles, checkboxes, and sliders
    -- Calculate check amounts for each slider (percentage as fraction * deal value)
      ((coalesce(c.senior_pct,0) / 100.0) * coalesce(c.d_value,0)) as senior_check_amount,
      ((coalesce(c.subordinate_pct,0) / 100.0) * coalesce(c.d_value,0)) as subordinate_check_amount,
      ((coalesce(c.equity_pct,0) / 100.0) * coalesce(c.d_value,0)) as equity_check_amount,

    -- whether user supplied any capital stack filter (any toggle + at least one enabled checkbox)
      (
        (c.senior_toggle AND (c.senior_loc_cb OR c.senior_scm_cb))
        OR (c.subordinate_toggle AND (c.sub_mezz_cb OR c.sub_pref_cb))
        OR (c.equity_toggle AND (c.eq_cogp_cb OR c.eq_lp_cb OR c.eq_pace_cb OR c.eq_glb_cb))
      ) as sizing_filter_provided,

    -- [v3 change] fits within min/max check size (legacy sizing_ok for backward compatibility)
      -- [v2 change] Open-ended bounds: NULL program min/max means "ignore that bound"
      ( (c.p_minimum_check_size IS NULL OR coalesce(c.d_value,0) >= c.p_minimum_check_size)
        AND (c.p_maximum_check_size IS NULL OR coalesce(c.d_value,0) <= c.p_maximum_check_size)
      ) as sizing_ok,

    -- [v3 change] Senior capital stack matching
    -- Match if: toggle is on AND at least one senior checkbox is on AND program has matching capital_stack
    -- Sizing: if slider is 0/null, match all; otherwise check size constraints and LTC
      (
        CASE
          -- If senior toggle is off, always match (neutral)
          WHEN NOT c.senior_toggle THEN true
          -- If toggle is on but no checkboxes are checked, no match
          WHEN NOT (c.senior_loc_cb OR c.senior_scm_cb) THEN false
          -- Require at least one of the checked capital stack options to exist on the program
          WHEN NOT (
            (c.senior_loc_cb AND 'Line of Credit' = ANY(coalesce(c.p_capital_stack, ARRAY[]::text[])))
            OR (c.senior_scm_cb AND 'Senior' = ANY(coalesce(c.p_capital_stack, ARRAY[]::text[])))
          ) THEN false
          ELSE (
            -- If slider is 0 or null, match all (no size checking)
            (c.senior_pct IS NULL OR c.senior_pct = 0)
            OR (
              -- Otherwise check size constraints and LTC (skip size checks when deal value missing)
              (c.d_value IS NULL
                OR (
                  (c.p_minimum_check_size IS NULL OR ((c.senior_pct / 100.0) * c.d_value) >= c.p_minimum_check_size)
                  AND (c.p_maximum_check_size IS NULL OR ((c.senior_pct / 100.0) * c.d_value) <= c.p_maximum_check_size)
                )
              )
              AND (c.p_maximum_ltc IS NULL OR (c.senior_pct / 100.0) <= c.p_maximum_ltc)
            )
          )
        END
      ) as fits_senior,

    -- [v3 change] Subordinate capital stack matching
      (
        CASE
          WHEN NOT c.subordinate_toggle THEN true
          WHEN NOT (c.sub_mezz_cb OR c.sub_pref_cb) THEN false
          -- Require at least one checked subordinate capital stack value on the program
          WHEN NOT (
            (c.sub_mezz_cb AND 'Mezzanine' = ANY(coalesce(c.p_capital_stack, ARRAY[]::text[])))
            OR (c.sub_pref_cb AND 'Preferred Equity' = ANY(coalesce(c.p_capital_stack, ARRAY[]::text[])))
          ) THEN false
          ELSE (
            (c.subordinate_pct IS NULL OR c.subordinate_pct = 0)
            OR (
              -- Otherwise enforce check size comparisons; skip size checks if deal value missing
              c.d_value IS NULL
              OR (
                (c.p_minimum_check_size IS NULL OR ((c.subordinate_pct / 100.0) * c.d_value) >= c.p_minimum_check_size)
                AND (c.p_maximum_check_size IS NULL OR ((c.subordinate_pct / 100.0) * c.d_value) <= c.p_maximum_check_size)
              )
            )
          )
        END
      ) as fits_subordinate,

    -- [v3 change] Equity capital stack matching
      (
        CASE
          WHEN NOT c.equity_toggle THEN true
          WHEN NOT (c.eq_cogp_cb OR c.eq_lp_cb OR c.eq_pace_cb OR c.eq_glb_cb) THEN false
          -- Require at least one checked equity capital stack value on the program
          WHEN NOT (
            (c.eq_cogp_cb AND 'Co-GP Equity' = ANY(coalesce(c.p_capital_stack, ARRAY[]::text[])))
            OR (c.eq_lp_cb AND 'LP Equity' = ANY(coalesce(c.p_capital_stack, ARRAY[]::text[])))
            OR (c.eq_pace_cb AND 'PACE' = ANY(coalesce(c.p_capital_stack, ARRAY[]::text[])))
            OR (c.eq_glb_cb AND 'Ground Lease Buyer' = ANY(coalesce(c.p_capital_stack, ARRAY[]::text[])))
          ) THEN false
          ELSE (
            (c.equity_pct IS NULL OR c.equity_pct = 0)
            OR (
              -- Otherwise enforce check size comparisons; skip size checks if deal value missing
              c.d_value IS NULL
              OR (
                (c.p_minimum_check_size IS NULL OR ((c.equity_pct / 100.0) * c.d_value) >= c.p_minimum_check_size)
                AND (c.p_maximum_check_size IS NULL OR ((c.equity_pct / 100.0) * c.d_value) <= c.p_maximum_check_size)
              )
            )
          )
        END
      ) as fits_equity,
----------------------- END of FILTERS, BEGIN RULES -----------------------

    -- financing_type: if p_transaction_types is empty or null, the program matches all financing types; otherwise, arrays must overlap
      (
        (c.p_transaction_types IS NULL OR cardinality(c.p_transaction_types) = 0)
        OR (c.d_financing_type IS NULL OR cardinality(c.d_financing_type) = 0)
        OR (coalesce(c.d_financing_type, ARRAY[]::text[]) && coalesce(c.p_transaction_types, ARRAY[]::text[]))
      ) as financing_ok,

    -- property location: if program target list empty -> match, otherwise check via fuzzy match or substring
    location_matches_exact_split(
        c.d_city_town_village_locality_of_property_address,
        c.d_region_of_property_address,
        c.d_state_county_of_property_address,
        c.d_zip_postal_code_of_property_address,
        c.p_target_property_locations
    ) AS location_ok,

    -- asset type: [v2 change] use ID-based overlap from deal_asset_types and program_asset_types
    (
      (cardinality(coalesce(c.p_program_asset_type_ids, ARRAY[]::int2[])) = 0)
      OR (coalesce(c.d_asset_type_ids, ARRAY[]::int2[]) && coalesce(c.p_program_asset_type_ids, ARRAY[]::int2[]))
    ) as asset_type_ok,

    -- investment strategy: match if either side empty OR exact equality
      (
        (coalesce(c.p_investment_strategy,'') = '')
        OR (coalesce(c.d_investment_strategy,'') = '')
        OR (lower(c.p_investment_strategy) = lower(c.d_investment_strategy))
      ) as investment_strategy_ok,

    -- tenancy: program empty => match, otherwise equality to any allowed tenancy
      (
        (coalesce(c.p_commercial_tenancy,'') = '')
        OR (lower(coalesce(c.p_commercial_tenancy,'')) = 'any')
        OR (coalesce(c.d_tenancy,'') = '')
        OR (lower(c.p_commercial_tenancy) = lower(c.d_tenancy))
      ) as tenancy_ok,

    -- hotel rule: [intent confirmed] program excludes boutique hotels
      (
        (c.p_hotel_flag_required IS NOT TRUE)
        OR (coalesce(lower(c.d_hotel_type),'') <> 'boutique')
      ) as hotel_ok,

    -- guarantor rule: if deal is Corporation require program to include Corporation (string search tolerant)
      (
        (lower(coalesce(c.d_guarantor_type,'')) <> 'corporation')
        OR (
          lower(coalesce(c.d_guarantor_type,'')) = 'corporation'
          AND (coalesce(c.p_guarantor_type::text,'') ~~* '%corporation%')
        )
      ) as guarantor_ok,

    -- sponsor location: if program blank => match, else check sponsor city/county/state against sponsor_location_req
      (
        (c.d_sponsor_location IS NULL OR trim(c.d_sponsor_location) = '')
        OR (c.p_sponsor_location_req IS NULL)
        OR
          location_matches_exact_split(
              c.d_city_town_village_locality_of_sponsor_location,
              c.d_region_of_sponsor_location,
              c.d_state_county_of_sponsor_location,
              c.d_zip_postal_code_of_sponsor_location,
              c.p_sponsor_location_req
          )
      ) as sponsor_location_ok,

    -- experience level: if program blank => match, if deal blank => match, else exact match
      (
        (coalesce(c.p_sponsor_experience_level,'') = '')
        OR (coalesce(c.d_experience_level,'') = '')
        OR (c.p_sponsor_experience_level = c.d_experience_level)
      ) as experience_ok,

    -- net worth: if deal.net_worth is unknown => match. Else enforce absolute and ratio requirements without forcing 0 defaults.
      (
        (c.d_net_worth_num IS NULL)
          OR (
            (c.p_min_net_worth IS NULL OR (c.d_net_worth_num >= c.p_min_net_worth))
            AND (
              c.p_min_net_worth_ratio IS NULL
              OR parse_money_to_numeric(c.p_min_net_worth_ratio) IS NULL
              OR (
                c.d_value IS NOT NULL
                AND (c.d_net_worth_num * c.d_value) >= parse_money_to_numeric(c.p_min_net_worth_ratio)
              )
            )
          )
      ) as net_worth_ok,

    -- liquidity absolute: unknown deal liquidity passes; otherwise require numeric deal liquidity above program minimum.
      (
        (c.d_liquidity_num IS NULL)
        OR (c.p_min_liquidity IS NULL)
        OR (c.d_liquidity_num > c.p_min_liquidity)
      ) as liquidity_ok,

    -- liquidity ratio: require both parsed deal liquidity and ratio requirement to be present before comparing.
      (
        (c.d_liquidity_num IS NULL)
        OR (c.p_min_liquidity_ratio IS NULL)
        OR parse_money_to_numeric(c.p_min_liquidity_ratio) IS NULL
        OR (
          c.d_value IS NOT NULL
          AND (c.d_liquidity_num * c.d_value) > parse_money_to_numeric(c.p_min_liquidity_ratio)
        )
      ) as liquidity_ratio_ok,

    -- assets under management (AUM)
      (
        (c.d_assets_under_management IS NULL)
        OR (c.p_sponsor_aum_req IS NULL)
        OR parse_money_to_numeric(c.p_sponsor_aum_req) IS NULL
        OR (c.d_assets_under_management > parse_money_to_numeric(c.p_sponsor_aum_req))
      ) as aum_ok,

    -- credit score: use normalized numeric column; unknown values remain permissive
      (
        (c.d_credit_score_num IS NULL)
        OR (c.p_min_credit_score IS NULL)
        OR (c.d_credit_score_num >= c.p_min_credit_score)
      ) as credit_ok,

    -- US citizenship: [v2 change] permissive when unknown (deal NULL => ok);
    -- ok if program does not require; if program requires, then deal must be true.
      (
        (coalesce(c.p_us_citizenship_required, false) = false)
        OR (c.d_us_citizenship IS NULL)
        OR (c.d_us_citizenship IS TRUE AND c.p_us_citizenship_required IS TRUE)
      ) as us_citizenship_ok

    from candidates c
) c
  where
  -- only return programs that satisfy the filtering boolean set (you can remove this WHERE to return near-misses)
    (
      c.recourse_ok
      and c.amortization_ok
      and (
      -- [v3 change] if any capital stack toggle is on, require at least one capital stack type to match
        (not c.sizing_filter_provided) OR (c.fits_senior OR c.fits_subordinate OR c.fits_equity)
      )
----------------------- END of FILTERS, BEGIN RULES -----------------------
      and c.sizing_ok
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
    )
    or (not p_match_only) -- if p_match_only is false, return all candidates
),

-- derive soft_spot_score now that matched/match_score aliases are available
results as (
  select
    rr.*,
    (
      (case when (rr.recency_rank <= 100) then 1 else 0 end)
      + (case when rr.matched then 2 else 0 end)
      + least(rr.match_score, 20) * 0.05
    )::numeric as soft_spot_score
  from raw_results rr
),

-- Rank per organization and pick the top 1 program for each organization.
-- tie-breakers: prefer matched=true, then higher match_score, then newer updated_at, then lower program_id
ranked as (
  select
    r.*,
    row_number() over (
      partition by r.organization_id
      order by
        (case when r.matched then 1 else 0 end) desc,
        r.match_score desc,
        r.updated_at desc nulls last,
        r.program_id
    ) as rn
  from results r
)

-- final: one program per organization, then apply limit and final ordering
select
  program_id,
  program_name,
  organization_id,
  organization_name,
  organization_hq_location,
  match_score,
  matched,
  match_reasons,
  d_asset_type,
  p_program_asset_types,
  recourse,
  typical_amortization,
  minimum_check_size,
  maximum_check_size,
  capital_stack,
  updated_at,
  extra
from ranked
where rn = 1
order by
  -- [v2 change] Implement dynamic sort modes. Fallback to 'updated' preference if unknown.
  case when p_sort_by in ('updated','score','check_size','soft_spot') then 0 else 1 end,
  -- 'score': matched desc, match_score desc, updated_at desc
  case when p_sort_by = 'score' then (case when matched then 1 else 0 end) end desc nulls last,
  case when p_sort_by = 'score' then match_score end desc nulls last,
  case when p_sort_by = 'score' then updated_at end desc nulls last,
  -- 'check_size': prefer programs whose range center is closest to deal value, then matched and score
  case when p_sort_by = 'check_size' then check_size_diff end asc nulls last,
  case when p_sort_by = 'check_size' then (case when matched then 1 else 0 end) end desc nulls last,
  case when p_sort_by = 'check_size' then match_score end desc nulls last,
  -- 'soft_spot': simple heuristic that prefers matched, score, and recency via soft_spot_score
  case when p_sort_by = 'soft_spot' then soft_spot_score end desc nulls last,
  -- default 'updated': keep same preference as original
  (case when matched then 1 else 0 end) desc,
  match_score desc,
  updated_at desc nulls last,
  program_id
limit p_limit offset p_offset;
$$;


-- select * from rpc_match_programs(34);

-- select * 
-- from rpc_match_programs(
--   p_deal_id := 26,
--   p_filters := NULL, --'{"recourse":["Non-Recourse"],"amortization":"25"}',
--   p_sort_by := 'updated',
--   p_match_only := true,
--   p_limit := 1000
-- );



-- -- Deal-side numeric normalizations
-- alter table deals
--   add column if not exists net_worth_num numeric generated always as (parse_money_to_numeric(net_worth)) stored,
--   add column if not exists liquidity_num numeric generated always as (parse_money_to_numeric(liquidity)) stored,
--   add column if not exists credit_score_num numeric generated always as (parse_money_to_numeric(credit_score)) stored;

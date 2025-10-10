create or replace function public.location_matches_exact_split(
  d_city_town_village_locality text,  -- metro or city
  d_region                     text,  -- state/region
  d_state_county               text,  -- county
  p_target_locs                jsonb  -- program locations JSON
)
returns boolean
language plpgsql
stable
as $$
declare
  -- Flatten the program’s location requirements.  p_target_locs may be a single
  -- JSON object with “states”, “counties” and “metros” keys or an array of such
  -- objects.  Wrap non-array inputs into a single-element array; extract the
  -- arrays under each key and accumulate into flattened lists.  Lower-case all
  -- entries for case-insensitive comparison.
  v_states   text[] := coalesce(
    (
      select array_agg(lower(value::text))
      from jsonb_array_elements(
             case when jsonb_typeof(p_target_locs) = 'array'
                  then p_target_locs
                  else jsonb_build_array(p_target_locs)
             end
           ) obj
      left join lateral jsonb_array_elements_text(obj.value->'states') as value on true
    ),
    array[]::text[]
  );
  v_counties text[] := coalesce(
    (
      select array_agg(lower(value::text))
      from jsonb_array_elements(
             case when jsonb_typeof(p_target_locs) = 'array'
                  then p_target_locs
                  else jsonb_build_array(p_target_locs)
             end
           ) obj
      left join lateral jsonb_array_elements_text(obj.value->'counties') as value on true
    ),
    array[]::text[]
  );
  v_metros   text[] := coalesce(
    (
      select array_agg(lower(value::text))
      from jsonb_array_elements(
             case when jsonb_typeof(p_target_locs) = 'array'
                  then p_target_locs
                  else jsonb_build_array(p_target_locs)
             end
           ) obj
      left join lateral jsonb_array_elements_text(obj.value->'metros') as value on true
    ),
    array[]::text[]
  );
  -- Full state names and their corresponding two-letter abbreviations.
  state_names text[] := array[
    'alabama','alaska','arizona','arkansas','california','colorado','connecticut',
    'delaware','district of columbia','florida','georgia','hawaii','idaho',
    'illinois','indiana','iowa','kansas','kentucky','louisiana','maine',
    'maryland','massachusetts','michigan','minnesota','mississippi','missouri',
    'montana','nebraska','nevada','new hampshire','new jersey','new mexico',
    'new york','north carolina','north dakota','ohio','oklahoma','oregon',
    'pennsylvania','rhode island','south carolina','south dakota',
    'tennessee','texas','utah','vermont','virginia','washington',
    'west virginia','wisconsin','wyoming'
  ];
  state_abbrevs text[] := array[
    'al','ak','az','ar','ca','co','ct','de','dc','fl','ga','hi','id','il','in','ia',
    'ks','ky','la','me','md','ma','mi','mn','ms','mo','mt','ne','nv','nh','nj','nm',
    'ny','nc','nd','oh','ok','or','pa','ri','sc','sd','tn','tx','ut','vt','va','wa',
    'wv','wi','wy'
  ];
  normalized_deal_state text;
begin
  -- No filters? Always match.
  if coalesce(array_length(v_states,1),0) = 0
     and coalesce(array_length(v_counties,1),0) = 0
     and coalesce(array_length(v_metros,1),0) = 0 then
    return true;
  end if;

  -- Normalize the deal’s region to a two-letter abbreviation (lowercase).
  normalized_deal_state := null;
  if d_region is not null and d_region <> '' then
    normalized_deal_state := lower(d_region);
    if char_length(normalized_deal_state) > 2 then
      for i in 1 .. array_length(state_names,1) loop
        if normalized_deal_state = state_names[i] then
          normalized_deal_state := state_abbrevs[i];
          exit;
        end if;
      end loop;
    end if;
    normalized_deal_state := lower(normalized_deal_state);
  end if;

  -- Convert any full state names in the program’s states array to abbreviations.
  if array_length(v_states,1) is not null then
    for i in 1 .. array_length(v_states,1) loop
      if v_states[i] is not null and char_length(v_states[i]) > 2 then
        for j in 1 .. array_length(state_names,1) loop
          if v_states[i] = state_names[j] then
            v_states[i] := state_abbrevs[j];
            exit;
          end if;
        end loop;
      end if;
      v_states[i] := lower(v_states[i]);
    end loop;
  end if;

  -- State match.
  if normalized_deal_state is not null and normalized_deal_state <> '' then
    if normalized_deal_state = any(v_states) then
      return true;
    end if;
  end if;

  -- County match.
  if d_state_county is not null and d_state_county <> '' then
    if lower(d_state_county) = any(v_counties) then
      return true;
    end if;
  end if;

  -- Metro (city) match.
  if d_city_town_village_locality is not null and d_city_town_village_locality <> '' then
    if lower(d_city_town_village_locality) = any(v_metros) then
      return true;
    end if;
  end if;

  return false;
end;
$$;

SELECT public.location_matches_exact_split(
  'Sulphur',          -- city
  'Texas',            -- region (state)
  'Calcasieu Parish', -- county
  '[{
    "states": [
      "NJ","NY","PA","CT","DE","MD","MA","TX"
    ]
  }]'::jsonb
);

SELECT public.location_matches_exact_split(
  'Sulphur',
  'Texas',
  'Calcasieu Parish',
  '[{
    "states": [
      "NJ",
      "NY",
      "PA",
      "CT",
      "DE",
      "MD",
      "MA",
      "TX"
    ]}]'::jsonb
);
-- should return true
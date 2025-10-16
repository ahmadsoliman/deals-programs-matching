-- drop function if exists public.location_matches_exact_split(
--   text, text, text, text, jsonb
-- );

create or replace function public.location_matches_exact_split (
  d_city_town_village_locality text default null, -- city or town or village or locality
  d_region text default null, -- county
  d_state_county text default null, -- state
  d_zip_code text default null, -- zip code
  p_target_locs jsonb default null
) returns boolean language plpgsql stable as $$
declare
  -- Flatten the location filter criteria from p_target_locs.
  v_states     text[] := coalesce(
    (
      select array_agg(lower(v_cur::text)) filter (where v_cur is not null)
      from jsonb_array_elements(
             case 
               when jsonb_typeof(p_target_locs) = 'array' then p_target_locs
               else jsonb_build_array(p_target_locs)
             end
           ) obj
      left join lateral jsonb_array_elements_text(CASE WHEN jsonb_typeof(obj.value->'states') = 'array' THEN obj.value->'states' ELSE '[]'::jsonb END) as v_cur on true
    ),
    array[]::text[]
  );

  v_counties   text[] := coalesce(
    (
      select array_agg(lower(v_cur::text)) filter (where v_cur is not null)
      from jsonb_array_elements(
             case 
               when jsonb_typeof(p_target_locs) = 'array' then p_target_locs
               else jsonb_build_array(p_target_locs)
             end
           ) obj
      left join lateral jsonb_array_elements_text(CASE WHEN jsonb_typeof(obj.value->'counties') = 'array' THEN obj.value->'counties' ELSE '[]'::jsonb END) as v_cur on true
    ),
    array[]::text[]
  );

  v_cities     text[] := coalesce(
    (
      select array_agg(lower(v_cur::text)) filter (where v_cur is not null)
      from jsonb_array_elements(
             case 
               when jsonb_typeof(p_target_locs) = 'array' then p_target_locs
               else jsonb_build_array(p_target_locs)
             end
           ) obj
      left join lateral jsonb_array_elements_text(CASE WHEN jsonb_typeof(obj.value->'cities') = 'array' THEN obj.value->'cities' ELSE '[]'::jsonb END) as v_cur on true
    ),
    array[]::text[]
  );

  v_zip_codes  text[] := coalesce(
    (
      select array_agg(lower(v_cur::text)) filter (where v_cur is not null)
      from jsonb_array_elements(
             case 
               when jsonb_typeof(p_target_locs) = 'array' then p_target_locs
               else jsonb_build_array(p_target_locs)
             end
           ) obj
      left join lateral jsonb_array_elements_text(CASE WHEN jsonb_typeof(obj.value->'zip_codes') = 'array' THEN obj.value->'zip_codes' ELSE '[]'::jsonb END) as v_cur on true
    ),
    array[]::text[]
  );
  
  -- Lookup arrays for state full names and abbreviations.
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

  normalized_state text;

begin

  -- If no target location filters are provided, always match.
  if p_target_locs is null or p_target_locs = 'null'::jsonb
    or (coalesce(cardinality(v_states),0) = 0 and
     coalesce(cardinality(v_counties),0) = 0 and
     coalesce(cardinality(v_cities),0) = 0 and
     coalesce(cardinality(v_zip_codes),0) = 0) then
    return true;
  end if;

  if d_region is not null and d_region <> '' then
    if lower(d_region) = any(v_counties) then
      return true;
    end if;
  end if;

  if d_city_town_village_locality is not null and d_city_town_village_locality <> '' then
    if lower(d_city_town_village_locality) = any(v_cities) then
      return true;
    end if;
  end if;

  if d_zip_code is not null and d_zip_code <> '' then
    if lower(d_zip_code) = any(v_zip_codes) then
      return true;
    end if;
  end if;

  -- Check for a state match. (If the deal's state is already an abbreviation or v_states contains full names.)
  if d_state_county is not null and d_state_county <> '' then
    if lower(d_state_county) = any(v_states) then
      return true;
    end if;
  end if;

  -- Normalize the deal's state from d_state_county.
  normalized_state := null;
  if d_state_county is not null and d_state_county <> '' then
    normalized_state := lower(d_state_county);
    if char_length(normalized_state) > 2 then
      for i in 1 .. array_length(state_names,1) loop
        if normalized_state = state_names[i] then
          normalized_state := state_abbrevs[i];
          exit;
        end if;
      end loop;
    end if;
    normalized_state := lower(normalized_state);
  end if;

  -- Convert any full state names in the target states array to abbreviations.
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

  -- Check for a state match.
  if normalized_state is not null and normalized_state <> '' then
    if normalized_state = any(v_states) then
      return true;
    end if;
  end if;

  return false;
end;
$$;

select
  public.location_matches_exact_split (
    'Sulphur',
    'Calcasieu Parish',
    'Texas',
    '',
    '[{"states": []}]'::jsonb
  );


-- -- Example call (inserts NULL for zip code when not used):
-- SELECT public.location_matches_exact_split(
--   'Sulphur',          -- city
--   'Texas',            -- region (state)
--   'Calcasieu Parish', -- county
--   '',               -- zip code
--   NULL
-- );


-- select public.location_matches_exact_split(
--   'Sulphur',
--   'Texas',
--   'Calcasieu Parish',
--   null,
--   '[{"states":["NJ","NY","PA","CT","DE","MD","MA","TX"]}]'::jsonb
-- );
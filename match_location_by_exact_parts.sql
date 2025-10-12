create or replace function public.location_matches_exact_split(
  d_city_town_village_locality text default null,  -- city/town/village/locality
  d_region                     text default null,  -- state (full name or abbreviation)
  d_state_county               text default null,  -- county
  d_zip_code                   text default null,
  p_target_locs                jsonb default null
)
returns boolean
language plpgsql
stable
as $$
declare
  -- Flatten the location filter criteria from p_target_locs.
  v_states     text[] := coalesce(
    (
      select array_agg(lower(value::text))
      from jsonb_array_elements(
             case 
               when jsonb_typeof(p_target_locs) = 'array' then p_target_locs
               else jsonb_build_array(p_target_locs)
             end
           ) obj
      left join lateral jsonb_array_elements_text(obj.value->'states') as value on true
    ),
    array[]::text[]
  );
  v_counties   text[] := coalesce(
    (
      select array_agg(lower(value::text))
      from jsonb_array_elements(
             case 
               when jsonb_typeof(p_target_locs) = 'array' then p_target_locs
               else jsonb_build_array(p_target_locs)
             end
           ) obj
      left join lateral jsonb_array_elements_text(obj.value->'counties') as value on true
    ),
    array[]::text[]
  );
  v_cities     text[] := coalesce(
    (
      select array_agg(lower(value::text))
      from jsonb_array_elements(
             case 
               when jsonb_typeof(p_target_locs) = 'array' then p_target_locs
               else jsonb_build_array(p_target_locs)
             end
           ) obj
      left join lateral jsonb_array_elements_text(obj.value->'cities') as value on true
    ),
    array[]::text[]
  );
  v_zip_codes  text[] := coalesce(
    (
      select array_agg(lower(value::text))
      from jsonb_array_elements(
             case 
               when jsonb_typeof(p_target_locs) = 'array' then p_target_locs
               else jsonb_build_array(p_target_locs)
             end
           ) obj
      left join lateral jsonb_array_elements_text(obj.value->'zip_codes') as value on true
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
  if coalesce(array_length(v_states,1),0) = 0 and
     coalesce(array_length(v_counties,1),0) = 0 and
     coalesce(array_length(v_cities,1),0) = 0 and
     coalesce(array_length(v_zip_codes,1),0) = 0 then
    return true;
  end if;

  -- Normalize the deal's state from d_region.
  normalized_state := null;
  if d_region is not null and d_region <> '' then
    normalized_state := lower(d_region);
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

  -- Check for a county match.
  if d_state_county is not null and d_state_county <> '' then
    if lower(d_state_county) = any(v_counties) then
      return true;
    end if;
  end if;

  -- Check for a city match.
  if d_city_town_village_locality is not null and d_city_town_village_locality <> '' then
    if lower(d_city_town_village_locality) = any(v_cities) then
      return true;
    end if;
  end if;

  -- Check for a zip code match.
  if d_zip_code is not null and d_zip_code <> '' then
    if lower(d_zip_code) = any(v_zip_codes) then
      return true;
    end if;
  end if;

  return false;
end;
$$;

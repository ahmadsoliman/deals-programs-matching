
CREATE OR REPLACE FUNCTION public.location_matches_address_fuzzy(
  p_property_address    text,
  p_target_locs         jsonb,
  p_threshold           real DEFAULT 0.6
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_states   text[] := COALESCE(
    (SELECT array_agg(value::text) FROM jsonb_array_elements_text(p_target_locs->'states')),
    ARRAY[]::text[]
  );
  v_counties text[] := COALESCE(
    (SELECT array_agg(value::text) FROM jsonb_array_elements_text(p_target_l ocs->'counties')),
    ARRAY[]::text[]
  );
  v_metros   text[] := COALESCE(
    (SELECT array_agg(value::text) FROM jsonb_array_elements_text(p_target_locs->'metros')),
    ARRAY[]::text[]
  );
  loc text;
BEGIN
  -- No filters? Always match.
  IF array_length(v_states,1) IS NULL
     AND array_length(v_counties,1) IS NULL
     AND array_length(v_metros,1) IS NULL THEN
    RETURN TRUE;
  END IF;

  -- Check states
  FOREACH loc IN ARRAY v_states LOOP
    IF POSITION(lower(loc) IN lower(p_property_address)) > 0
       OR similarity(lower(p_property_address), lower(loc)) >= p_threshold THEN
      RETURN TRUE;
    END IF;
  END LOOP;

  -- Check counties
  FOREACH loc IN ARRAY v_counties LOOP
    IF POSITION(lower(loc) IN lower(p_property_address)) > 0
       OR similarity(lower(p_property_address), lower(loc)) >= p_threshold THEN
      RETURN TRUE;
    END IF;
  END LOOP;

  -- Check metros
  FOREACH loc IN ARRAY v_metros LOOP
    IF POSITION(lower(loc) IN lower(p_property_address)) > 0
       OR similarity(lower(p_property_address), lower(loc)) >= p_threshold THEN
      RETURN TRUE;
    END IF;
  END LOOP;

  RETURN FALSE;
END;
$$;
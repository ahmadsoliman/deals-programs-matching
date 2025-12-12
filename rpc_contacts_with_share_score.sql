CREATE OR REPLACE FUNCTION public.rpc_contacts_with_share_score(
  p_consider_open_deals_only boolean DEFAULT TRUE,
  p_stage_ids bigint[] DEFAULT NULL,
  p_owner_user_id text DEFAULT NULL,
  p_contact_name text DEFAULT NULL,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS TABLE (
  total_count bigint,
  id bigint,
  organization_id bigint,
  name text,
  email text,
  phone text,
  title text,
  linkedin text,
  location text,
  timezone text,
  notes text,
  pipedrive_id bigint,
  share_score integer,
  shares_needs_attention integer,
  shares jsonb
)
SECURITY DEFINER
LANGUAGE sql
STABLE
AS $$
WITH base AS (
  SELECT
    c.id,
    c.organization_id,
    c.name,
    c.email,
    c.phone,
    c.title,
    c.linkedin,
    c.location,
    c.timezone,
    c.notes,
    c.pipedrive_id,
    COALESCE((
      SELECT sum(
        CASE s.status
          WHEN 'sent' THEN 2
          WHEN 'interested' THEN 1
          WHEN 'shortlisted' THEN 1
          ELSE 0
        END)
      FROM public.share_contacts sc
      JOIN public.shares s ON s.id = sc.share_id
      JOIN public.deals d ON d.id = s.deal_id
      WHERE sc.contact_id = c.id
        AND (p_consider_open_deals_only IS NOT TRUE OR d.status = 'open')
        AND ((p_stage_ids IS NULL OR cardinality(p_stage_ids) = 0) OR d.stage::numeric = ANY(p_stage_ids))
        AND (p_owner_user_id IS NULL OR d.owner_user_id = p_owner_user_id)
    ), 0)::int AS share_score,
    COALESCE((
      SELECT count(*)
      FROM public.share_contacts sc2
      JOIN public.shares s2 ON s2.id = sc2.share_id
      JOIN public.deals d2 ON d2.id = s2.deal_id
      WHERE sc2.contact_id = c.id
        AND (p_consider_open_deals_only IS NOT TRUE OR d2.status = 'open')
        AND ((p_stage_ids IS NULL OR cardinality(p_stage_ids) = 0) OR d2.stage::numeric = ANY(p_stage_ids))
        AND (p_owner_user_id IS NULL OR d2.owner_user_id = p_owner_user_id)
        AND s2.status = ANY (ARRAY['sent','interested','shortlisted'])
    ), 0)::int AS shares_needs_attention
  FROM public.contacts c
  WHERE (p_contact_name IS NULL OR COALESCE(c.name,'') ILIKE '%' || p_contact_name || '%')
),
filtered AS (
  SELECT *
  FROM base
  WHERE shares_needs_attention > 0
),
counted AS (
  SELECT COUNT(*) AS total_count FROM filtered
),
ordered AS (
  SELECT *
  FROM filtered
  ORDER BY share_score DESC, id ASC
),
paged AS (
  SELECT * FROM ordered
  LIMIT GREATEST(p_limit, 0)
  OFFSET GREATEST(p_offset, 0)
),
shares_for_contact AS (
  SELECT
    c.id AS contact_id,
    jsonb_agg(
      jsonb_build_object(
        'share_id', s.id,
        'share_status', s.status,
        'share_sent_at', s.sent_at,
        'share_created_at', s.created_at,
        'share_updated_at', s.updated_at,
        'share_updated_by', s.updated_by,
        'score', CASE s.status WHEN 'sent' THEN 2 WHEN 'interested' THEN 1 WHEN 'shortlisted' THEN 1 ELSE 0 END,
        'deal', jsonb_build_object(
          'deal_id', d.id,
          'title', d.title,
          'stage', d.stage,
          'status', d.status,
          'owner_user_id', d.owner_user_id,
          'value', d.value,
          'currency', d.currency,
          'org_id', d.organization_id,
          'created_at', d.created_at,
          'updated_at', d.updated_at,
          'city_town_village_locality_of_property_address', d.city_town_village_locality_of_property_address,
          'state_county_of_property_address', d.state_county_of_property_address
        )
      )
      ORDER BY
        CASE s.status WHEN 'sent' THEN 2 WHEN 'interested' THEN 1 WHEN 'shortlisted' THEN 1 ELSE 0 END DESC,
        COALESCE(s.updated_at, s.created_at) DESC
    ) AS shares
  FROM paged c
  JOIN public.share_contacts sc ON sc.contact_id = c.id
  JOIN public.shares s ON s.id = sc.share_id
  JOIN public.deals d ON d.id = s.deal_id
  WHERE s.status = ANY (ARRAY['sent','interested','shortlisted'])
    AND (p_consider_open_deals_only IS NOT TRUE OR d.status = 'open')
    AND ((p_stage_ids IS NULL OR cardinality(p_stage_ids) = 0) OR d.stage::numeric = ANY(p_stage_ids))
    AND (p_owner_user_id IS NULL OR d.owner_user_id = p_owner_user_id)
  GROUP BY c.id
)
SELECT
  counted.total_count,
  paged.id,
  paged.organization_id,
  paged.name,
  paged.email,
  paged.phone,
  paged.title,
  paged.linkedin,
  paged.location,
  paged.timezone,
  paged.notes,
  paged.pipedrive_id,
  paged.share_score,
  paged.shares_needs_attention,
  COALESCE(sfc.shares, '[]'::jsonb) AS shares
FROM counted, paged
LEFT JOIN shares_for_contact sfc ON sfc.contact_id = paged.id;
$$;

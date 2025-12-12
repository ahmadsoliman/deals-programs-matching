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
-- Pre-filter shares with common deal filters applied once
WITH relevant_shares AS (
  SELECT
    sc.contact_id,
    s.id AS share_id,
    s.status,
    s.sent_at,
    s.created_at,
    s.updated_at,
    s.updated_by,
    d.id AS deal_id,
    d.title AS deal_title,
    d.stage AS deal_stage,
    d.status AS deal_status,
    d.owner_user_id AS deal_owner_user_id,
    d.value AS deal_value,
    d.currency AS deal_currency,
    d.organization_id AS deal_organization_id,
    d.created_at AS deal_created_at,
    d.updated_at AS deal_updated_at,
    d.city_town_village_locality_of_property_address,
    d.state_county_of_property_address
  FROM public.share_contacts sc
  JOIN public.shares s ON s.id = sc.share_id
  JOIN public.deals d ON d.id = s.deal_id
  WHERE (p_consider_open_deals_only IS NOT TRUE OR d.status = 'open')
    AND ((p_stage_ids IS NULL OR cardinality(p_stage_ids) = 0) OR d.stage::numeric = ANY(p_stage_ids))
    AND (p_owner_user_id IS NULL OR d.owner_user_id = p_owner_user_id)
),
-- Aggregate scores per contact using relevant_shares
contact_scores AS (
  SELECT
    rs.contact_id,
    SUM(CASE rs.status
      WHEN 'sent' THEN 2
      WHEN 'interested' THEN 1
      WHEN 'shortlisted' THEN 1
      ELSE 0
    END)::int AS share_score,
    COUNT(*) FILTER (WHERE rs.status IN ('sent','interested','shortlisted'))::int AS shares_needs_attention
  FROM relevant_shares rs
  GROUP BY rs.contact_id
),
base AS (
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
    COALESCE(cs.share_score, 0) AS share_score,
    COALESCE(cs.shares_needs_attention, 0) AS shares_needs_attention
  FROM public.contacts c
  LEFT JOIN contact_scores cs ON cs.contact_id = c.id
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
    p.id AS contact_id,
    jsonb_agg(
      jsonb_build_object(
        'share_id', rs.share_id,
        'share_status', rs.status,
        'share_sent_at', rs.sent_at,
        'share_created_at', rs.created_at,
        'share_updated_at', rs.updated_at,
        'share_updated_by', rs.updated_by,
        'score', CASE rs.status WHEN 'sent' THEN 2 WHEN 'interested' THEN 1 WHEN 'shortlisted' THEN 1 ELSE 0 END,
        'deal', jsonb_build_object(
          'deal_id', rs.deal_id,
          'title', rs.deal_title,
          'stage', rs.deal_stage,
          'status', rs.deal_status,
          'owner_user_id', rs.deal_owner_user_id,
          'value', rs.deal_value,
          'currency', rs.deal_currency,
          'org_id', rs.deal_organization_id,
          'created_at', rs.deal_created_at,
          'updated_at', rs.deal_updated_at,
          'city_town_village_locality_of_property_address', rs.city_town_village_locality_of_property_address,
          'state_county_of_property_address', rs.state_county_of_property_address
        )
      )
      ORDER BY
        CASE rs.status WHEN 'sent' THEN 2 WHEN 'interested' THEN 1 WHEN 'shortlisted' THEN 1 ELSE 0 END DESC,
        COALESCE(rs.updated_at, rs.created_at) DESC
    ) AS shares
  FROM paged p
  JOIN relevant_shares rs ON rs.contact_id = p.id
  WHERE rs.status IN ('sent','interested','shortlisted')
  GROUP BY p.id
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

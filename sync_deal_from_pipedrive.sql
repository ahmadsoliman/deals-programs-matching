CREATE OR REPLACE FUNCTION public.sync_deal_from_pipedrive(p_deal_id bigint)
RETURNS void
LANGUAGE plpgsql
AS $$
begin

insert into public.deals (
    id,
    title,
    value,
    currency,
    stage,
    status,
    probability,
    organization_id,
    primary_contact_id,
    owner_user_id,
    financing_type,
    deal_assist_user,
    capital_advisor_fee,
    referral_fee,
    referral_partner_id,
    winning_capital_provider_id,
    occupancy,
    ground_lease,
    property_address,
    asset_type,
    investment_strategy,
    tenancy,
    hotel_flag_id,
    hotel_type,
    single_tenant_name_id,
    guarantor_type,
    sponsor_location,
    experience_level,
    net_worth,
    liquidity,
    assets_under_management,
    credit_score,
    us_citizenship,
    deal_file_folder_link,
    offering_memorandum_link,
    add_time,
    won_time,
    lost_time,
    close_time,
    expected_close_date,
    last_synced_at,
    created_at,
    updated_at,
    -- new property address columns
    house_number_of_property_address,
    street_road_name_of_property_address,
    apartment_suite_no_of_property_address,
    district_sublocality_of_property_address,
    city_town_village_locality_of_property_address,
    state_county_of_property_address,
    region_of_property_address,
    country_of_property_address,
    zip_postal_code_of_property_address,
    full_combined_address_of_property_address
)
select
    d.id,
    d.title,
    d.value,
    d.currency,
    d.stage_id,
    d.status,
    null as probability,
    org.id as organization_id,
    c.id   as primary_contact_id,
    d.user_id__id as owner_user_id,
    '{}'::text[] as financing_type,
    d.deal_assist__id,
    d.capital_advisor_fee,
    d.referral_fee,
    ref.id as referral_partner_id,
    win_org.id as winning_capital_provider_id,
    d.occupancy,
    d.ground_lease,
    d.full_combined_address_of_property_address as property_address,
    '{}'::text[] as asset_type,
    d.investment_strategy,
    d.tenancy,
    hotel_org.id as hotel_flag_id,
    d.hotel_type,
    tenant_org.id as single_tenant_name_id,
    d.guarantor_type,
    d.full_combined_address_of_sponsor_location as sponsor_location,
    d.experience_level,
    d.net_worth,
    d.liquidity,
    null as assets_under_management,
    d.credit_score,
    d.us_citizenship,
    d.deal_file_folder_link,
    d.offering_memorandum_link,
    d.add_time,
    d.won_time,
    d.lost_time,
    d.close_time,
    d.expected_close_date::date,
    now() as last_synced_at,
    now() as created_at,
    now() as updated_at,
    -- new property address columns from pipedrive_data.deals
    d.house_number_of_property_address,
    d.street_road_name_of_property_address,
    d.apartment_suite_no_of_property_address,
    d.district_sublocality_of_property_address,
    d.city_town_village_locality_of_property_address,
    d.state_county_of_property_address,
    d.region_of_property_address,
    d.country_of_property_address,
    d.zip_postal_code_of_property_address,
    d.full_combined_address_of_property_address
from pipedrive_data.deals d
left join public.organizations org
  on org.pipedrive_id = d.org_id__value
   and org.pipedrive_id is not null
left join public.contacts c
  on c.pipedrive_id = d.person_id__value
   and c.pipedrive_id is not null
left join public.contacts ref
  on ref.pipedrive_id = d.referral_partner__value
   and ref.pipedrive_id is not null
left join public.organizations win_org
  on win_org.pipedrive_id = d.winning_capital_provider__value
   and win_org.pipedrive_id is not null
left join public.organizations hotel_org
  on hotel_org.pipedrive_id = d.hotel_flag__value
   and hotel_org.pipedrive_id is not null
left join public.organizations tenant_org
  on tenant_org.pipedrive_id = d.single_tenant_name__value
   and tenant_org.pipedrive_id is not null

where d.id = p_deal_id

on conflict (id) do update set
    title = excluded.title,
    value = excluded.value,
    currency = excluded.currency,
    stage = excluded.stage,
    status = excluded.status,
    probability = excluded.probability,
    organization_id = excluded.organization_id,
    primary_contact_id = excluded.primary_contact_id,
    owner_user_id = excluded.owner_user_id,
    financing_type = excluded.financing_type,
    deal_assist_user = excluded.deal_assist_user,
    capital_advisor_fee = excluded.capital_advisor_fee,
    referral_fee = excluded.referral_fee,
    referral_partner_id = excluded.referral_partner_id,
    winning_capital_provider_id = excluded.winning_capital_provider_id,
    occupancy = excluded.occupancy,
    ground_lease = excluded.ground_lease,
    property_address = excluded.property_address,
    asset_type = excluded.asset_type,
    investment_strategy = excluded.investment_strategy,
    tenancy = excluded.tenancy,
    hotel_flag_id = excluded.hotel_flag_id,
    hotel_type = excluded.hotel_type,
    single_tenant_name_id = excluded.single_tenant_name_id,
    guarantor_type = excluded.guarantor_type,
    sponsor_location = excluded.sponsor_location,
    experience_level = excluded.experience_level,
    net_worth = excluded.net_worth,
    liquidity = excluded.liquidity,
    assets_under_management = excluded.assets_under_management,
    credit_score = excluded.credit_score,
    us_citizenship = excluded.us_citizenship,
    deal_file_folder_link = excluded.deal_file_folder_link,
    offering_memorandum_link = excluded.offering_memorandum_link,
    add_time = excluded.add_time,
    won_time = excluded.won_time,
    lost_time = excluded.lost_time,
    close_time = excluded.close_time,
    expected_close_date = excluded.expected_close_date,
    last_synced_at = excluded.last_synced_at,
    updated_at = excluded.updated_at,
    -- update new property address columns as well
    house_number_of_property_address = excluded.house_number_of_property_address,
    street_road_name_of_property_address = excluded.street_road_name_of_property_address,
    apartment_suite_no_of_property_address = excluded.apartment_suite_no_of_property_address,
    district_sublocality_of_property_address = excluded.district_sublocality_of_property_address,
    city_town_village_locality_of_property_address = excluded.city_town_village_locality_of_property_address,
    state_county_of_property_address = excluded.state_county_of_property_address,
    region_of_property_address = excluded.region_of_property_address,
    country_of_property_address = excluded.country_of_property_address,
    zip_postal_code_of_property_address = excluded.zip_postal_code_of_property_address,
    full_combined_address_of_property_address = excluded.full_combined_address_of_property_address;
end;
$$;
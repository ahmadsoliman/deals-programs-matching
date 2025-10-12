-- sync_deal_asset_type

-- Recompute asset_type array on public.deals from pipedrive_data child rows
create or replace function public.sync_deal_asset_type(p_deal_id bigint)
returns void
language sql
as $$
  update public.deals d
  set asset_type = coalesce((
      select array_agg(at.value order by at.value)
      from pipedrive_data.deals__asset_type at
      join pipedrive_data.deals pd
        on pd._dlt_id = at._dlt_parent_id
      where pd.id = p_deal_id
  ), '{}')
  where d.id = p_deal_id;
$$;

begin
    update public.deals d
    set asset_type = coalesce((
        select array_agg(at.value order by at.value)
        from pipedrive_data.deals__asset_type at
        join pipedrive_data.deals pd on pd._dlt_id = at._dlt_parent_id
        where pd.id = p_deal_id
    ), '{}')
    where d.id = p_deal_id;
end;

-- Trigger function to call recompute on child changes
create or replace function pipedrive_data.tg_sync_deal_asset_type()
returns trigger
language plpgsql
as $$
declare
  v_parent_dlt_id text;
  v_deal_id bigint;
begin
  -- Determine which parent to update depending on operation
  if tg_op = 'DELETE' then
    v_parent_dlt_id := old._dlt_parent_id;
  else
    v_parent_dlt_id := new._dlt_parent_id;
  end if;

  -- Resolve to pipedrive_data.deals.id (the external deal id)
  select pd.id into v_deal_id
  from pipedrive_data.deals pd
  where pd._dlt_id = v_parent_dlt_id;

  -- If found, update the aggregated asset_type on public.deals
  if v_deal_id is not null then
    perform public.sync_deal_asset_type(v_deal_id);
  end if;

  -- Standard row return
  if tg_op = 'DELETE' then
    return old;
  else
    return new;
  end if;
end;
$$;

drop trigger if exists trg_sync_deal_asset_type on pipedrive_data.deals__asset_type;
create trigger trg_sync_deal_asset_type
after insert or update or delete on pipedrive_data.deals__asset_type
for each row execute function pipedrive_data.tg_sync_deal_asset_type();

create or replace function pipedrive_data.tg_sync_deal_asset_type_parent()
returns trigger
language plpgsql
as $$
begin
  perform public.sync_deal_asset_type(new.id);
  return new;
end;
$$;

drop trigger if exists trg_sync_deal_asset_type_parent on pipedrive_data.deals;
create trigger trg_sync_deal_asset_type_parent
after insert or update on pipedrive_data.deals
for each row execute function pipedrive_data.tg_sync_deal_asset_type_parent();

-- Phase Z1: idempotent external-order production request generation for one
-- production day.
--
-- Why an RPC: app roles (anon/authenticated) have SELECT-only RLS policies on
-- production_requests (U2); request creation must be a narrow
-- server/database operation, not a client table write.
--
-- Behavior (single transaction, idempotent):
--   1. require auth.uid() non-null with an active profile (any of the three
--      app roles; the role column is DB-constrained to operator/supervisor/admin);
--   2. load the stored production_day.production_date for p_production_day_id
--      (error 'production_day_not_found' if missing); the date is never
--      recalculated from now()/UTC;
--   3. lock the production_days row (FOR UPDATE) so concurrent calls for the
--      same day serialize (including against ensure_base_production_requests);
--   4. find external_orders with requested_date = stored production_date and
--      status <> 'cancelled';
--   5. for each external_order_item of those orders, create a
--      production_request if none exists yet for
--      (production_day_id, source_type='external_order', external_order_item_id)
--      — the stored item id makes repeated calls create no duplicates, and the
--      same product in different shifts remains distinct (different item ids);
--   6. copy the item's shift_code, product, quantity and unit;
--      source_type='external_order', status='pending', created_by=caller;
--      reason fields stay null (enforced by the external-order integrity
--      constraint);
--   7. return the number of requests created by this call (0 when everything
--      already existed).
-- Requests created by an earlier call are never cancelled or rewritten here
-- (e.g. if an order is cancelled afterwards); base and additional requests are
-- not touched (phases Y and the additional flow).
--
-- Security (SECURITY.md RPC checklist):
--   - SECURITY DEFINER owned by postgres is deliberate: the body performs the
--     inserts that no app role may do directly. Every authorization check
--     lives in the function body above.
--   - explicit safe search_path; every object fully qualified.
--   - EXECUTE revoked from PUBLIC, anon, authenticated and service_role
--     (Supabase default privileges would grant it, see U4); granted to
--     authenticated only, the role the app's users run as through PostgREST.

create or replace function public.ensure_external_order_requests(
  p_production_day_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_production_date date;
  v_created integer := 0;
  rec record;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if not exists (select 1 from public.profiles where id = v_user_id and active) then
    raise exception 'no_active_profile';
  end if;

  select production_date into v_production_date
  from public.production_days
  where id = p_production_day_id;

  if not found then
    raise exception 'production_day_not_found';
  end if;

  -- Serialize concurrent generation for the same day.
  perform 1
  from public.production_days
  where id = p_production_day_id
  for update;

  for rec in
    select i.id as item_id, i.product_id, i.quantity, i.unit, i.shift_code
    from public.external_order_items i
    join public.external_orders o on o.id = i.external_order_id
    where o.requested_date = v_production_date
      and o.status <> 'cancelled'
    order by i.id
  loop
    if not exists (
      select 1
      from public.production_requests r
      where r.production_day_id = p_production_day_id
        and r.source_type = 'external_order'
        and r.external_order_item_id = rec.item_id
    ) then
      insert into public.production_requests (
        production_day_id, source_type, shift_code, product_id,
        requested_quantity, unit, external_order_item_id, status, created_by
      ) values (
        p_production_day_id, 'external_order', rec.shift_code, rec.product_id,
        rec.quantity, rec.unit, rec.item_id, 'pending', v_user_id
      );
      v_created := v_created + 1;
    end if;
  end loop;

  return v_created;
end;
$$;

comment on function public.ensure_external_order_requests(uuid) is
  'Idempotently creates external-order production requests (source_type=external_order, status=pending) for one production day from the non-cancelled external orders of the stored production date; returns the number created.';

revoke execute on function public.ensure_external_order_requests(uuid) from public;
revoke execute on function public.ensure_external_order_requests(uuid) from anon, authenticated, service_role;
grant execute on function public.ensure_external_order_requests(uuid) to authenticated;

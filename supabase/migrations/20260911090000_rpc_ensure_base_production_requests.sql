-- Phase Y1: idempotent base production request generation for one production day.
--
-- Why an RPC: app roles (anon/authenticated) have SELECT-only RLS policies on
-- production_requests (U2); request creation must be a narrow
-- server/database operation, not a client table write.
--
-- Behavior (single transaction, idempotent):
--   1. require auth.uid() non-null with an active profile (any of the three
--      app roles; the role column is DB-constrained to operator/supervisor/admin);
--   2. load the stored production_day.production_date for p_production_day_id
--      (error 'production_day_not_found' if missing); the ISO weekday is
--      derived from that STORED date, never recalculated from now();
--   3. lock the production_days row (FOR UPDATE) so concurrent calls for the
--      same day serialize: the second call sees the first call's inserts and
--      creates nothing;
--   4. for each ACTIVE production_plan_item of that weekday, create a
--      production_request if none exists yet for
--      (production_day_id, source_type='base', product_id, shift_code) —
--      idempotency includes the shift, so the same product in a different
--      shift is a distinct request;
--      existing requests count in any status (a cancelled base request is not
--      silently recreated);
--   5. copy the plan item's shift_code, product, planned_quantity and unit;
--      status='pending', created_by=caller; external_order_item_id and the
--      reason fields stay null (enforced by the base integrity constraint);
--   6. return the number of requests created by this call (0 when everything
--      already existed).
-- External-order and additional requests are not touched here (phases Z and
-- the additional flow).
--
-- Security (SECURITY.md RPC checklist):
--   - SECURITY DEFINER owned by postgres is deliberate: the body performs the
--     inserts that no app role may do directly. Every authorization check
--     lives in the function body above.
--   - explicit safe search_path; every object fully qualified.
--   - EXECUTE revoked from PUBLIC, anon, authenticated and service_role
--     (Supabase default privileges would grant it, see U4); granted to
--     authenticated only, the role the app's users run as through PostgREST.

create or replace function public.ensure_base_production_requests(
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
  v_weekday smallint;
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

  -- ISO weekday of the STORED production date: 1 = Monday ... 7 = Sunday.
  v_weekday := extract(isodow from v_production_date)::smallint;

  for rec in
    select product_id, shift_code, planned_quantity, unit
    from public.production_plan_items
    where weekday = v_weekday
      and active
    order by sort_order, id
  loop
    if not exists (
      select 1
      from public.production_requests r
      where r.production_day_id = p_production_day_id
        and r.source_type = 'base'
        and r.product_id = rec.product_id
        and r.shift_code = rec.shift_code
    ) then
      insert into public.production_requests (
        production_day_id, source_type, shift_code, product_id,
        requested_quantity, unit, status, created_by
      ) values (
        p_production_day_id, 'base', rec.shift_code, rec.product_id,
        rec.planned_quantity, rec.unit, 'pending', v_user_id
      );
      v_created := v_created + 1;
    end if;
  end loop;

  return v_created;
end;
$$;

comment on function public.ensure_base_production_requests(uuid) is
  'Idempotently creates base production requests (source_type=base, status=pending) for one production day from the active weekly plan items of the stored production date''s ISO weekday; returns the number created.';

revoke execute on function public.ensure_base_production_requests(uuid) from public;
revoke execute on function public.ensure_base_production_requests(uuid) from anon, authenticated, service_role;
grant execute on function public.ensure_base_production_requests(uuid) to authenticated;

-- V6.11 (spec §60): CONFIRM DAILY PRODUCTION.
--
-- confirm_daily_production():
-- the single secure, atomic write path that reconciles the CURRENT business
-- day's daily selection into the existing BASE production-request model and
-- marks the selection confirmed. One plpgsql function = one transaction.
--
-- Reconciliation rules (spec §60, audited against the live schema first):
--   * selected items whose linked request is PENDING + source_type='base'
--     -> quantity/unit synced to the item (safe: the request has not started);
--   * selected items with no linked request -> an existing unlinked pending
--     base request for (day, product, shift) is linked (old base generator's
--     idempotency key: production_day_id + source_type + product_id +
--     shift_code); otherwise a new pending base request is created;
--   * items linked to in_progress or completed requests -> PRESERVED, never
--     touched (spec: already started/finished production survives);
--   * linked requests that are 'additional' or 'external_order' -> untouched
--     (spec: those sources are never reconciled here);
--   * selected-or-not, unselected pending BASE requests must not remain
--     active base production:
--       - linked to an unchecked item -> cancelled;
--       - not referenced by any selection item (old products no longer
--         selected) -> cancelled;
--   * cancellation uses the existing history-safe convention
--     (status = 'cancelled'; production_requests has no active column and
--     requests are never physically deleted);
--   * source_type values are NOT renamed ('base' stays 'base').
--
-- Invariants:
--   * only writes production_requests (pending base rows + cancellations),
--     item.production_request_id links, and the selection confirmation
--     stamps; in_progress/completed rows and additional/external_order rows
--     are never modified;
--   * re-confirming is idempotent: it re-runs the reconciliation and re-
--     stamps confirmed_by/confirmed_at without duplicating requests
--     (created requests are linked, so later passes never re-create them).
--
-- Roles: operator (production personnel) plus supervisor/admin (same
-- authorization as the V6.10 toggle; the confirmation button lives on the
-- same review screen).
--
-- Error tokens:
--   not_authenticated, no_active_profile, insufficient_role,
--   no_selection_for_today.
--
-- No UI in this file (spec §60: the review screen's CONFIRMAR PRODUCCIÓN
-- button calls it).

create or replace function public.confirm_daily_production()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_role text;
  v_day_id uuid;
  v_selection_id uuid;
  v_item record;
  v_request_status text;
  v_request_source text;
  v_existing uuid;
  v_stale_count integer;
  v_created integer := 0;
  v_updated integer := 0;
  v_cancelled integer := 0;
  v_preserved integer := 0;
  v_total integer := 0;
  v_selected integer := 0;
begin
  -- 1. Authentication, active profile, role (same gates as V6.8/V6.10).
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;
  select role into v_role
  from public.profiles
  where id = v_user_id and active;
  if v_role is null then
    raise exception 'no_active_profile';
  end if;
  if v_role not in ('operator', 'supervisor', 'admin') then
    raise exception 'insufficient_role';
  end if;

  -- 2. The current business day (America/Argentina/Cordoba via the existing
  --    database flow); serialize concurrent confirmations for the same day
  --    the same way the base generator does.
  v_day_id := public.ensure_production_day();
  perform 1
  from public.production_days
  where id = v_day_id
  for update;

  -- 3. The day's selection.
  select id into v_selection_id
  from public.daily_production_selections
  where production_day_id = v_day_id;
  if v_selection_id is null then
    raise exception 'no_selection_for_today';
  end if;

  -- 4. Reconcile every snapshot item.
  for v_item in
    select i.id, i.product_id, i.shift_code, i.quantity, i.unit,
           i.is_selected, i.production_request_id
    from public.daily_production_selection_items i
    where i.daily_selection_id = v_selection_id
    order by i.sort_order, i.id
  loop
    v_total := v_total + 1;
    if v_item.is_selected then
      v_selected := v_selected + 1;
    end if;

    if v_item.production_request_id is not null then
      select r.status, r.source_type
      into v_request_status, v_request_source
      from public.production_requests r
      where r.id = v_item.production_request_id;

      if v_request_status in ('in_progress', 'completed') then
        -- Locked: started/finished production is preserved, selected or not.
        v_preserved := v_preserved + 1;
        continue;
      end if;

      if v_request_source <> 'base' then
        -- additional / external_order requests are never touched here.
        v_preserved := v_preserved + 1;
        continue;
      end if;

      -- Linked PENDING base request.
      if v_item.is_selected then
        update public.production_requests
        set requested_quantity = v_item.quantity,
            unit = v_item.unit
        where id = v_item.production_request_id;
        v_updated := v_updated + 1;
      else
        -- Unchecked: must not remain active base production for the day.
        update public.production_requests
        set status = 'cancelled'
        where id = v_item.production_request_id;
        v_cancelled := v_cancelled + 1;
      end if;
    elsif v_item.is_selected then
      -- No linked request: reuse an existing unlinked pending base request
      -- for this (product, shift) if one exists (old base generator
      -- leftovers), otherwise create it.
      select r.id into v_existing
      from public.production_requests r
      where r.production_day_id = v_day_id
        and r.source_type = 'base'
        and r.status = 'pending'
        and r.product_id = v_item.product_id
        and r.shift_code = v_item.shift_code
        and not exists (
          select 1
          from public.daily_production_selection_items i2
          where i2.production_request_id = r.id
        )
      limit 1;

      if v_existing is null then
        insert into public.production_requests (
          production_day_id, source_type, shift_code, product_id,
          requested_quantity, unit, status, created_by
        ) values (
          v_day_id, 'base', v_item.shift_code, v_item.product_id,
          v_item.quantity, v_item.unit, 'pending', v_user_id
        )
        returning id into v_existing;
        v_created := v_created + 1;
      else
        v_updated := v_updated + 1;
      end if;

      update public.production_requests
      set requested_quantity = v_item.quantity,
          unit = v_item.unit
      where id = v_existing;

      update public.daily_production_selection_items
      set production_request_id = v_existing,
          updated_at = now()
      where id = v_item.id;
    end if;
    -- Unselected without a linked request: nothing here; the catch-all
    -- below cancels old pending base requests no longer referenced.
  end loop;

  -- 5. Catch-all: old pending base requests of the day that no selection
  --    item references (products no longer selected) are cancelled.
  with stale as (
    update public.production_requests r
    set status = 'cancelled'
    where r.production_day_id = v_day_id
      and r.source_type = 'base'
      and r.status = 'pending'
      and not exists (
        select 1
        from public.daily_production_selection_items i
        where i.daily_selection_id = v_selection_id
          and i.production_request_id = r.id
      )
    returning 1
  )
  select count(*) into v_stale_count from stale;
  v_cancelled := v_cancelled + v_stale_count;

  -- 6. Confirm the selection.
  update public.daily_production_selections
  set status = 'confirmed',
      confirmed_by = v_user_id,
      confirmed_at = now(),
      updated_by = v_user_id,
      updated_at = now()
  where id = v_selection_id;

  return jsonb_build_object(
    'selection_id', v_selection_id,
    'production_day_id', v_day_id,
    'status', 'confirmed',
    'items_total', v_total,
    'items_selected', v_selected,
    'requests_created', v_created,
    'requests_updated', v_updated,
    'requests_cancelled', v_cancelled,
    'requests_preserved', v_preserved
  );
end;
$$;

comment on function public.confirm_daily_production() is
  'V6.11 (spec §60): atomically reconcile the current business day''s daily selection into the existing base production-request model (create/link pending base requests for selected items, cancel stale pending base production, preserve in-progress/completed and additional/external_order) and confirm the selection. Operator, supervisor and admin only.';

revoke execute on function public.confirm_daily_production() from public;
revoke execute on function public.confirm_daily_production() from anon, authenticated, service_role;
grant execute on function public.confirm_daily_production() to authenticated;

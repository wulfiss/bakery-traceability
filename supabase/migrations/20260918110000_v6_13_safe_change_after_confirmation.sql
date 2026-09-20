-- V6.13 (spec §62): SAFE CHANGE AFTER CONFIRMATION.
--
-- Scenario the spec pins down: suggestion B is confirmed, Baguette is
-- already in_progress, Chip and Pebete are still pending, and the user
-- selects suggestion C. Requirements implemented here:
--   * the in_progress request (Baguette) is preserved and locked: its row,
--     quantity, batch and history are never modified, and its selection
--     item stays linked;
--   * pending B-only items that C does not select are safely cancelled
--     (history-safe status = 'cancelled');
--   * C's selected items create/update pending base requests; an existing
--     pending request for the same (product, shift) is linked and its
--     quantity updated WHILE IT IS STILL PENDING;
--   * quantities of in_progress/completed requests are never rewritten;
--   * external_order and additional production is never touched;
--   * the new selection is DRAFT until re-confirmed (re-confirming is
--     idempotent and creates no duplicates);
--   * operator AND supervisor/admin can perform the change (unchanged role
--     gates on choose_daily_production_suggestion).
--
-- Implementation:
--   1. reconcile_daily_production_selection(uuid, uuid, uuid) — NEW internal
--      helper: the exact reconciliation loop + catch-all sweep that
--      confirm_daily_production has always run (moved verbatim, so both
--      entry points share one implementation and can never drift).
--      Internal only: revoked from every role, no grants — it is called
--      exclusively by the two SECURITY DEFINER RPCs below.
--   2. choose_daily_production_suggestion — extended refresh path:
--        * when a selection already exists, items linked to PENDING BASE
--          requests are unlinked first (that production has not started, so
--          it is not "locked"); their request rows become orphaned and the
--          reconciliation cancels them unless the new snapshot re-selects
--          the same (product, shift);
--        * items linked to in_progress/completed requests stay linked
--          (locked, preserved);
--        * after the new snapshot, snapshot rows that duplicate a preserved
--          item locked by an in_progress/completed BASE request on the same
--          (product, shift) are dropped: that production has started or
--          finished, its quantity must never be rewritten, and a second
--          base request for the same (product, shift) would double it.
--          Items linked to additional/external_order are NOT suppressed:
--          the planned base row for that (product, shift) still stands,
--          and the additional/external request is left untouched;
--        * the reconciliation then runs: selected items link/create pending
--          base requests (quantity synced only while pending), stale
--          pending base production is cancelled.
--      The reconciliation (and with it any creation of NEW base requests)
--      only runs when the day already HAS base requests — i.e. the
--      selection was confirmed before (spec §62). A freshly CREATED
--      selection and any refresh of a never-confirmed draft are NOT
--      reconciled: base production must only appear after confirmation
--      (spec §61), and such drafts carry no requests. (Dedup of snapshot
--      rows against preserved linked items still applies on refresh.)
--      The day row is locked (for update) before the selection is read,
--      the same lock the base generator and confirm use, so a concurrent
--      confirm on the same day serializes cleanly.
--   3. confirm_daily_production — slimmed to gates + helper call +
--      confirmation stamp; its return shape is byte-for-byte unchanged.
--
-- Error tokens: unchanged on both public RPCs (not_authenticated,
-- no_active_profile, insufficient_role, production_day_not_found,
-- suggestion_not_found, weekday_mismatch / no_selection_for_today).
-- The internal helper raises 'selection_not_found' on bad input (it is
-- unreachable from clients: no grants).
--
-- Legacy planning tables and all existing grants are untouched.

-- ---------------------------------------------------------------------------
-- 1. Internal reconciliation helper (shared by choose and confirm).
--    Callers must already hold the production day row lock (for update).
-- ---------------------------------------------------------------------------
create or replace function public.reconcile_daily_production_selection(
  p_selection_id uuid,
  p_day_id uuid,
  p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_selection_day uuid;
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
  -- Consistency: the selection must exist and belong to the given day.
  select production_day_id into v_selection_day
  from public.daily_production_selections
  where id = p_selection_id;
  if v_selection_day is null or v_selection_day <> p_day_id then
    raise exception 'selection_not_found';
  end if;

  -- Reconcile every snapshot item (verbatim from V6.11 confirm).
  for v_item in
    select i.id, i.product_id, i.shift_code, i.quantity, i.unit,
           i.is_selected, i.production_request_id
    from public.daily_production_selection_items i
    where i.daily_selection_id = p_selection_id
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
      where r.production_day_id = p_day_id
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
          p_day_id, 'base', v_item.shift_code, v_item.product_id,
          v_item.quantity, v_item.unit, 'pending', p_user_id
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

  -- Catch-all: old pending base requests of the day that no selection item
  -- references (products no longer selected) are cancelled.
  with stale as (
    update public.production_requests r
    set status = 'cancelled'
    where r.production_day_id = p_day_id
      and r.source_type = 'base'
      and r.status = 'pending'
      and not exists (
        select 1
        from public.daily_production_selection_items i
        where i.daily_selection_id = p_selection_id
          and i.production_request_id = r.id
      )
    returning 1
  )
  select count(*) into v_stale_count from stale;
  v_cancelled := v_cancelled + v_stale_count;

  return jsonb_build_object(
    'items_total', v_total,
    'items_selected', v_selected,
    'requests_created', v_created,
    'requests_updated', v_updated,
    'requests_cancelled', v_cancelled,
    'requests_preserved', v_preserved
  );
end;
$$;

comment on function public.reconcile_daily_production_selection(uuid, uuid, uuid) is
  'V6.13 (spec §62) INTERNAL: safe reconciliation of a daily selection into the base production-request model (create/link pending base requests for selected items, sync quantity only while pending, cancel stale pending base production, preserve in_progress/completed and additional/external_order). Internal only — no client grants; called by choose_daily_production_suggestion and confirm_daily_production, which hold the day-row lock.';

revoke execute on function public.reconcile_daily_production_selection(uuid, uuid, uuid) from public;
revoke execute on function public.reconcile_daily_production_selection(uuid, uuid, uuid) from anon, authenticated, service_role;
-- No grants: the two SECURITY DEFINER RPCs run as the function owner.

-- ---------------------------------------------------------------------------
-- 2. choose_daily_production_suggestion — V6.13 refresh path.
--    Signature, gates and error tokens unchanged; the return gains the four
--    requests_* counters (zero on a freshly created selection).
-- ---------------------------------------------------------------------------
create or replace function public.choose_daily_production_suggestion(
  p_production_day_id uuid,
  p_suggestion_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_role text;
  v_date date;
  v_weekday smallint;
  v_suggestion_weekday smallint;
  v_selection_id uuid;
  v_selection_suggestion_id uuid;
  v_refreshed boolean := false;
  v_items_snapshot integer := 0;
  v_items_preserved integer := 0;
  v_items_removed integer := 0;
  v_items_deduped integer := 0;
  v_day_base_requests integer := 0;
  v_changed_suggestion boolean;
  v_reconciled jsonb;
begin
  -- 1. Authentication, active profile, role.
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

  -- 2. Production day exists.
  select production_date into v_date
  from public.production_days
  where id = p_production_day_id;
  if v_date is null then
    raise exception 'production_day_not_found';
  end if;

  -- 3. Suggestion exists and is active.
  select weekday into v_suggestion_weekday
  from public.production_suggestions
  where id = p_suggestion_id and active;
  if v_suggestion_weekday is null then
    raise exception 'suggestion_not_found';
  end if;

  -- 4. Weekday of the suggestion matches the stored production date
  --    (business date, never recalculated from session time).
  v_weekday := extract(isodow from v_date)::smallint;
  if v_weekday <> v_suggestion_weekday then
    raise exception 'weekday_mismatch';
  end if;

  -- 4b. V6.13: this RPC now writes the day's base requests (via the
  --     reconciliation), so it takes the same day-row lock the base
  --     generator and confirm_daily_production use, before reading the
  --     selection (concurrent confirmations serialize cleanly).
  perform 1
  from public.production_days
  where id = p_production_day_id
  for update;

  -- 5. Existing selection for this production day?
  select id, suggestion_id into v_selection_id, v_selection_suggestion_id
  from public.daily_production_selections
  where production_day_id = p_production_day_id;

  if v_selection_id is null then
    -- 5a. Create the day's selection (status draft). Not reconciled: a
    --     draft carries no requests (base production appears only after
    --     confirmation, spec §61).
    insert into public.daily_production_selections
      (production_day_id, suggestion_id, status, selected_by, selected_at, updated_by, updated_at)
    values
      (p_production_day_id, p_suggestion_id, 'draft', v_user_id, now(), v_user_id, now())
    returning id into v_selection_id;
    v_changed_suggestion := true;
  else
    -- 5b. Refresh the existing selection.
    v_refreshed := true;
    v_changed_suggestion := v_selection_suggestion_id <> p_suggestion_id;

    -- V6.13: items linked to PENDING BASE requests are not locked
    -- production — that request has not started, so the link is released
    -- and the item becomes replaceable. Its request row is now orphaned:
    -- the reconciliation re-links it if the new snapshot re-selects the
    -- same (product, shift), or cancels it otherwise.
    update public.daily_production_selection_items i
    set production_request_id = null,
        updated_at = now()
    where i.daily_selection_id = v_selection_id
      and exists (
        select 1
        from public.production_requests r
        where r.id = i.production_request_id
          and r.status = 'pending'
          and r.source_type = 'base'
      );

    -- Preserve items already linked to production (started/completed, or
    -- other sources): they stay exactly as they are, never rewritten.
    select count(*) into v_items_preserved
    from public.daily_production_selection_items
    where daily_selection_id = v_selection_id
      and production_request_id is not null;

    -- Pending/unstarted items (no request linked) may be replaced or
    -- reconciled when the suggestion changes (or is re-snapshotted).
    with removed as (
      delete from public.daily_production_selection_items
      where daily_selection_id = v_selection_id
        and production_request_id is null
      returning 1
    )
    select count(*) into v_items_removed from removed;

    update public.daily_production_selections
    set suggestion_id = p_suggestion_id,
        status = 'draft',
        confirmed_by = null,
        confirmed_at = null,
        updated_by = v_user_id,
        updated_at = now()
    where id = v_selection_id;
  end if;

  -- 6. Snapshot the suggestion's active items (source order preserved),
  --    all checked by default; not linked to any request yet.
  insert into public.daily_production_selection_items
    (daily_selection_id, source_suggestion_item_id, product_id, shift_code,
     quantity, unit, is_selected, production_request_id, sort_order)
  select v_selection_id, m.id, m.product_id, m.shift_code,
         m.suggested_quantity, m.unit, true, null, m.sort_order
  from public.production_suggestion_items m
  where m.suggestion_id = p_suggestion_id
    and m.active;

  -- 6b. V6.13: drop snapshot rows that duplicate a preserved item locked by
  --     an in_progress/completed BASE request on the same (product, shift):
  --     that production has started or finished, its quantity must never be
  --     rewritten, and a second base request for the same (product, shift)
  --     would double it. Items linked to additional/external_order are NOT
  --     suppressed: the planned base row for that (product, shift) still
  --     stands, and the additional/external request stays untouched.
  if v_refreshed then
    with deduped as (
      delete from public.daily_production_selection_items i
      where i.daily_selection_id = v_selection_id
        and i.production_request_id is null
        and exists (
          select 1
          from public.daily_production_selection_items i2
          join public.production_requests r2 on r2.id = i2.production_request_id
          where i2.daily_selection_id = v_selection_id
            and i2.production_request_id is not null
            and r2.source_type = 'base'
            and r2.status in ('in_progress', 'completed')
            and i2.product_id = i.product_id
            and i2.shift_code = i.shift_code
        )
      returning 1
    )
    select count(*) into v_items_deduped from deduped;

    -- 7. V6.13: reconcile the refreshed snapshot against the day's existing
    --     requests — the same safe rules confirm uses (shared helper):
    --     create/link pending base for selected items, sync quantity only
    --     while pending, cancel stale pending base, never touch
    --     in_progress/completed/additional/external_order. Only runs when
    --     the day already HAS base requests (it was confirmed before,
    --     spec §62); a never-confirmed draft carries no requests (§61).
    select count(*) into v_day_base_requests
    from public.production_requests
    where production_day_id = p_production_day_id
      and source_type = 'base';
    if v_day_base_requests > 0 then
      v_reconciled := public.reconcile_daily_production_selection(
        v_selection_id, p_production_day_id, v_user_id
      );
    end if;
  end if;

  select count(*) into v_items_snapshot
  from public.daily_production_selection_items
  where daily_selection_id = v_selection_id
    and production_request_id is null;

  return jsonb_build_object(
    'selection_id', v_selection_id,
    'production_day_id', p_production_day_id,
    'suggestion_id', p_suggestion_id,
    'status', 'draft',
    'changed_suggestion', v_changed_suggestion,
    'items_snapshot', v_items_snapshot,
    'items_preserved', v_items_preserved,
    'items_removed', v_items_removed,
    'requests_created', coalesce((v_reconciled ->> 'requests_created')::integer, 0),
    'requests_updated', coalesce((v_reconciled ->> 'requests_updated')::integer, 0),
    'requests_cancelled', coalesce((v_reconciled ->> 'requests_cancelled')::integer, 0),
    'requests_preserved', coalesce((v_reconciled ->> 'requests_preserved')::integer, 0)
  );
end;
$$;

comment on function public.choose_daily_production_suggestion(uuid, uuid) is
  'V6.8/V6.13 (spec §57/§62): choose or change the day''s master suggestion. Creates or refreshes the single daily selection for the production day (status draft, no confirmation stamp). On refresh, items linked to pending base requests are unlinked and re-reconciled, items linked to started/finished production stay locked and preserved, and the day''s base requests are reconciled to the new snapshot (safe create/link/cancel). Operator, supervisor and admin only.';

revoke execute on function public.choose_daily_production_suggestion(uuid, uuid) from public;
revoke execute on function public.choose_daily_production_suggestion(uuid, uuid) from anon, authenticated, service_role;
grant execute on function public.choose_daily_production_suggestion(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. confirm_daily_production — V6.13: gates + shared helper + stamp.
--    Return shape unchanged (items_total, items_selected, requests_*).
-- ---------------------------------------------------------------------------
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
  v_reconciled jsonb;
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

  -- 4. V6.13: reconcile via the shared helper (same rules and counters the
  --    V6.11 body ran inline).
  v_reconciled := public.reconcile_daily_production_selection(
    v_selection_id, v_day_id, v_user_id
  );

  -- 5. Confirm the selection.
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
    'items_total', (v_reconciled ->> 'items_total')::integer,
    'items_selected', (v_reconciled ->> 'items_selected')::integer,
    'requests_created', (v_reconciled ->> 'requests_created')::integer,
    'requests_updated', (v_reconciled ->> 'requests_updated')::integer,
    'requests_cancelled', (v_reconciled ->> 'requests_cancelled')::integer,
    'requests_preserved', (v_reconciled ->> 'requests_preserved')::integer
  );
end;
$$;

comment on function public.confirm_daily_production() is
  'V6.11/V6.13 (spec §60/§62): atomically reconcile the current business day''s daily selection into the existing base production-request model (shared internal helper: create/link pending base requests for selected items, cancel stale pending base production, preserve in-progress/completed and additional/external_order) and confirm the selection. Operator, supervisor and admin only.';

revoke execute on function public.confirm_daily_production() from public;
revoke execute on function public.confirm_daily_production() from anon, authenticated, service_role;
grant execute on function public.confirm_daily_production() to authenticated;

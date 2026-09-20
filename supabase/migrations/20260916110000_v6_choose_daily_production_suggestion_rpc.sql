-- V6.8: RPC to choose/change the daily production suggestion (spec §57).
--
-- choose_daily_production_suggestion(p_production_day_id, p_suggestion_id):
-- the single secure write path for the DAILY layer of the three-layer model
-- (spec §69): master suggestion -> daily selection -> request batch.
--
-- Behavior:
--   * no selection for the day yet -> create it (status 'draft') and snapshot
--     the suggestion's active items with is_selected = true;
--   * selection with the SAME suggestion -> refresh the snapshot: pending
--     items (no production request linked yet) are replaced, linked items
--     are preserved;
--   * selection with a DIFFERENT suggestion (B -> C) -> same reconciliation:
--     pending/unstarted items of B are removed, items already linked to a
--     production request (started/completed production) are preserved
--     untouched ("locked"), C's items are snapshotted, status = 'draft'.
--
-- Invariants:
--   * one selection per production day (enforced by the unique
--     production_day_id column, V6.5);
--   * items with production_request_id NOT NULL are never deleted or
--     rewritten by this function - started/completed history is intact;
--   * the function never touches production_requests (external_order or
--     additional) - request confirmation is a later V6 step;
--   * a draft selection carries no confirmation stamp: on refresh,
--     confirmed_by/confirmed_at are reset to NULL. The audit of a previous
--     confirmation survives on the production_requests rows that the
--     preserved items still point to (production_request_id).
--
-- The suggestion's weekday must match the production day's date in the
-- business timezone (America/Argentina/Cordoba): production_date is a date,
-- extract(isodow) gives 1 = Monday ... 7 = Sunday, the same convention as
-- production_suggestions.weekday.
--
-- Roles: operator (production personnel) plus supervisor/admin (V5 role
-- model, spec §57).
--
-- Error tokens:
--   not_authenticated, no_active_profile, insufficient_role,
--   production_day_not_found, suggestion_not_found (missing or inactive),
--   weekday_mismatch.
--
-- No UI in this step (spec §57).

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
  v_items_snapshot integer := 0;
  v_items_preserved integer := 0;
  v_items_removed integer := 0;
  v_changed_suggestion boolean;
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

  -- 5. Existing selection for this production day?
  select id, suggestion_id into v_selection_id, v_selection_suggestion_id
  from public.daily_production_selections
  where production_day_id = p_production_day_id;

  if v_selection_id is null then
    -- 5a. Create the day's selection (status draft).
    insert into public.daily_production_selections
      (production_day_id, suggestion_id, status, selected_by, selected_at, updated_by, updated_at)
    values
      (p_production_day_id, p_suggestion_id, 'draft', v_user_id, now(), v_user_id, now())
    returning id into v_selection_id;
    v_changed_suggestion := true;
  else
    -- 5b. Refresh the existing selection.
    v_changed_suggestion := v_selection_suggestion_id <> p_suggestion_id;

    -- Preserve items already linked to production (started/completed):
    -- they stay exactly as they are; this function never rewrites them.
    select count(*) into v_items_preserved
    from public.daily_production_selection_items
    where daily_selection_id = v_selection_id
      and production_request_id is not null;

    -- Pending/unstarted items (no request linked yet) may be replaced or
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
    'items_removed', v_items_removed
  );
end;
$$;

comment on function public.choose_daily_production_suggestion(uuid, uuid) is
  'V6.8 (spec §57): choose or change the day''s master suggestion. Creates or refreshes the single daily selection for the production day, snapshots the suggestion''s items checked by default (status draft), and preserves items already linked to started/completed production. Operator, supervisor and admin only.';

revoke execute on function public.choose_daily_production_suggestion(uuid, uuid) from public;
revoke execute on function public.choose_daily_production_suggestion(uuid, uuid) from anon, authenticated, service_role;
grant execute on function public.choose_daily_production_suggestion(uuid, uuid) to authenticated;

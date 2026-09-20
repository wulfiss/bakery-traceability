-- V6.10: RPC to check/uncheck a daily selection item (spec §59).
--
-- toggle_daily_selection_item(p_item_id):
-- the single secure write path for toggling is_selected on the DAILY layer
-- of the three-layer model (spec §69): master suggestion -> daily selection
-- -> request batch. No UI in this file; the review page server action calls
-- it (no direct table writes from the browser; the table only has SELECT
-- policies for authenticated active profiles).
--
-- Behavior:
--   * the item must belong to the CURRENT business day's selection
--     (ensure_production_day, business date in America/Argentina/Cordoba,
--     never recalculated from session time elsewhere);
--   * flips is_selected and stamps the selection's updated_by/updated_at;
--   * toggling a CONFIRMED selection returns it to draft: status -> 'draft'
--     and confirmed_by/confirmed_at reset to NULL (same reset semantics as
--     choose_daily_production_suggestion, V6.8);
--   * an item linked to an in_progress or completed production request is
--     LOCKED: the toggle is refused (item_locked). Items linked to a
--     pending request are not locked: V6.11 reconciliation may still
--     adjust that pending request.
--
-- Invariants:
--   * only flips is_selected / updated_at on the item row; quantities,
--     units, shifts and links are never touched here;
--   * never touches production_requests (external_order or additional);
--   * one selection per production day (V6.5) is assumed, not enforced here.
--
-- Roles: operator (production personnel) plus supervisor/admin (V5 role
-- model, spec §59).
--
-- Error tokens:
--   not_authenticated, no_active_profile, insufficient_role,
--   item_not_found, not_current_production_day, item_locked.
--
-- No UI in this file (spec §59: the review screen consumes this RPC).

create or replace function public.toggle_daily_selection_item(p_item_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_role text;
  v_day_id uuid;
  v_item_id uuid;
  v_selection_id uuid;
  v_selection_day_id uuid;
  v_selection_status text;
  v_item_is_selected boolean;
  v_request_id uuid;
  v_request_status text;
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

  -- 2. The current business day.
  v_day_id := public.ensure_production_day();

  -- 3. The item and its selection.
  select i.id, s.id, s.production_day_id, s.status, i.is_selected,
         i.production_request_id
    into v_item_id, v_selection_id, v_selection_day_id,
         v_selection_status, v_item_is_selected, v_request_id
  from public.daily_production_selection_items i
  join public.daily_production_selections s on s.id = i.daily_selection_id
  where i.id = p_item_id;
  if v_item_id is null then
    raise exception 'item_not_found';
  end if;

  -- 4. Only the current business day's selection may be modified.
  if v_selection_day_id <> v_day_id then
    raise exception 'not_current_production_day';
  end if;

  -- 5. Items linked to in-progress or completed production are locked.
  if v_request_id is not null then
    select status into v_request_status
    from public.production_requests
    where id = v_request_id;
    if v_request_status in ('in_progress', 'completed') then
      raise exception 'item_locked';
    end if;
  end if;

  -- 6. Flip the item.
  update public.daily_production_selection_items
  set is_selected = not is_selected,
      updated_at = now()
  where id = p_item_id;

  -- 7. Stamp the selection; a confirmed selection returns to draft.
  update public.daily_production_selections
  set status = case when status = 'confirmed' then 'draft' else status end,
      confirmed_by = case when status = 'confirmed' then null else confirmed_by end,
      confirmed_at = case when status = 'confirmed' then null else confirmed_at end,
      updated_by = v_user_id,
      updated_at = now()
  where id = v_selection_id;

  return jsonb_build_object(
    'item_id', p_item_id,
    'is_selected', not v_item_is_selected,
    'selection_id', v_selection_id,
    'status', case when v_selection_status = 'confirmed' then 'draft' else v_selection_status end,
    'production_day_id', v_day_id
  );
end;
$$;

comment on function public.toggle_daily_selection_item(uuid) is
  'V6.10 (spec §59): check/uncheck one item of the current business day''s daily selection. Refuses items locked by in-progress/completed production; toggling a confirmed selection returns it to draft. Operator, supervisor and admin only.';

revoke execute on function public.toggle_daily_selection_item(uuid) from public;
revoke execute on function public.toggle_daily_selection_item(uuid) from anon, authenticated, service_role;
grant execute on function public.toggle_daily_selection_item(uuid) to authenticated;

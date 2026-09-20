-- V6.12 (spec §61): deactivate the legacy base production generator.
--
-- The confirmed daily suggestion is now the authoritative source of normal
-- base production: choose_daily_production_suggestion (V6.8) -> daily
-- selection -> confirm_daily_production (V6.11) creates the 'base' requests.
-- The old weekly-plan generator (production_plan_items -> production_requests)
-- is replaced by a no-op that preserves the EXACT same signature, error
-- tokens, auth gates and day-row lock, so existing callers (the /production
-- page load) keep working unchanged. It never creates rows anymore, so it
-- cannot create duplicates next to the suggestion flow.
--
-- Consequences (spec §61):
--   * until a suggestion is confirmed, /production shows
--     "No hay producción sugerida confirmada." and no base requests exist
--     for the day (the list only holds external_order/additional rows);
--   * after confirmation, only the checked items appear as base production;
--   * external orders (ensure_external_order_requests) and additional
--     production (its own RPC) are untouched and continue normally;
--   * the legacy planning tables (production_plan_items, ...) are NOT
--     dropped: they remain readable history (spec: "Do not remove legacy
--     planning tables unless clearly necessary").
--
-- Error tokens preserved: not_authenticated, no_active_profile,
-- production_day_not_found. Return type preserved: integer (always 0).

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
begin
  -- Same gates as before deactivation.
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if not exists (select 1 from public.profiles where id = v_user_id and active) then
    raise exception 'no_active_profile';
  end if;

  if not exists (select 1 from public.production_days where id = p_production_day_id) then
    raise exception 'production_day_not_found';
  end if;

  -- Same day-row lock as before (ensure_external_order_requests takes the
  -- same lock right after; keeping it preserves the original lock order and
  -- serializes the page load against confirm_daily_production, which also
  -- locks this row), even though this function no longer writes.
  perform 1
  from public.production_days
  where id = p_production_day_id
  for update;

  -- V6.12: generation is DEACTIVATED. Base requests are created only by
  -- confirm_daily_production from the confirmed daily selection.
  return 0;
end;
$$;

comment on function public.ensure_base_production_requests(uuid) is
  'DEACTIVATED in V6.12 (spec §61): no longer creates base production requests from production_plan_items; the confirmed daily suggestion (confirm_daily_production) is the sole source of base production. Signature, auth gates, day validation and day-row lock are preserved so existing callers keep working; returns 0.';

-- Grants are unchanged: the original migration revoked PUBLIC/anon/
-- service_role and granted only to authenticated (create or replace keeps
-- existing grants).

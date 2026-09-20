-- V6.9 (spec §58): minimum SELECT RLS policies for the suggested-production
-- tables: master suggestion templates and the daily selection state.
--
-- Same access model as the U1/U2 operational reads:
-- - only the `authenticated` Postgres role receives a policy;
-- - the requesting user must have a profile row (id = auth.uid()) with
--   active = true;
-- - SELECT only: no INSERT/UPDATE/DELETE policies. Daily selections are
--   written exclusively through choose_daily_production_suggestion (V6.8),
--   and the master templates only through the controlled seed RPC.

create policy production_suggestions_select_active
  on public.production_suggestions
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

create policy production_suggestion_items_select_active
  on public.production_suggestion_items
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

create policy daily_production_selections_select_active
  on public.daily_production_selections
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

create policy daily_production_selection_items_select_active
  on public.daily_production_selection_items
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

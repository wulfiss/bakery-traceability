-- V6.5: SELECT-only RLS for the daily selection tables (spec §54:
-- "Enable RLS. Do not allow direct client writes.").
--
-- Same access model as rls_master_data_select and
-- rls_production_suggestions_select:
-- - only the `authenticated` Postgres role receives a policy;
-- - the requesting user must have a profile row (id = auth.uid()) with
--   active = true;
-- - SELECT only: no INSERT/UPDATE/DELETE policies, so authenticated users
--   cannot write to these tables (RLS denies by default). Later V6 steps
--   write through SECURITY DEFINER RPCs only.

create policy daily_production_selections_select_active
  on public.daily_production_selections
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

create policy daily_production_selection_items_select_active
  on public.daily_production_selection_items
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

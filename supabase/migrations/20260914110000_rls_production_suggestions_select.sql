-- V6.4: SELECT-only RLS for the master suggested-production tables
-- (spec §53: "READ policies appropriate for active authenticated
-- production users. Do not add client direct-write policies.").
--
-- Same access model as rls_master_data_select:
-- - only the `authenticated` Postgres role receives a policy;
-- - the requesting user must have a profile row (id = auth.uid()) with
--   active = true;
-- - SELECT only: no INSERT/UPDATE/DELETE policies, so authenticated users
--   cannot write to these tables (RLS denies by default). Later V6 steps
--   write through SECURITY DEFINER RPCs only.

create policy production_suggestions_select_active
  on public.production_suggestions
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

create policy production_suggestion_items_select_active
  on public.production_suggestion_items
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

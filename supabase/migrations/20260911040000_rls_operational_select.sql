-- Phase U2: minimum SELECT RLS policies for operational tables.
--
-- Same access model as U1:
-- - only the `authenticated` Postgres role receives a policy;
-- - the requesting user must have a profile row (id = auth.uid()) with active = true;
-- - SELECT only: no INSERT/UPDATE/DELETE policies, so traceability history
--   cannot be rewritten through direct table writes (controlled operations
--   arrive with later phases).
--
-- Profile reads needed for authorization are already covered by the
-- profiles_select_own policy created in U1 (the user's own row, which
-- carries the role). No additional profile policy is needed.

create policy production_days_select_active
  on public.production_days
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

create policy production_requests_select_active
  on public.production_requests
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

create policy production_batches_select_active
  on public.production_batches
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

create policy batch_materials_select_active
  on public.batch_materials
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

create policy batch_outputs_select_active
  on public.batch_outputs
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

create policy batch_requests_select_active
  on public.batch_requests
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

create policy parent_batch_inputs_select_active
  on public.parent_batch_inputs
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

create policy external_orders_select_active
  on public.external_orders
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

create policy external_order_items_select_active
  on public.external_order_items
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

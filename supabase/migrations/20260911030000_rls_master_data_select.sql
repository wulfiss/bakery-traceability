-- Phase U1: minimum SELECT RLS policies for master data.
--
-- Access model:
-- - only the `authenticated` Postgres role receives a policy;
-- - the requesting user must have a profile row (id = auth.uid()) with active = true;
-- - SELECT only: there are no INSERT/UPDATE/DELETE policies here, so
--   authenticated users cannot write to these tables (RLS denies by default).
--
-- profiles gets a plain identity check (id = auth.uid()). It does not
-- reference profiles itself, so it is not recursive. It is required here
-- because the master-data subquery below is evaluated under RLS and must
-- be able to see the requesting user's own profile row.

create policy profiles_select_own
  on public.profiles
  for select to authenticated
  using (id = auth.uid());

create policy raw_materials_select_active
  on public.raw_materials
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

create policy brands_select_active
  on public.brands
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

create policy raw_material_brands_select_active
  on public.raw_material_brands
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

create policy material_lots_select_active
  on public.material_lots
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

create policy products_select_active
  on public.products
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

create policy recipes_select_active
  on public.recipes
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

create policy recipe_versions_select_active
  on public.recipe_versions
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

create policy recipe_ingredients_select_active
  on public.recipe_ingredients
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

create policy recipe_products_select_active
  on public.recipe_products
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

create policy recipe_product_inputs_select_active
  on public.recipe_product_inputs
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

create policy production_plan_items_select_active
  on public.production_plan_items
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));

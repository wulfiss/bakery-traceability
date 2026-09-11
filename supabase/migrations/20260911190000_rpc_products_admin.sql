-- AL3: controlled management of products master data (admin only).
--
-- Three narrow RPCs, all sharing the same security rules:
--   1. create_product(p_name, p_default_unit, p_default_shift_code) -> uuid
--   2. update_product(p_id, p_name, p_default_unit, p_default_shift_code) -> uuid
--   3. set_product_active(p_id, p_active) -> uuid
--
-- Rules per function:
-- 1. Require an authenticated user with an active profile.
-- 2. Require the admin role (master-data management, per the role model):
--    insufficient_role otherwise.
-- 3. Validate inputs:
--    - name: non-empty after trim (invalid_name);
--    - default_unit: non-empty after trim (invalid_unit);
--    - default_shift_code: one of morning/afternoon/night (invalid_shift);
--    - id: must exist (product_not_found) for update/deactivate.
-- 4. No name uniqueness: the H1 schema spec does not require it (same open
--    business decision as brands in AL2); duplicates are allowed.
-- 5. No physical deletes: deactivation is active = false (six RESTRICT FKs
--    from batch_outputs, external_order_items, production_plan_items,
--    production_requests, recipe_product_inputs, recipe_products).
-- 6. Revoke execution from public/anon/service_role; grant only
--    authenticated (the role gate lives in the body).
--
-- Error tokens (English, developer-facing):
--   not_authenticated, no_active_profile, insufficient_role,
--   product_not_found, invalid_name, invalid_unit, invalid_shift.

create or replace function public.create_product(
  p_name text,
  p_default_unit text,
  p_default_shift_code text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_role text;
  v_name text;
  v_unit text;
  v_shift text;
  v_new_id uuid;
begin
  -- 1. Authentication and active profile.
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

  -- 2. Role gate: only admin manages master data.
  if v_role <> 'admin' then
    raise exception 'insufficient_role';
  end if;

  -- 3. Validation.
  v_name := trim(coalesce(p_name, ''));
  if v_name = '' then
    raise exception 'invalid_name';
  end if;

  v_unit := trim(coalesce(p_default_unit, ''));
  if v_unit = '' then
    raise exception 'invalid_unit';
  end if;

  v_shift := trim(coalesce(p_default_shift_code, ''));
  if v_shift not in ('morning', 'afternoon', 'night') then
    raise exception 'invalid_shift';
  end if;

  -- 4. Insert and return the new id.
  insert into public.products (name, default_unit, default_shift_code)
  values (v_name, v_unit, v_shift)
  returning id into v_new_id;

  return v_new_id;
end;
$$;

create or replace function public.update_product(
  p_id uuid,
  p_name text,
  p_default_unit text,
  p_default_shift_code text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_role text;
  v_name text;
  v_unit text;
  v_shift text;
begin
  -- 1. Authentication and active profile.
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

  -- 2. Role gate: only admin manages master data.
  if v_role <> 'admin' then
    raise exception 'insufficient_role';
  end if;

  -- 3. Validation.
  if not exists (select 1 from public.products where id = p_id) then
    raise exception 'product_not_found';
  end if;

  v_name := trim(coalesce(p_name, ''));
  if v_name = '' then
    raise exception 'invalid_name';
  end if;

  v_unit := trim(coalesce(p_default_unit, ''));
  if v_unit = '' then
    raise exception 'invalid_unit';
  end if;

  v_shift := trim(coalesce(p_default_shift_code, ''));
  if v_shift not in ('morning', 'afternoon', 'night') then
    raise exception 'invalid_shift';
  end if;

  -- 4. Update and return the id. Historical shifts already copied into
  -- production_requests/production_batches are never touched.
  update public.products
  set name = v_name,
      default_unit = v_unit,
      default_shift_code = v_shift,
      updated_at = now()
  where id = p_id;

  return p_id;
end;
$$;

create or replace function public.set_product_active(
  p_id uuid,
  p_active boolean
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_role text;
begin
  -- 1. Authentication and active profile.
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

  -- 2. Role gate: only admin manages master data.
  if v_role <> 'admin' then
    raise exception 'insufficient_role';
  end if;

  -- 3. Validation.
  if not exists (select 1 from public.products where id = p_id) then
    raise exception 'product_not_found';
  end if;

  -- 4. Deactivation is soft (active = false); no physical delete.
  update public.products
  set active = p_active,
      updated_at = now()
  where id = p_id;

  return p_id;
end;
$$;

revoke execute on function public.create_product(text, text, text)
  from public, anon, service_role, authenticated;
grant execute on function public.create_product(text, text, text)
  to authenticated;

revoke execute on function public.update_product(uuid, text, text, text)
  from public, anon, service_role, authenticated;
grant execute on function public.update_product(uuid, text, text, text)
  to authenticated;

revoke execute on function public.set_product_active(uuid, boolean)
  from public, anon, service_role, authenticated;
grant execute on function public.set_product_active(uuid, boolean)
  to authenticated;

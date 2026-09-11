-- AL1: controlled management of raw_materials master data (admin only).
--
-- Three narrow RPCs, all sharing the same security rules:
--   1. create_raw_material(p_name, p_default_unit) -> uuid
--   2. update_raw_material(p_id, p_name, p_default_unit) -> uuid
--   3. set_raw_material_active(p_id, p_active) -> uuid
--
-- Rules per function:
-- 1. Require an authenticated user with an active profile.
-- 2. Require the admin role (master-data management, per the role model):
--    insufficient_role otherwise.
-- 3. Validate inputs:
--    - name: non-empty after trim (invalid_name);
--    - default_unit: non-empty after trim (invalid_unit);
--    - name: case-insensitively unique (raw_material_name_exists);
--    - id: must exist (raw_material_not_found) for update/deactivate.
-- 4. No physical deletes: deactivation is active = false.
-- 5. Revoke execution from public/anon/service_role; grant only
--    authenticated (the role gate lives in the body).
--
-- Error tokens (English, developer-facing):
--   not_authenticated, no_active_profile, insufficient_role,
--   raw_material_not_found, raw_material_name_exists, invalid_name,
--   invalid_unit.

create or replace function public.create_raw_material(
  p_name text,
  p_default_unit text
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

  if exists (select 1 from public.raw_materials where lower(name) = lower(v_name)) then
    raise exception 'raw_material_name_exists';
  end if;

  -- 4. Insert and return the new id.
  insert into public.raw_materials (name, default_unit)
  values (v_name, v_unit)
  returning id into v_new_id;

  return v_new_id;
end;
$$;

create or replace function public.update_raw_material(
  p_id uuid,
  p_name text,
  p_default_unit text
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
  if not exists (select 1 from public.raw_materials where id = p_id) then
    raise exception 'raw_material_not_found';
  end if;

  v_name := trim(coalesce(p_name, ''));
  if v_name = '' then
    raise exception 'invalid_name';
  end if;

  v_unit := trim(coalesce(p_default_unit, ''));
  if v_unit = '' then
    raise exception 'invalid_unit';
  end if;

  if exists (
    select 1 from public.raw_materials
    where lower(name) = lower(v_name) and id <> p_id
  ) then
    raise exception 'raw_material_name_exists';
  end if;

  -- 4. Update and return the id.
  update public.raw_materials
  set name = v_name,
      default_unit = v_unit,
      updated_at = now()
  where id = p_id;

  return p_id;
end;
$$;

create or replace function public.set_raw_material_active(
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
  if not exists (select 1 from public.raw_materials where id = p_id) then
    raise exception 'raw_material_not_found';
  end if;

  -- 4. Deactivation is soft (active = false); no physical delete.
  update public.raw_materials
  set active = p_active,
      updated_at = now()
  where id = p_id;

  return p_id;
end;
$$;

revoke execute on function public.create_raw_material(text, text)
  from public, anon, service_role, authenticated;
grant execute on function public.create_raw_material(text, text)
  to authenticated;

revoke execute on function public.update_raw_material(uuid, text, text)
  from public, anon, service_role, authenticated;
grant execute on function public.update_raw_material(uuid, text, text)
  to authenticated;

revoke execute on function public.set_raw_material_active(uuid, boolean)
  from public, anon, service_role, authenticated;
grant execute on function public.set_raw_material_active(uuid, boolean)
  to authenticated;

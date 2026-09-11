-- AL2: controlled management of brands master data (admin only).
--
-- Three narrow RPCs, all sharing the same security rules:
--   1. create_brand(p_name) -> uuid
--   2. update_brand(p_id, p_name) -> uuid
--   3. set_brand_active(p_id, p_active) -> uuid
--
-- Rules per function:
-- 1. Require an authenticated user with an active profile.
-- 2. Require the admin role (master-data management, per the role model):
--    insufficient_role otherwise.
-- 3. Validate inputs:
--    - name: non-empty after trim (invalid_name);
--    - id: must exist (brand_not_found) for update/deactivate.
-- 4. Brand names are NOT uniqueness-constrained: the F2 schema spec requires
--    only a non-empty name (unlike raw_materials, whose F1 spec asked for a
--    case-insensitive uniqueness strategy). Duplicate names are allowed by
--    design until a business decision says otherwise.
-- 5. No physical deletes: deactivation is active = false.
-- 6. Revoke execution from public/anon/service_role; grant only
--    authenticated (the role gate lives in the body).
--
-- Error tokens (English, developer-facing):
--   not_authenticated, no_active_profile, insufficient_role,
--   brand_not_found, invalid_name.

create or replace function public.create_brand(
  p_name text
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

  -- 4. Insert and return the new id.
  insert into public.brands (name)
  values (v_name)
  returning id into v_new_id;

  return v_new_id;
end;
$$;

create or replace function public.update_brand(
  p_id uuid,
  p_name text
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
  if not exists (select 1 from public.brands where id = p_id) then
    raise exception 'brand_not_found';
  end if;

  v_name := trim(coalesce(p_name, ''));
  if v_name = '' then
    raise exception 'invalid_name';
  end if;

  -- 4. Update and return the id.
  update public.brands
  set name = v_name,
      updated_at = now()
  where id = p_id;

  return p_id;
end;
$$;

create or replace function public.set_brand_active(
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
  if not exists (select 1 from public.brands where id = p_id) then
    raise exception 'brand_not_found';
  end if;

  -- 4. Deactivation is soft (active = false); no physical delete.
  update public.brands
  set active = p_active,
      updated_at = now()
  where id = p_id;

  return p_id;
end;
$$;

revoke execute on function public.create_brand(text)
  from public, anon, service_role, authenticated;
grant execute on function public.create_brand(text)
  to authenticated;

revoke execute on function public.update_brand(uuid, text)
  from public, anon, service_role, authenticated;
grant execute on function public.update_brand(uuid, text)
  to authenticated;

revoke execute on function public.set_brand_active(uuid, boolean)
  from public, anon, service_role, authenticated;
grant execute on function public.set_brand_active(uuid, boolean)
  to authenticated;

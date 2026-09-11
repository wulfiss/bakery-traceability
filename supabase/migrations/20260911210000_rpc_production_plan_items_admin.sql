-- AL5: controlled management of the weekly base production plan
-- (production_plan_items) — the last admin master-data page.
--
-- Three narrow RPCs, all sharing the same security rules:
--   1. create_production_plan_item(p_weekday smallint, p_shift_code text,
--      p_product_id uuid, p_planned_quantity numeric, p_unit text) -> uuid
--   2. update_production_plan_item(p_id uuid, p_weekday smallint,
--      p_shift_code text, p_product_id uuid, p_planned_quantity numeric,
--      p_unit text) -> uuid
--   3. set_production_plan_item_active(p_id uuid, p_active boolean) -> uuid
--
-- Rules per function:
-- 1. Require an authenticated user with an active profile.
-- 2. Require the admin role (master-data management, per the role model):
--    insufficient_role otherwise.
-- 3. Validate inputs:
--    - weekday: 1 (Monday) .. 7 (Sunday) (invalid_weekday);
--    - shift_code: morning / afternoon / night (invalid_shift);
--    - product: must exist (product_not_found);
--    - planned_quantity: > 0 (invalid_quantity);
--    - unit: non-empty after trim (invalid_unit);
--    - id: must exist (production_plan_item_not_found) for update/deactivate.
-- 4. At most one ACTIVE row per (weekday, shift_code, product_id, unit), per
--    the partial unique index: create/update/enabling a row that would
--    duplicate an existing ACTIVE row raises already_planned. Deactivated
--    rows never conflict.
-- 5. Create assigns sort_order = max(sort_order) + 1 within the same
--    (weekday, shift_code) group; update never changes sort_order.
-- 6. No physical deletes: deactivation is active = false (production_requests
--    copy plan data at request-generation time and keep no FK back, so editing
--    a plan item never rewrites generated requests).
-- 7. Revoke execution from public/anon/service_role; grant only
--    authenticated (the role gate lives in the body).
--
-- Error tokens (English, developer-facing):
--   not_authenticated, no_active_profile, insufficient_role,
--   production_plan_item_not_found, product_not_found, invalid_weekday,
--   invalid_shift, invalid_quantity, invalid_unit, already_planned.

create or replace function public.create_production_plan_item(
  p_weekday smallint,
  p_shift_code text,
  p_product_id uuid,
  p_planned_quantity numeric,
  p_unit text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_role text;
  v_shift text;
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
  if p_weekday is null or p_weekday < 1 or p_weekday > 7 then
    raise exception 'invalid_weekday';
  end if;

  v_shift := trim(coalesce(p_shift_code, ''));
  if v_shift not in ('morning', 'afternoon', 'night') then
    raise exception 'invalid_shift';
  end if;

  if not exists (select 1 from public.products where id = p_product_id) then
    raise exception 'product_not_found';
  end if;

  if p_planned_quantity is null or p_planned_quantity <= 0 then
    raise exception 'invalid_quantity';
  end if;

  v_unit := trim(coalesce(p_unit, ''));
  if v_unit = '' then
    raise exception 'invalid_unit';
  end if;

  -- At most one ACTIVE row per (weekday, shift, product, unit).
  if exists (
    select 1
    from public.production_plan_items
    where weekday = p_weekday
      and shift_code = v_shift
      and product_id = p_product_id
      and unit = v_unit
      and active
  ) then
    raise exception 'already_planned';
  end if;

  -- 4. Insert with the next sort_order within the weekday + shift group.
  insert into public.production_plan_items
    (weekday, shift_code, product_id, planned_quantity, unit, sort_order)
  values
    (
      p_weekday,
      v_shift,
      p_product_id,
      p_planned_quantity,
      v_unit,
      (
        select coalesce(max(sort_order), 0) + 1
        from public.production_plan_items
        where weekday = p_weekday and shift_code = v_shift
      )
    )
  returning id into v_new_id;

  return v_new_id;
end;
$$;

create or replace function public.update_production_plan_item(
  p_id uuid,
  p_weekday smallint,
  p_shift_code text,
  p_product_id uuid,
  p_planned_quantity numeric,
  p_unit text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_role text;
  v_shift text;
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
  if not exists (select 1 from public.production_plan_items where id = p_id) then
    raise exception 'production_plan_item_not_found';
  end if;

  if p_weekday is null or p_weekday < 1 or p_weekday > 7 then
    raise exception 'invalid_weekday';
  end if;

  v_shift := trim(coalesce(p_shift_code, ''));
  if v_shift not in ('morning', 'afternoon', 'night') then
    raise exception 'invalid_shift';
  end if;

  if not exists (select 1 from public.products where id = p_product_id) then
    raise exception 'product_not_found';
  end if;

  if p_planned_quantity is null or p_planned_quantity <= 0 then
    raise exception 'invalid_quantity';
  end if;

  v_unit := trim(coalesce(p_unit, ''));
  if v_unit = '' then
    raise exception 'invalid_unit';
  end if;

  -- At most one ACTIVE row per (weekday, shift, product, unit), excluding
  -- this row itself.
  if exists (
    select 1
    from public.production_plan_items
    where weekday = p_weekday
      and shift_code = v_shift
      and product_id = p_product_id
      and unit = v_unit
      and active
      and id <> p_id
  ) then
    raise exception 'already_planned';
  end if;

  -- 4. Update. sort_order is preserved (position in the plan is stable).
  update public.production_plan_items
  set weekday = p_weekday,
      shift_code = v_shift,
      product_id = p_product_id,
      planned_quantity = p_planned_quantity,
      unit = v_unit,
      updated_at = now()
  where id = p_id;

  return p_id;
end;
$$;

create or replace function public.set_production_plan_item_active(
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
  v_item production_plan_items;
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
  select * into v_item
  from public.production_plan_items
  where id = p_id;

  if not found then
    raise exception 'production_plan_item_not_found';
  end if;

  -- Enabling would break the one-active-per-key rule if another active row
  -- already occupies the same (weekday, shift, product, unit).
  if p_active and exists (
    select 1
    from public.production_plan_items
    where weekday = v_item.weekday
      and shift_code = v_item.shift_code
      and product_id = v_item.product_id
      and unit = v_item.unit
      and active
      and id <> p_id
  ) then
    raise exception 'already_planned';
  end if;

  -- 4. Deactivation is soft (active = false); no physical delete.
  update public.production_plan_items
  set active = p_active,
      updated_at = now()
  where id = p_id;

  return p_id;
end;
$$;

revoke execute on function public.create_production_plan_item(smallint, text, uuid, numeric, text)
  from public, anon, service_role, authenticated;
grant execute on function public.create_production_plan_item(smallint, text, uuid, numeric, text)
  to authenticated;

revoke execute on function public.update_production_plan_item(uuid, smallint, text, uuid, numeric, text)
  from public, anon, service_role, authenticated;
grant execute on function public.update_production_plan_item(uuid, smallint, text, uuid, numeric, text)
  to authenticated;

revoke execute on function public.set_production_plan_item_active(uuid, boolean)
  from public, anon, service_role, authenticated;
grant execute on function public.set_production_plan_item_active(uuid, boolean)
  to authenticated;

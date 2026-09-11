-- AK3: controlled creation of one product item on an existing external order.
--
-- 1. Require an authenticated user with an active profile.
-- 2. Require the supervisor/admin role (order-item management, per the role
--    model): insufficient_role otherwise.
-- 3. Validate the order exists, the product exists and is active, the
--    quantity is positive, the unit is non-empty and the shift is one of the
--    three internal shift codes. The shift arrives as the final value chosen
--    by the caller (preselected from products.default_shift_code in the UI);
--    it is stored as-is and is never recalculated from product defaults
--    later.
-- 4. Insert the item (notes blank -> null) and return its id.
-- 5. Revoke execution from public/anon/service_role; grant only authenticated.
--
-- Error tokens (English, developer-facing):
--   not_authenticated, no_active_profile, insufficient_role,
--   order_not_found, product_not_available, invalid_quantity, invalid_unit,
--   invalid_shift.

create or replace function public.add_external_order_item(
  p_external_order_id uuid,
  p_product_id uuid,
  p_quantity numeric,
  p_unit text,
  p_shift_code text,
  p_notes text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_role text;
  v_unit text;
  v_notes text;
  v_new_item_id uuid;
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

  -- 2. Role gate: only supervisor/admin manage order items.
  if v_role not in ('supervisor', 'admin') then
    raise exception 'insufficient_role';
  end if;

  -- 3. Validation.
  if not exists (select 1 from public.external_orders where id = p_external_order_id) then
    raise exception 'order_not_found';
  end if;

  if not exists (select 1 from public.products where id = p_product_id and active) then
    raise exception 'product_not_available';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'invalid_quantity';
  end if;

  v_unit := trim(coalesce(p_unit, ''));
  if v_unit = '' then
    raise exception 'invalid_unit';
  end if;

  if p_shift_code is null or p_shift_code not in ('morning', 'afternoon', 'night') then
    raise exception 'invalid_shift';
  end if;

  v_notes := trim(coalesce(p_notes, ''));

  -- 4. Insert (the final shift is stored verbatim, never recalculated later).
  insert into public.external_order_items (
    external_order_id, product_id, quantity, unit, shift_code, notes
  )
  values (
    p_external_order_id,
    p_product_id,
    p_quantity,
    v_unit,
    p_shift_code,
    nullif(v_notes, '')
  )
  returning id into v_new_item_id;

  return v_new_item_id;
end;
$$;

revoke execute on function public.add_external_order_item(uuid, uuid, numeric, text, text, text)
  from public, anon, service_role, authenticated;

grant execute on function public.add_external_order_item(uuid, uuid, numeric, text, text, text)
  to authenticated;

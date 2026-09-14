-- Phase V5.3: "add material lot" controlled write, reachable from /production.
--
-- Why an RPC: app roles (anon/authenticated) have SELECT-only RLS policies on
-- material_lots; creating a lot must therefore be a narrow server/database
-- operation, not an unrestricted client table write.
--
-- Behavior (single transaction, all-or-nothing):
--   1. require auth.uid() non-null with an active profile (any of the three
--      app roles; the UI entry point lives on the operator-facing /production
--      page, but authorization stays generic like change_current_material_lot);
--   2. validate the raw material exists and is active;
--   3. validate the brand exists and is active, and is permitted for that raw
--      material via raw_material_brands (active link);
--   4. require a non-empty supplier_lot (btrim);
--   5. idempotency: if a lot with the same (raw_material_id, brand_id,
--      supplier_lot) is still open (status available or in_use), return its
--      id instead of creating a duplicate (the operator re-confirmed a lot
--      that is already open);
--   6. create the new lot with is_current=true, status='in_use',
--      opened_at = p_opened_at (the operator's "fecha de incorporacion") or the
--      business date (get_business_date()) when left empty, created_by=caller.
--      received_at is not an input, so it stays null (not invented).
--   7. return the lot id.
--
-- V5 multi-lot semantics: this RPC does NOT close the prior current lot of the
-- material. Several open lots of the same raw material are allowed to
-- coexist, and a production batch started while several are open snapshots
-- every open lot of that material into batch_materials (the partial unique
-- index material_lots_one_current_per_raw_material, which forbade a second
-- current lot per material, is dropped in phase V5.5 of the same changeset).
-- change_current_material_lot keeps its "switch" behavior: it still closes
-- every open lot of the material before creating the new one.
--
-- Security (SECURITY.md RPC checklist):
--   - SECURITY DEFINER owned by postgres is deliberate: the body inserts a
--     material lot, which no app role may do directly. RLS is intentionally
--     bypassed by the owner role inside the function; every authorization
--     check lives in the function body above.
--   - explicit safe search_path; every object fully qualified.
--   - EXECUTE revoked from PUBLIC, anon and service_role; granted to
--     authenticated only, the role the app's users run as through PostgREST.

create or replace function public.add_material_lot(
  p_raw_material_id uuid,
  p_brand_id uuid,
  p_supplier_lot text,
  p_opened_at date default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_supplier_lot text;
  v_lot_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if not exists (select 1 from public.profiles where id = v_user_id and active) then
    raise exception 'no_active_profile';
  end if;

  if not exists (select 1 from public.raw_materials where id = p_raw_material_id and active) then
    raise exception 'raw_material_not_found';
  end if;

  if not exists (select 1 from public.brands where id = p_brand_id and active) then
    raise exception 'brand_not_found';
  end if;

  if not exists (
    select 1
    from public.raw_material_brands
    where raw_material_id = p_raw_material_id
      and brand_id = p_brand_id
      and active
  ) then
    raise exception 'brand_not_permitted_for_material';
  end if;

  v_supplier_lot := btrim(coalesce(p_supplier_lot, ''));
  if v_supplier_lot = '' then
    raise exception 'supplier_lot_required';
  end if;

  -- Idempotency: the same open lot was already added.
  select id into v_lot_id
  from public.material_lots
  where raw_material_id = p_raw_material_id
    and brand_id = p_brand_id
    and supplier_lot = v_supplier_lot
    and status in ('available', 'in_use');
  if v_lot_id is not null then
    return v_lot_id;
  end if;

  insert into public.material_lots (
    raw_material_id, brand_id, supplier_lot,
    opened_at, is_current, status, created_by
  ) values (
    p_raw_material_id, p_brand_id, v_supplier_lot,
    coalesce(p_opened_at, public.get_business_date())::timestamptz,
    true, 'in_use', v_user_id
  )
  returning id into v_lot_id;

  return v_lot_id;
end;
$$;

comment on function public.add_material_lot(uuid, uuid, text, date) is
  'Adds a new open material lot (in_use, is_current) without closing the material''s other open lots: several open lots per raw material may coexist and a batch snapshots all of them. Idempotent per (material, brand, supplier lot) while open. Controlled write for authenticated users with an active profile.';

revoke execute on function public.add_material_lot(uuid, uuid, text, date) from public;
revoke execute on function public.add_material_lot(uuid, uuid, text, date) from anon, authenticated, service_role;
grant execute on function public.add_material_lot(uuid, uuid, text, date) to authenticated;

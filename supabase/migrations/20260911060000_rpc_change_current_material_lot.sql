-- Phase W2: atomic "change current material lot" controlled write.
--
-- Why an RPC: app roles (anon/authenticated) have SELECT-only RLS policies on
-- material_lots (U1/U2); the close-old + insert-new transition must therefore
-- be a narrow server/database operation, not unrestricted client table writes.
--
-- Behavior (single transaction, all-or-nothing):
--   1. require auth.uid() non-null with an active profile (any of the three
--      app roles; the role column is DB-constrained to operator/supervisor/admin);
--   2. validate the raw material exists and is active;
--   3. validate the brand exists and is active, and is permitted for that raw
--      material via raw_material_brands (active link);
--   4. require a non-empty supplier_lot;
--   5. close the prior current lot if any (is_current=false, status='closed',
--      closed_at=now()); history rows are preserved, never deleted;
--   6. create the new lot with status='in_use', is_current=true,
--      opened_at=now(), created_by=caller. received_at is not an input, so it
--      stays null (not invented);
--   7. return the new lot id.
-- The partial unique index material_lots_one_current_per_raw_material enforces
-- the "one current lot per material" invariant even under concurrent calls.
--
-- Security (SECURITY.md RPC checklist):
--   - SECURITY DEFINER owned by postgres is deliberate: the body performs the
--     close/insert that no app role may do directly. RLS is intentionally
--     bypassed by the owner role inside the function; every authorization
--     check lives in the function body above.
--   - explicit safe search_path; every object fully qualified.
--   - EXECUTE revoked from PUBLIC, anon and service_role (Supabase default
--     privileges would grant it, see U4); granted to authenticated only, the
--     role the app's users run as through PostgREST.

create or replace function public.change_current_material_lot(
  p_raw_material_id uuid,
  p_brand_id uuid,
  p_supplier_lot text,
  p_expiry_date date default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_new_lot_id uuid;
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

  if p_supplier_lot is null or btrim(p_supplier_lot) = '' then
    raise exception 'supplier_lot_required';
  end if;

  -- Close the prior current lot for this material, if any.
  update public.material_lots
     set is_current = false,
         status = case
                    when status in ('available', 'in_use') then 'closed'
                    else status
                  end,
         closed_at = now()
   where raw_material_id = p_raw_material_id
     and is_current = true;

  insert into public.material_lots (
    raw_material_id, brand_id, supplier_lot, expiry_date,
    opened_at, is_current, status, created_by
  ) values (
    p_raw_material_id, p_brand_id, btrim(p_supplier_lot), p_expiry_date,
    now(), true, 'in_use', v_user_id
  )
  returning id into v_new_lot_id;

  return v_new_lot_id;
end;
$$;

comment on function public.change_current_material_lot(uuid, uuid, text, date) is
  'Atomically switches the current lot of a raw material: closes the prior current lot (if any) and creates the new one (in_use, is_current). Controlled write for authenticated users with an active profile.';

revoke execute on function public.change_current_material_lot(uuid, uuid, text, date) from public;
revoke execute on function public.change_current_material_lot(uuid, uuid, text, date) from anon, authenticated, service_role;
grant execute on function public.change_current_material_lot(uuid, uuid, text, date) to authenticated;

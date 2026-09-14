-- Phase V5.5: "usar otro lote" — link a second (or further) lot of a raw
-- material that an in-progress batch is already using.
--
-- Business case (the changeset's final rule): the batch was started with
-- Harina 000 H001; mid-dough the baker opens a second bag, H002. The new lot
-- must be recorded without losing the first: the batch's batch_materials keeps
-- the H001 row untouched and gains one row per additional lot. The UI then
-- lists every lot the batch used: "Harina 000 / - H001 / - H002".
--
-- Behavior (single transaction, all-or-nothing):
--   1. require auth.uid() non-null with an active profile (any app role, like
--      the other production RPCs; the UI entry point is the operator-facing
--      batch detail page, and the page only offers it for in-progress
--      batches);
--   2. the batch exists and is still in progress (a finished or cancelled
--      batch's lot list is history and can never be extended);
--   3. the raw material exists and is active, and is already used by this
--      batch (at least one batch_materials row for batch + material);
--   4. create or activate the lot through the established add_material_lot
--      RPC (brand checks, supplier_lot btrim, idempotency per (material,
--      brand, supplier lot) while open);
--   5. make the new lot the current one for future production: the material's
--      other current lots are retired with the established close pattern
--      (same as change_current_material_lot) and the target lot is marked
--      is_current = true / in_use, so the next batch defaults to it;
--   6. append one batch_materials row (batch, material, lot) when it does not
--      already exist; existing rows are NEVER updated or replaced, and
--      recipe_quantity/recipe_unit stay null for the additional row (this
--      version does not ask for a quantity per lot);
--   7. return the lot id.
--
-- Security (SECURITY.md RPC checklist):
--   - SECURITY DEFINER owned by postgres is deliberate: the body writes
--     material_lots and batch_materials, which no app role may do directly.
--     RLS is intentionally bypassed by the owner role inside the function;
--     every authorization check lives in the function body above.
--   - explicit safe search_path; every object fully qualified.
--   - EXECUTE revoked from PUBLIC, anon and service_role; granted to
--     authenticated only, the role the app's users run as through PostgREST.

create or replace function public.use_other_material_lot(
  p_batch_id uuid,
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
  v_batch_status text;
  v_lot_id uuid;
begin
  -- 1. Auth (established model).
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if not exists (select 1 from public.profiles where id = v_user_id and active) then
    raise exception 'no_active_profile';
  end if;

  -- 2. The batch exists and is still in progress.
  select status into v_batch_status
  from public.production_batches
  where id = p_batch_id;
  if v_batch_status is null then
    raise exception 'batch_not_found';
  end if;
  if v_batch_status <> 'in_progress' then
    raise exception 'batch_not_in_progress';
  end if;

  -- 3. The material exists, is active, and is already used by this batch.
  if not exists (select 1 from public.raw_materials where id = p_raw_material_id and active) then
    raise exception 'raw_material_not_found';
  end if;

  if not exists (
    select 1
    from public.batch_materials
    where batch_id = p_batch_id
      and raw_material_id = p_raw_material_id
  ) then
    raise exception 'material_not_in_batch';
  end if;

  -- 4. Create or reuse the lot (established validations and idempotency).
  v_lot_id := public.add_material_lot(
    p_raw_material_id, p_brand_id, p_supplier_lot, p_opened_at
  );

  -- 5. Make the new lot the current one for future production: retire the
  --    material's other current lots (established close pattern, same as
  --    change_current_material_lot) so the next batch defaults to it.
  update public.material_lots
     set is_current = false,
         status = case when status in ('available', 'in_use') then 'closed' else status end,
         closed_at = now()
   where raw_material_id = p_raw_material_id
     and is_current
     and id <> v_lot_id;

  update public.material_lots
     set is_current = true,
         status = case when status in ('available', 'in_use') then 'in_use' else status end
   where id = v_lot_id;

  -- 6. Append the batch link when absent; never rewrite an existing row.
  insert into public.batch_materials (batch_id, raw_material_id, material_lot_id)
  select p_batch_id, p_raw_material_id, v_lot_id
  where not exists (
    select 1
    from public.batch_materials
    where batch_id = p_batch_id
      and raw_material_id = p_raw_material_id
      and material_lot_id = v_lot_id
  );

  -- 7. Result.
  return v_lot_id;
end;
$$;

comment on function public.use_other_material_lot(uuid, uuid, uuid, text, date) is
  'Links a second lot of an already-used raw material to an in-progress batch (appends a batch_materials row, never rewrites the existing ones), makes the new lot the current one for future production, and returns the lot id. Controlled write for authenticated users with an active profile.';

revoke execute on function public.use_other_material_lot(uuid, uuid, uuid, text, date) from public;
revoke execute on function public.use_other_material_lot(uuid, uuid, uuid, text, date) from anon, authenticated, service_role;
grant execute on function public.use_other_material_lot(uuid, uuid, uuid, text, date) to authenticated;

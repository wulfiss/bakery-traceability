-- Phase AF1: start a production batch for ONE pending production request.
--
-- Critical traceability transaction. Steps (all-or-nothing, single implicit
-- transaction; any raised exception rolls everything back):
--   1. validate authenticated user + active profile (established RPC model);
--   2. request exists and status = pending (row locked FOR UPDATE);
--   3. resolve the active recipe_version for the request's product
--      (AC1 logic; at most one active version per recipe is DB-enforced);
--   4. validate that every required recipe ingredient has a current material
--      lot (AE1 logic); if any is missing, fail with 'missing_material_lot'
--      plus the raw-material names after a colon (e.g.
--      "missing_material_lot: Levadura, Sal") so the UI can list them;
--   5. generate the safe batch code PAN-DDMMYY-X-NNN via next_batch_code
--      (stored production_day.production_date + request shift; the function's
--      transaction-scoped advisory lock is held by THIS transaction until
--      commit, so the code generation and the batch insert below are
--      serialized per day+shift);
--   6. create the batch with the request's shift_code copied (historical);
--   7. snapshot the EXACT current material lots into batch_materials
--      (append-mostly; historical traceability never reads is_current again);
--   8. create the batch_requests link (allocated_quantity = requested quantity);
--   9. set the request status to in_progress;
--  10. return (batch_id, batch_code).
--
-- Concurrency:
--   - Same request, two callers: the FOR UPDATE lock on the request row makes
--     the second caller wait; after the first commits it re-reads
--     status = in_progress and fails with 'request_not_pending'. No duplicate
--     batches for one request.
--   - Different requests, same day+shift: serialized by the next_batch_code
--     advisory lock; each gets a distinct code (AD1).
--
-- Security (established RPC security model, see SECURITY.md):
--   SECURITY DEFINER (performs batch/batch_materials/batch_requests/
--   production_requests writes no app role may do directly), requires
--   auth.uid(), validates the active profile, explicit safe search_path,
--   EXECUTE revoked from PUBLIC/anon/service_role, granted to authenticated
--   only. No profile-role restriction: starting production is an operator
--   task in the MVP (same model as the other production RPCs); the role column
--   remains DB-constrained and is enforced where the business requires it.

create type public.start_production_batch_result as (batch_id uuid, batch_code text);

create or replace function public.start_production_batch(p_production_request_id uuid)
returns public.start_production_batch_result
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_request_status text;
  v_product_id uuid;
  v_day_id uuid;
  v_shift_code text;
  v_requested_quantity numeric;
  v_recipe_count int;
  v_version_id uuid;
  v_missing_materials text;
  v_batch_id uuid;
  v_batch_code text;
begin
  -- 1. Auth (established model).
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if not exists (select 1 from public.profiles where id = v_user_id and active) then
    raise exception 'no_active_profile';
  end if;

  -- 2. Request exists and is pending. FOR UPDATE serializes concurrent starts
  --    of the same request (see header).
  select r.status, r.product_id, r.production_day_id, r.shift_code, r.requested_quantity
    into v_request_status, v_product_id, v_day_id, v_shift_code, v_requested_quantity
  from public.production_requests r
  where r.id = p_production_request_id
  for update;

  if v_request_status is null then
    raise exception 'production_request_not_found';
  end if;

  if v_request_status <> 'pending' then
    raise exception 'request_not_pending';
  end if;

  -- 3. Resolve the active recipe_version for the product (AC1 logic).
  select count(distinct rp.recipe_id)
    into v_recipe_count
  from public.recipe_products rp
  join public.recipe_versions rv on rv.recipe_id = rp.recipe_id and rv.status = 'active'
  where rp.product_id = v_product_id;

  if v_recipe_count = 0 then
    if not exists (select 1 from public.recipe_products rp where rp.product_id = v_product_id) then
      raise exception 'no_recipe';
    end if;
    raise exception 'no_active_version';
  end if;

  if v_recipe_count > 1 then
    raise exception 'ambiguous_recipes';
  end if;

  select rv.id
    into v_version_id
  from public.recipe_products rp
  join public.recipe_versions rv on rv.recipe_id = rp.recipe_id and rv.status = 'active'
  where rp.product_id = v_product_id;

  -- 4. Validate required current material lots (AE1 logic). Missing optional
  --    ingredients are allowed (they simply are not snapshotted).
  select coalesce(string_agg(rm.name, ', ' order by ri.sort_order), '')
    into v_missing_materials
  from public.recipe_ingredients ri
  join public.raw_materials rm on rm.id = ri.raw_material_id
  where ri.recipe_version_id = v_version_id
    and not ri.optional
    and not exists (
      select 1
      from public.material_lots ml
      where ml.raw_material_id = ri.raw_material_id
        and ml.is_current
    );

  if v_missing_materials <> '' then
    raise exception 'missing_material_lot: %', v_missing_materials;
  end if;

  -- 5. Safe batch code (AD1); the advisory xact lock is held until this
  --    transaction commits, covering the insert below.
  v_batch_code := public.next_batch_code(v_day_id, v_shift_code);

  -- 6. Create the batch; the request's shift is copied (historical).
  insert into public.production_batches
    (production_day_id, recipe_version_id, shift_code, batch_code, status, started_at, started_by)
  values (v_day_id, v_version_id, v_shift_code, v_batch_code, 'in_progress', now(), v_user_id)
  returning id into v_batch_id;

  -- 7. Snapshot the EXACT current lots (required + present optional).
  insert into public.batch_materials (batch_id, raw_material_id, material_lot_id, recipe_quantity, recipe_unit)
  select v_batch_id, ri.raw_material_id, ml.id, ri.quantity, ri.unit
  from public.recipe_ingredients ri
  join public.material_lots ml on ml.raw_material_id = ri.raw_material_id and ml.is_current
  where ri.recipe_version_id = v_version_id;

  -- 8. Link the batch to the request.
  insert into public.batch_requests (batch_id, production_request_id, allocated_quantity)
  values (v_batch_id, p_production_request_id, v_requested_quantity);

  -- 9. Advance the request.
  update public.production_requests
  set status = 'in_progress'
  where id = p_production_request_id;

  -- 10. Result.
  return (v_batch_id, v_batch_code);
end;
$$;

comment on function public.start_production_batch(uuid) is
  'Starts a production batch for one pending request: validates auth/profile, resolves the active recipe_version, validates required current material lots (fails with missing_material_lot: <names>), generates the safe PAN-DDMMYY-X-NNN code in-transaction, snapshots exact lots into batch_materials, links the request and sets it in_progress; atomic, all-or-nothing.';

revoke execute on function public.start_production_batch(uuid) from public;
revoke execute on function public.start_production_batch(uuid) from anon, authenticated, service_role;
grant execute on function public.start_production_batch(uuid) to authenticated;

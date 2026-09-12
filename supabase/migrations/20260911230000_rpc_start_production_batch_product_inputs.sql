-- Phase AP1: extend start_production_batch with produced-product inputs
-- (guide phase AP: "Produced product used as input").
--
-- A recipe version may declare previously produced products as required
-- inputs (recipe_product_inputs, phase J). When the recipe of a request's
-- product requires such inputs, the operator MUST select the actual physical
-- source lot for each of them before the batch can start:
--
--   Pan Felipe
--   PAN-090926-N-014
--        downarrow
--   Tostadas (this batch)
--
-- This migration REPLACES start_production_batch with a new signature:
--
--   start_production_batch(p_production_request_id uuid,
--                          p_product_inputs jsonb default null)
--
-- p_product_inputs is a JSON array of
--   {source_product_id, parent_batch_output_id}
-- objects, exactly one per REQUIRED recipe_product_inputs row of the
-- resolved recipe_version. Existing callers (single-argument) are unchanged:
-- the default null means "no produced-product selections" and the RPC
-- behaves exactly as before when the recipe requires no product inputs.
--
-- New steps (all-or-nothing, same single implicit transaction):
--   4b. validate the produced-product selections:
--        - required inputs exist  -> p_product_inputs must be a non-empty
--          JSON array (otherwise 'missing_product_input');
--        - the same source_product_id twice -> 'duplicate_product_input';
--        - fewer selections than required inputs -> 'missing_product_input';
--        - malformed element (missing / invalid uuid) ->
--          'invalid_product_input';
--        - source_product_id not a required input of the recipe ->
--          'input_not_in_recipe';
--        - parent_batch_output_id must exist, belong to a COMPLETED batch,
--          and be an output of exactly that source product (otherwise
--          'invalid_product_input');
--        - no required inputs but a non-empty selection array ->
--          'input_not_in_recipe'.
--   7b. after the batch insert, store the EXACT parent output relations in
--       parent_batch_inputs (child_batch_id = the new batch,
--       parent_batch_output_id = the operator-selected output, quantity and
--       unit copied from the parent output - the same exact-snapshot
--       principle as the material-lot snapshot). The RPC never selects a
--       previous batch on its own: the physical source lot is always an
--       explicit operator choice.
--
-- Full error token list: not_authenticated, no_active_profile,
-- production_request_not_found, request_not_pending, no_recipe,
-- no_active_version, ambiguous_recipes, missing_material_lot: <names>,
-- missing_product_input, duplicate_product_input, input_not_in_recipe,
-- invalid_product_input.
--
-- Security (established RPC security model, see SECURITY.md):
--   SECURITY DEFINER (performs the parent_batch_inputs write no app role may
--   do directly, in addition to the existing writes), requires auth.uid(),
--   validates the active profile, explicit safe search_path, EXECUTE revoked
--   from PUBLIC/anon/service_role, granted to authenticated only. No
--   profile-role restriction: starting production is an operator task in the
--   MVP (same model as before); the role column remains DB-constrained and
--   is enforced where the business requires it.

drop function if exists public.start_production_batch(uuid);

create function public.start_production_batch(
  p_production_request_id uuid,
  p_product_inputs jsonb default null
)
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
  v_required_input_count int;
  v_input_total int;
  v_input_distinct int;
  v_source_raw text;
  v_parent_raw text;
  v_source_id uuid;
  v_parent_id uuid;
  v_output_product uuid;
  v_output_status text;
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

  -- 4b. Produced-product inputs (AP1, guide phase AP). The operator selects
  --     the physical source lot for every required input; the RPC only
  --     validates and records the choice - it never picks one itself.
  select count(*)
    into v_required_input_count
  from public.recipe_product_inputs
  where recipe_version_id = v_version_id
    and required;

  if v_required_input_count > 0 then
    if p_product_inputs is null or jsonb_typeof(p_product_inputs) <> 'array'
      or jsonb_array_length(p_product_inputs) = 0 then
      raise exception 'missing_product_input';
    end if;

    select count(*), count(distinct value->>'source_product_id')
      into v_input_total, v_input_distinct
    from jsonb_array_elements(p_product_inputs) e(value);

    if v_input_total <> v_input_distinct then
      raise exception 'duplicate_product_input';
    end if;

    if v_input_total < v_required_input_count then
      raise exception 'missing_product_input';
    end if;

    for v_source_raw, v_parent_raw in
      select e.value->>'source_product_id', e.value->>'parent_batch_output_id'
      from jsonb_array_elements(p_product_inputs) e(value)
    loop
      if v_source_raw is null or v_parent_raw is null then
        raise exception 'invalid_product_input';
      end if;

      begin
        v_source_id := v_source_raw::uuid;
      exception
        when others then
          raise exception 'invalid_product_input';
      end;

      begin
        v_parent_id := v_parent_raw::uuid;
      exception
        when others then
          raise exception 'invalid_product_input';
      end;

      -- The selected product must be one of the recipe's required inputs;
      -- extra selections (total > count) fail here.
      if not exists (
        select 1
        from public.recipe_product_inputs rpi
        where rpi.recipe_version_id = v_version_id
          and rpi.required
          and rpi.source_product_id = v_source_id
      ) then
        raise exception 'input_not_in_recipe';
      end if;

      -- The parent output must exist, belong to a COMPLETED batch (only
      -- finished productions can be physical inputs), and be an output of
      -- exactly the declared source product.
      select bo.product_id, b.status
        into v_output_product, v_output_status
      from public.batch_outputs bo
      join public.production_batches b on b.id = bo.batch_id
      where bo.id = v_parent_id;

      if v_output_product is null
        or v_output_product <> v_source_id
        or v_output_status <> 'completed' then
        raise exception 'invalid_product_input';
      end if;
    end loop;
  elsif p_product_inputs is not null
    and jsonb_typeof(p_product_inputs) = 'array'
    and jsonb_array_length(p_product_inputs) > 0 then
    -- Selections were sent although the recipe requires no product inputs.
    raise exception 'input_not_in_recipe';
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

  -- 7b. Store the EXACT parent output relations (AP1). Quantity and unit are
  --     copied from the parent output (exact physical source, same
  --     snapshot principle as step 7); every element was validated in 4b.
  if v_required_input_count > 0 then
    insert into public.parent_batch_inputs (child_batch_id, parent_batch_output_id, quantity, unit)
    select v_batch_id, bo.id, bo.quantity, bo.unit
    from jsonb_array_elements(p_product_inputs) e(value)
    cross join public.batch_outputs bo
    where bo.id = (e.value->>'parent_batch_output_id')::uuid;
  end if;

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

comment on function public.start_production_batch(uuid, jsonb) is
  'Starts a production batch for one pending request: validates auth/profile, resolves the active recipe_version, validates required current material lots (fails with missing_material_lot: <names>), validates produced-product input selections (one operator-chosen completed parent batch_output per required recipe_product_inputs; missing_product_input / duplicate_product_input / input_not_in_recipe / invalid_product_input), generates the safe PAN-DDMMYY-X-NNN code in-transaction, snapshots exact material lots into batch_materials and exact parent outputs into parent_batch_inputs, links the request and sets it in_progress; atomic, all-or-nothing.';

revoke execute on function public.start_production_batch(uuid, jsonb) from public;
revoke execute on function public.start_production_batch(uuid, jsonb) from anon, authenticated, service_role;
grant execute on function public.start_production_batch(uuid, jsonb) to authenticated;

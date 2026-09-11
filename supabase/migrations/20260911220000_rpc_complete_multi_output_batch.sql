-- Phase AO1: complete an in-progress batch that produced MULTIPLE products
-- (multi-output finalization series, guide phase AO).
--
-- The single-output complete_production_batch is left untouched: single-product
-- batches keep using it. This RPC is the all-or-nothing finalization for a
-- preparation whose active recipe yields several products at once:
--
--   Masa Pan Galleta (one recipe, one batch) -> batch_outputs:
--     Pan Galleta / Pebete / Pan Leche Redondo / ...
--
-- Critical traceability transaction. Steps (all-or-nothing, single implicit
-- transaction; any raised exception rolls everything back):
--   1. validate authenticated user + active profile (established RPC model);
--   2. batch exists and status = in_progress (row locked FOR UPDATE so a
--      concurrent completion fails cleanly instead of double-writing);
--   3. p_outputs must be a non-empty JSON array of
--      {product_id, quantity, unit} objects, without repeated product_id;
--   4. every element must be well-formed (valid existing product uuid,
--      numeric quantity > 0, non-empty unit) and the product must be one of
--      the products of the batch's recipe (recipe_products of the batch's
--      recipe_version) - the RPC never records a product the recipe cannot
--      yield;
--   5. create one batch_outputs row per element;
--   6. set the batch to completed with finished_at = now() and
--      finished_by = the acting user;
--   7. set every linked production request to completed and save
--      batch_requests.allocated_quantity ONLY where it is still null (start
--      already stores the requested quantity as the allocation).
--
-- batch_materials is NEVER modified here: the material-lot snapshot taken at
-- batch start happens exactly once and is append-mostly / immutable historical
-- traceability (already guaranteed by start_production_batch).
--
-- Error tokens: not_authenticated, no_active_profile, batch_not_found,
-- batch_not_in_progress, invalid_outputs (null / not an array / empty),
-- duplicate_output (same product twice in p_outputs), invalid_output
-- (malformed element or unknown product), output_not_in_recipe.
--
-- Security (established RPC security model, see SECURITY.md):
--   SECURITY DEFINER (performsthe batch_outputs / production_batches /
--   production_requests / batch_requests writes no app role may do directly),
--   requires auth.uid(), validates the active profile, explicit safe
--   search_path, EXECUTE revoked from PUBLIC/anon/service_role, granted to
--   authenticated only. No profile-role restriction: finishing production is
--   an operator task in the MVP (same model as complete_production_batch);
--   the role column remains DB-constrained and is enforced where the business
--   requires it.

create or replace function public.complete_multi_output_batch(
  p_batch_id uuid,
  p_outputs jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_batch_status text;
  v_recipe_id uuid;
  v_total int;
  v_distinct_products int;
  v_elem jsonb;
  v_product_raw text;
  v_quantity_raw text;
  v_unit text;
  v_product_id uuid;
  v_quantity numeric;
begin
  -- 1. Auth (established model).
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if not exists (select 1 from public.profiles where id = v_user_id and active) then
    raise exception 'no_active_profile';
  end if;

  -- 2. Batch exists. FOR UPDATE serializes concurrent completions of the same
  --    batch (the second caller re-reads status = completed and fails). The
  --    recipe_version row is locked as well, so the recipe cannot be swapped
  --    mid-transaction.
  select b.status, rv.recipe_id
    into v_batch_status, v_recipe_id
  from public.production_batches b
  join public.recipe_versions rv on rv.id = b.recipe_version_id
  where b.id = p_batch_id
  for update;

  if v_batch_status is null then
    raise exception 'batch_not_found';
  end if;

  if v_batch_status <> 'in_progress' then
    raise exception 'batch_not_in_progress';
  end if;

  -- 3. p_outputs must be a non-empty JSON array.
  if p_outputs is null
    or jsonb_typeof(p_outputs) <> 'array'
    or jsonb_array_length(p_outputs) = 0 then
    raise exception 'invalid_outputs';
  end if;

  -- 4. A product may appear at most once in the output list.
  select count(*), count(distinct (value->>'product_id'))
    into v_total, v_distinct_products
  from jsonb_array_elements(p_outputs) e(value);

  if v_total <> v_distinct_products then
    raise exception 'duplicate_output';
  end if;

  -- 5. Validate every element and record one output row per element.
  for v_elem in
    select e.value from jsonb_array_elements(p_outputs) e(value)
  loop
    v_product_raw := v_elem->>'product_id';
    v_quantity_raw := v_elem->>'quantity';
    v_unit := coalesce(v_elem->>'unit', '');

    if v_product_raw is null then
      raise exception 'invalid_output';
    end if;

    begin
      v_product_id := v_product_raw::uuid;
    exception
      when others then
        raise exception 'invalid_output';
    end;

    if not exists (select 1 from public.products where id = v_product_id) then
      raise exception 'invalid_output';
    end if;

    begin
      v_quantity := v_quantity_raw::numeric;
    exception
      when others then
        raise exception 'invalid_output';
    end;

    if v_quantity <= 0 or btrim(v_unit) = '' then
      raise exception 'invalid_output';
    end if;

    -- The output must be one of the products of the batch's recipe; never
    -- record a product the recipe cannot yield.
    if not exists (
      select 1
      from public.recipe_products rp
      where rp.recipe_id = v_recipe_id
        and rp.product_id = v_product_id
    ) then
      raise exception 'output_not_in_recipe';
    end if;

    insert into public.batch_outputs (batch_id, product_id, quantity, unit)
    values (p_batch_id, v_product_id, v_quantity, btrim(v_unit));
  end loop;

  -- 6. Complete the batch.
  update public.production_batches
  set status = 'completed',
      finished_at = now(),
      finished_by = v_user_id
  where id = p_batch_id;

  -- 7. Complete every linked request (a batch created by
  --    start_production_batch has exactly one) and backfill the allocation
  --    only where it was not saved at batch start.
  update public.production_requests r
  set status = 'completed'
  from public.batch_requests br
  where br.batch_id = p_batch_id
    and br.production_request_id = r.id;

  update public.batch_requests br
  set allocated_quantity = r.requested_quantity
  from public.production_requests r
  where br.production_request_id = r.id
    and br.batch_id = p_batch_id
    and br.allocated_quantity is null;
end;
$$;

comment on function public.complete_multi_output_batch(uuid, jsonb) is
  'Completes an in-progress multi-output batch: validates auth/profile, locks the batch and its recipe_version, validates that p_outputs is a non-empty JSON array of {product_id, quantity, unit} without duplicates and that every product belongs to the batch recipe (output_not_in_recipe), inserts one batch_outputs row per element, completes the batch, completes every linked production request, and backfills batch_requests.allocated_quantity only when null; never modifies batch_materials; atomic, all-or-nothing.';

revoke execute on function public.complete_multi_output_batch(uuid, jsonb) from public;
revoke execute on function public.complete_multi_output_batch(uuid, jsonb) from anon, authenticated, service_role;
grant execute on function public.complete_multi_output_batch(uuid, jsonb) to authenticated;

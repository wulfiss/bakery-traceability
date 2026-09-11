-- Phase AI1: complete an in-progress production batch for a simple
-- single-product batch (multi-output finalization is a separate later series).
--
-- Critical traceability transaction. Steps (all-or-nothing, single implicit
-- transaction; any raised exception rolls everything back):
--   1. validate authenticated user + active profile (established RPC model);
--   2. batch exists and status = in_progress (row locked FOR UPDATE so a
--      concurrent completion fails cleanly instead of double-writing);
--   3. validate the actually produced quantity (> 0) and a non-empty unit;
--   4. determine the linked production request via batch_requests (a batch
--      created by start_production_batch has exactly one);
--   5. create the batch_outputs row (actual quantity + unit);
--   6. set the batch to completed with finished_at = now() and
--      finished_by = the acting user;
--   7. set the linked production request to completed;
--   8. save batch_requests.allocated_quantity ONLY when it is still null
--      (start_production_batch already stores the requested quantity as the
--      allocation; an existing allocation is never overwritten).
--
-- batch_materials is NEVER modified here: the material-lot snapshot taken at
-- start is append-mostly / immutable historical traceability.
--
-- Security (established RPC security model, see SECURITY.md):
--   SECURITY DEFINER (performs production_batches/production_requests/
--   batch_requests/batch_outputs writes no app role may do directly), requires
--   auth.uid(), validates the active profile, explicit safe search_path,
--   EXECUTE revoked from PUBLIC/anon/service_role, granted to authenticated
--   only. No profile-role restriction: finishing production is an operator
--   task in the MVP (same model as start_production_batch); the role column
--   remains DB-constrained and is enforced where the business requires it.

create or replace function public.complete_production_batch(
  p_batch_id uuid,
  p_actual_quantity numeric,
  p_unit text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_batch_status text;
  v_request_id uuid;
  v_product_id uuid;
  v_requested_quantity numeric;
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
  --    batch (the second caller re-reads status = completed and fails).
  select b.status
    into v_batch_status
  from public.production_batches b
  where b.id = p_batch_id
  for update;

  if v_batch_status is null then
    raise exception 'batch_not_found';
  end if;

  -- 3. Only an in-progress batch can be completed.
  if v_batch_status <> 'in_progress' then
    raise exception 'batch_not_in_progress';
  end if;

  -- 4. Validate the actual production result.
  if p_actual_quantity is null
    or p_actual_quantity <= 0
    or p_unit is null
    or btrim(p_unit) = '' then
    raise exception 'invalid_quantity';
  end if;

  -- 5. Determine the linked request (product + requested quantity).
  select br.production_request_id, r.product_id, r.requested_quantity
    into v_request_id, v_product_id, v_requested_quantity
  from public.batch_requests br
  join public.production_requests r on r.id = br.production_request_id
  where br.batch_id = p_batch_id
  order by br.created_at
  limit 1;

  if v_request_id is null then
    raise exception 'batch_request_not_found';
  end if;

  -- 6. Record the actual output (single product for this step).
  insert into public.batch_outputs (batch_id, product_id, quantity, unit)
  values (p_batch_id, v_product_id, p_actual_quantity, btrim(p_unit));

  -- 7. Complete the batch.
  update public.production_batches
  set status = 'completed',
      finished_at = now(),
      finished_by = v_user_id
  where id = p_batch_id;

  -- 8. Complete the linked request.
  update public.production_requests
  set status = 'completed'
  where id = v_request_id;

  -- 9. Save the allocation only where it was not saved at batch start.
  update public.batch_requests
  set allocated_quantity = v_requested_quantity
  where batch_id = p_batch_id
    and production_request_id = v_request_id
    and allocated_quantity is null;
end;
$$;

comment on function public.complete_production_batch(uuid, numeric, text) is
  'Completes an in-progress single-product batch: validates auth/profile, locks the batch row, validates the actual quantity/unit, records the batch_outputs row, sets the batch completed with finished_at/finished_by, completes the linked production request, and backfills batch_requests.allocated_quantity only when null; never modifies batch_materials; atomic, all-or-nothing.';

revoke execute on function public.complete_production_batch(uuid, numeric, text) from public;
revoke execute on function public.complete_production_batch(uuid, numeric, text) from anon, authenticated, service_role;
grant execute on function public.complete_production_batch(uuid, numeric, text) to authenticated;

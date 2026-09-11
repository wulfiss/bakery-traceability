-- Phase AB1: creation of one additional production request.
--
-- Why an RPC: app roles (anon/authenticated) have SELECT-only RLS policies on
-- production_requests (U2); request creation must be a narrow
-- server/database operation, not a client table write.
--
-- Behavior (single transaction):
--   1. require auth.uid() non-null with an active profile (any of the three
--      app roles; the role column is DB-constrained to operator/supervisor/admin);
--   2. validate the production day (error 'production_day_not_found');
--   3. validate the product exists and is active (error 'product_not_found');
--   4. validate requested_quantity > 0 (error 'invalid_quantity');
--   5. validate unit is non-blank (error 'invalid_unit');
--   6. validate shift_code is one of morning/afternoon/night
--      (error 'invalid_shift'); the value is supplied by the caller and is
--      never inferred from the current time;
--   7. validate reason_code is one of replenishment/increased_demand/remake/other
--      (error 'invalid_reason'); when reason_code='other', a non-blank
--      reason_note is required (error 'reason_note_required'); a blank note for
--      any other reason is stored as NULL;
--   8. insert source_type='additional', status='pending', created_by=caller,
--      external_order_item_id=NULL (enforced by the additional integrity
--      constraint) and return the new request id.

create or replace function public.create_additional_production_request(
  p_production_day_id uuid,
  p_product_id uuid,
  p_requested_quantity numeric,
  p_unit text,
  p_shift_code text,
  p_reason_code text,
  p_reason_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_request_id uuid;
  v_note text;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if not exists (select 1 from public.profiles where id = v_user_id and active) then
    raise exception 'no_active_profile';
  end if;

  if not exists (select 1 from public.production_days where id = p_production_day_id) then
    raise exception 'production_day_not_found';
  end if;

  if not exists (select 1 from public.products where id = p_product_id and active) then
    raise exception 'product_not_found';
  end if;

  if p_requested_quantity is null or p_requested_quantity <= 0 then
    raise exception 'invalid_quantity';
  end if;

  if p_unit is null or btrim(p_unit) = '' then
    raise exception 'invalid_unit';
  end if;

  if p_shift_code is null or p_shift_code not in ('morning', 'afternoon', 'night') then
    raise exception 'invalid_shift';
  end if;

  if p_reason_code is null or p_reason_code not in ('replenishment', 'increased_demand', 'remake', 'other') then
    raise exception 'invalid_reason';
  end if;

  if p_reason_code = 'other' and (p_reason_note is null or btrim(p_reason_note) = '') then
    raise exception 'reason_note_required';
  end if;

  v_note := nullif(btrim(coalesce(p_reason_note, '')), '');

  insert into public.production_requests (
    production_day_id, source_type, shift_code, product_id,
    requested_quantity, unit, reason_code, reason_note, status, created_by
  ) values (
    p_production_day_id, 'additional', p_shift_code, p_product_id,
    p_requested_quantity, btrim(p_unit), p_reason_code, v_note, 'pending', v_user_id
  )
  returning id into v_request_id;

  return v_request_id;
end;
$$;

comment on function public.create_additional_production_request(uuid, uuid, numeric, text, text, text, text) is
  'Creates one additional production request (source_type=additional, status=pending) with a required reason_code (a non-empty reason_note when other); returns the new request id.';

revoke execute on function public.create_additional_production_request(uuid, uuid, numeric, text, text, text, text) from public;
revoke execute on function public.create_additional_production_request(uuid, uuid, numeric, text, text, text, text) from anon, authenticated, service_role;
grant execute on function public.create_additional_production_request(uuid, uuid, numeric, text, text, text, text) to authenticated;

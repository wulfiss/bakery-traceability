-- ============================================================================
-- Phase V5.7: additional production without a reason
--
-- Additional production requests no longer carry a reason: the UI removes
-- the Motivo/Detalle fields, and new rows save reason_code = NULL and
-- reason_note = NULL. The columns stay in the table (nullable, NOT dropped)
-- for backward compatibility, and historical additional requests keep their
-- existing reasons.
--
-- 1. production_requests_additional_integrity is dropped and re-added
--    without the reason requirement: an additional row must only have
--    external_order_item_id IS NULL. Historical additional rows with reasons
--    still satisfy it, so the constraint is added fully validated (no NOT
--    VALID needed). The reason_code enum check
--    (production_requests_reason_code_check) is untouched and still applies
--    whenever a value is present.
--
-- 2. create_additional_production_request: p_reason_code becomes optional
--    (default null). A provided reason_code must still be one of the four
--    enum values, and 'other' still requires a non-empty note. A null
--    reason_code forces a null note (the note has no meaning without a
--    code). Everything else (shift, quantity, unit, day, product
--    validation) is unchanged.
--
-- The function keeps its current grants (EXECUTE for `authenticated` only);
-- CREATE OR REPLACE preserves the existing grant state.
-- ============================================================================

-- 1. Additional rows no longer require a reason.
alter table public.production_requests
  drop constraint production_requests_additional_integrity;

alter table public.production_requests
  add constraint production_requests_additional_integrity
  check (
    (source_type <> 'additional')
    or (external_order_item_id is null)
  );

comment on constraint production_requests_additional_integrity
  on public.production_requests
  is 'Additional production requests must not reference an external order item. '
     'The reason fields are optional since V5.7 (new rows save NULL); '
     'historical rows may keep their reasons.';

-- 2. create_additional_production_request: reason is optional.
create or replace function public.create_additional_production_request(
  p_production_day_id uuid,
  p_product_id uuid,
  p_requested_quantity numeric,
  p_unit text,
  p_shift_code text,
  p_reason_code text default null,
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

  if p_shift_code is null or p_shift_code not in ('morning', 'night') then
    raise exception 'invalid_shift';
  end if;

  -- V5.7: the reason is optional; new additional requests save NULL/NULL.
  -- When a reason code IS provided it must still be valid, and 'other'
  -- still requires a non-empty note. A note without a code is meaningless
  -- and is not stored.
  if p_reason_code is not null and p_reason_code not in ('replenishment', 'increased_demand', 'remake', 'other') then
    raise exception 'invalid_reason';
  end if;

  if p_reason_code = 'other' and (p_reason_note is null or btrim(p_reason_note) = '') then
    raise exception 'reason_note_required';
  end if;

  v_note := case
    when p_reason_code is null then null
    else nullif(btrim(coalesce(p_reason_note, '')), '')
  end;

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

comment on function public.create_additional_production_request(uuid, uuid, numeric, text, text, text, text)
  is 'Creates a pending additional production request for a production day. '
     'Since V5.7 the reason (p_reason_code/p_reason_note) is optional and new '
     'requests save NULL; a provided code must be one of replenishment, '
     'increased_demand, remake, other (other requires a non-empty note). '
     'Shift codes: morning, night only.';

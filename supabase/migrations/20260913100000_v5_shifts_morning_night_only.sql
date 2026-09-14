-- Phase V5.2: retire the afternoon (TARDE) shift for NEW operations.
--
-- Rule (V5 changeset): new production operations may only use MAÑANA (morning)
-- or NOCHE (night). No new afternoon rows, no new 'T' batch codes.
-- Historical rows with shift_code='afternoon' (local dev DB: exactly one
-- pending production_requests row) are PRESERVED and remain readable in
-- history/traceability; display label maps keep TARDE for that reason.
--
-- Mechanism for the five tables that carry a shift code:
--   Each table's shift CHECK constraint is dropped and re-added with
--   `NOT VALID`. A NOT VALID constraint is enforced on every future INSERT
--   and UPDATE but skips validating pre-existing rows -- exactly the
--   "history preserved, no new afternoon" rule. Note a NOT VALID check still
--   applies when a pre-existing row is UPDATED: the one historical afternoon
--   request therefore freezes in place, and its start path fails earlier with
--   a clear invalid_shift raised by next_batch_code (it can never generate a
--   T code).
--
-- ensure_base_production_requests / ensure_external_order_requests:
--   Historical afternoon plan items / order items can no longer exist in the
--   dev data, but if any ever did (e.g. imported), the day-ensure loops must
--   not copy them into new production requests (an afternoon request could
--   never start and would surface as an error on /production). Both loops now
--   create requests only for shift_code in ('morning','night').
--
-- next_batch_code:
--   M (morning) / N (night) only. Any other shift raises invalid_shift, so a
--   'T' code can never be generated. Sequence rule, advisory-lock strategy and
--   concurrency behavior are unchanged.
--
-- Admin RPCs (add_external_order_item, create_product, update_product,
-- create_production_plan_item, update_production_plan_item,
-- create_additional_production_request): shift validation tightened to
-- ('morning','night'); everything else (auth model, error tokens, grants) is
-- unchanged -- create or replace keeps the existing revoke/grant state.
--
-- No RLS changes; no data is modified by this migration.

-- 1. Shift CHECK constraints: morning/night only, NOT VALID to preserve the
--    historical afternoon row(s) already present.
alter table public.products drop constraint products_default_shift_code_check;
alter table public.products
  add constraint products_default_shift_code_check
  check (default_shift_code in ('morning', 'night')) not valid;

alter table public.production_plan_items drop constraint production_plan_items_shift_code_check;
alter table public.production_plan_items
  add constraint production_plan_items_shift_code_check
  check (shift_code in ('morning', 'night')) not valid;

alter table public.external_order_items drop constraint external_order_items_shift_code_check;
alter table public.external_order_items
  add constraint external_order_items_shift_code_check
  check (shift_code in ('morning', 'night')) not valid;

alter table public.production_requests drop constraint production_requests_shift_code_check;
alter table public.production_requests
  add constraint production_requests_shift_code_check
  check (shift_code in ('morning', 'night')) not valid;

alter table public.production_batches drop constraint production_batches_shift_code_check;
alter table public.production_batches
  add constraint production_batches_shift_code_check
  check (shift_code in ('morning', 'night')) not valid;

-- 2. next_batch_code: M/N only, no new T codes.
create or replace function public.next_batch_code(p_production_day_id uuid, p_shift_code text)
returns text
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_production_date date;
  v_letter char(1);
  v_next int;
  v_code text;
begin
  select production_date into v_production_date
  from public.production_days
  where id = p_production_day_id;

  if v_production_date is null then
    raise exception 'production_day_not_found';
  end if;

  v_letter := case p_shift_code
    when 'morning' then 'M'
    when 'night' then 'N'
    else null
  end;

  if v_letter is null then
    raise exception 'invalid_shift';
  end if;

  -- Serialize code generation per (production_date, shift_code) for the whole
  -- caller transaction (see header comment for the strategy).
  perform pg_advisory_xact_lock(hashtext(v_production_date::text || '|' || p_shift_code));

  select coalesce(max(regexp_replace(batch_code, '^.*-([0-9]+)$', '\1')::int), 0) + 1
    into v_next
  from public.production_batches
  where batch_code like 'PAN-' || to_char(v_production_date, 'DDMMYY') || '-' || v_letter || '-%';

  v_code := 'PAN-' || to_char(v_production_date, 'DDMMYY') || '-' || v_letter || '-' || lpad(v_next::text, 3, '0');

  return v_code;
end;
$$;

comment on function public.next_batch_code(uuid, text) is
  'Generates the next PAN-DDMMYY-X-NNN batch code for a production day and shift; X is M (morning) or N (night) only -- afternoon (T) is historical and never generated; sequence resets by stored production_date + shift_code; transaction-scoped advisory lock makes generation concurrency-safe when the batch insert happens in the same transaction.';

-- 3. ensure_base_production_requests: skip historical afternoon plan items.
create or replace function public.ensure_base_production_requests(
  p_production_day_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_production_date date;
  v_weekday smallint;
  v_created integer := 0;
  rec record;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if not exists (select 1 from public.profiles where id = v_user_id and active) then
    raise exception 'no_active_profile';
  end if;

  select production_date into v_production_date
  from public.production_days
  where id = p_production_day_id;

  if not found then
    raise exception 'production_day_not_found';
  end if;

  -- Serialize concurrent generation for the same day.
  perform 1
  from public.production_days
  where id = p_production_day_id
  for update;

  -- ISO weekday of the STORED production date: 1 = Monday ... 7 = Sunday.
  v_weekday := extract(isodow from v_production_date)::smallint;

  for rec in
    select product_id, shift_code, planned_quantity, unit
    from public.production_plan_items
    where weekday = v_weekday
      and active
      and shift_code in ('morning','night')
    order by sort_order, id
  loop
    if not exists (
      select 1
      from public.production_requests r
      where r.production_day_id = p_production_day_id
        and r.source_type = 'base'
        and r.product_id = rec.product_id
        and r.shift_code = rec.shift_code
    ) then
      insert into public.production_requests (
        production_day_id, source_type, shift_code, product_id,
        requested_quantity, unit, status, created_by
      ) values (
        p_production_day_id, 'base', rec.shift_code, rec.product_id,
        rec.planned_quantity, rec.unit, 'pending', v_user_id
      );
      v_created := v_created + 1;
    end if;
  end loop;

  return v_created;
end;
$$;

-- 4. ensure_external_order_requests: skip historical afternoon order items.
create or replace function public.ensure_external_order_requests(
  p_production_day_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_production_date date;
  v_created integer := 0;
  rec record;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if not exists (select 1 from public.profiles where id = v_user_id and active) then
    raise exception 'no_active_profile';
  end if;

  select production_date into v_production_date
  from public.production_days
  where id = p_production_day_id;

  if not found then
    raise exception 'production_day_not_found';
  end if;

  -- Serialize concurrent generation for the same day.
  perform 1
  from public.production_days
  where id = p_production_day_id
  for update;

  for rec in
    select i.id as item_id, i.product_id, i.quantity, i.unit, i.shift_code
    from public.external_order_items i
    join public.external_orders o on o.id = i.external_order_id
    where o.requested_date = v_production_date
      and o.status <> 'cancelled'
      and i.shift_code in ('morning','night')
    order by i.id
  loop
    if not exists (
      select 1
      from public.production_requests r
      where r.production_day_id = p_production_day_id
        and r.source_type = 'external_order'
        and r.external_order_item_id = rec.item_id
    ) then
      insert into public.production_requests (
        production_day_id, source_type, shift_code, product_id,
        requested_quantity, unit, external_order_item_id, status, created_by
      ) values (
        p_production_day_id, 'external_order', rec.shift_code, rec.product_id,
        rec.quantity, rec.unit, rec.item_id, 'pending', v_user_id
      );
      v_created := v_created + 1;
    end if;
  end loop;

  return v_created;
end;
$$;

-- 5. add_external_order_item: morning/night only.
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

  if p_shift_code is null or p_shift_code not in ('morning', 'night') then
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

-- 6. create_product / update_product: morning/night only.
create or replace function public.create_product(
  p_name text,
  p_default_unit text,
  p_default_shift_code text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_role text;
  v_name text;
  v_unit text;
  v_shift text;
  v_new_id uuid;
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

  -- 2. Role gate: only admin manages master data.
  if v_role <> 'admin' then
    raise exception 'insufficient_role';
  end if;

  -- 3. Validation.
  v_name := trim(coalesce(p_name, ''));
  if v_name = '' then
    raise exception 'invalid_name';
  end if;

  v_unit := trim(coalesce(p_default_unit, ''));
  if v_unit = '' then
    raise exception 'invalid_unit';
  end if;

  v_shift := trim(coalesce(p_default_shift_code, ''));
  if v_shift not in ('morning', 'night') then
    raise exception 'invalid_shift';
  end if;

  -- 4. Insert and return the new id.
  insert into public.products (name, default_unit, default_shift_code)
  values (v_name, v_unit, v_shift)
  returning id into v_new_id;

  return v_new_id;
end;
$$;

create or replace function public.update_product(
  p_id uuid,
  p_name text,
  p_default_unit text,
  p_default_shift_code text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_role text;
  v_name text;
  v_unit text;
  v_shift text;
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

  -- 2. Role gate: only admin manages master data.
  if v_role <> 'admin' then
    raise exception 'insufficient_role';
  end if;

  -- 3. Validation.
  if not exists (select 1 from public.products where id = p_id) then
    raise exception 'product_not_found';
  end if;

  v_name := trim(coalesce(p_name, ''));
  if v_name = '' then
    raise exception 'invalid_name';
  end if;

  v_unit := trim(coalesce(p_default_unit, ''));
  if v_unit = '' then
    raise exception 'invalid_unit';
  end if;

  v_shift := trim(coalesce(p_default_shift_code, ''));
  if v_shift not in ('morning', 'night') then
    raise exception 'invalid_shift';
  end if;

  -- 4. Update and return the id. Historical shifts already copied into
  -- production_requests/production_batches are never touched.
  update public.products
  set name = v_name,
      default_unit = v_unit,
      default_shift_code = v_shift,
      updated_at = now()
  where id = p_id;

  return p_id;
end;
$$;

-- 7. create_production_plan_item / update_production_plan_item: morning/night only.
create or replace function public.create_production_plan_item(
  p_weekday smallint,
  p_shift_code text,
  p_product_id uuid,
  p_planned_quantity numeric,
  p_unit text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_role text;
  v_shift text;
  v_unit text;
  v_new_id uuid;
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

  -- 2. Role gate: only admin manages master data.
  if v_role <> 'admin' then
    raise exception 'insufficient_role';
  end if;

  -- 3. Validation.
  if p_weekday is null or p_weekday < 1 or p_weekday > 7 then
    raise exception 'invalid_weekday';
  end if;

  v_shift := trim(coalesce(p_shift_code, ''));
  if v_shift not in ('morning', 'night') then
    raise exception 'invalid_shift';
  end if;

  if not exists (select 1 from public.products where id = p_product_id) then
    raise exception 'product_not_found';
  end if;

  if p_planned_quantity is null or p_planned_quantity <= 0 then
    raise exception 'invalid_quantity';
  end if;

  v_unit := trim(coalesce(p_unit, ''));
  if v_unit = '' then
    raise exception 'invalid_unit';
  end if;

  -- At most one ACTIVE row per (weekday, shift, product, unit).
  if exists (
    select 1
    from public.production_plan_items
    where weekday = p_weekday
      and shift_code = v_shift
      and product_id = p_product_id
      and unit = v_unit
      and active
  ) then
    raise exception 'already_planned';
  end if;

  -- 4. Insert with the next sort_order within the weekday + shift group.
  insert into public.production_plan_items
    (weekday, shift_code, product_id, planned_quantity, unit, sort_order)
  values
    (
      p_weekday,
      v_shift,
      p_product_id,
      p_planned_quantity,
      v_unit,
      (
        select coalesce(max(sort_order), 0) + 1
        from public.production_plan_items
        where weekday = p_weekday and shift_code = v_shift
      )
    )
  returning id into v_new_id;

  return v_new_id;
end;
$$;

create or replace function public.update_production_plan_item(
  p_id uuid,
  p_weekday smallint,
  p_shift_code text,
  p_product_id uuid,
  p_planned_quantity numeric,
  p_unit text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_role text;
  v_shift text;
  v_unit text;
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

  -- 2. Role gate: only admin manages master data.
  if v_role <> 'admin' then
    raise exception 'insufficient_role';
  end if;

  -- 3. Validation.
  if not exists (select 1 from public.production_plan_items where id = p_id) then
    raise exception 'production_plan_item_not_found';
  end if;

  if p_weekday is null or p_weekday < 1 or p_weekday > 7 then
    raise exception 'invalid_weekday';
  end if;

  v_shift := trim(coalesce(p_shift_code, ''));
  if v_shift not in ('morning', 'night') then
    raise exception 'invalid_shift';
  end if;

  if not exists (select 1 from public.products where id = p_product_id) then
    raise exception 'product_not_found';
  end if;

  if p_planned_quantity is null or p_planned_quantity <= 0 then
    raise exception 'invalid_quantity';
  end if;

  v_unit := trim(coalesce(p_unit, ''));
  if v_unit = '' then
    raise exception 'invalid_unit';
  end if;

  -- At most one ACTIVE row per (weekday, shift, product, unit), excluding
  -- this row itself.
  if exists (
    select 1
    from public.production_plan_items
    where weekday = p_weekday
      and shift_code = v_shift
      and product_id = p_product_id
      and unit = v_unit
      and active
      and id <> p_id
  ) then
    raise exception 'already_planned';
  end if;

  -- 4. Update. sort_order is preserved (position in the plan is stable).
  update public.production_plan_items
  set weekday = p_weekday,
      shift_code = v_shift,
      product_id = p_product_id,
      planned_quantity = p_planned_quantity,
      unit = v_unit,
      updated_at = now()
  where id = p_id;

  return p_id;
end;
$$;

-- 8. create_additional_production_request: shift validation morning/night only
--    (the reason_code handling is relaxed separately in the V5.7 migration).
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

  if p_shift_code is null or p_shift_code not in ('morning', 'night') then
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


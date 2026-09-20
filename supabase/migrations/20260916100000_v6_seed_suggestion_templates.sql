-- V6.7: idempotent seed of reviewed suggestion templates (spec §56, V6 STEP 7).
--
-- One narrow RPC:
--   seed_v6_suggestion_templates(p_items jsonb) -> jsonb
--
-- p_items: array of fully resolved rows (resolved from the V6.6 review CSVs,
-- spec §44-§48). Every element:
--   {
--     "weekday": 1..6 (smallint, 1 = Monday ... 6 = Saturday),
--     "code": "A".."E" (only Tuesday may use "E"),
--     "source_sheet": "LUNES"|"MARTES"|"MIÉRCOLES"|"JUEVES"|"VIERNES"|"SÁBADO",
--     "source_row": integer > 0,
--     "source_text": exact workbook cell text (audit, spec §43),
--     "product_name": master product name to reuse or create,
--     "default_shift": "morning"|"night" (default shift for a NEW product),
--     "suggested_quantity": numeric > 0,
--     "unit": non-empty text
--   }
--
-- Rules:
-- 1. Admin role only (same gate as the AL3 master-data RPCs).
-- 2. Monday-Saturday only, no Sunday (spec §56); A-D every day, A-E Tuesday
--    only; source_sheet must match the weekday.
-- 3. morning/night only: afternoon is never a template shift, so Saturday
--    PARA LA TARDE rows can never enter templates (spec §46).
-- 4. Products are reused by normalized name (lowercase, whitespace collapsed)
--    and created only when absent: no duplicate product creation (spec §56).
-- 5. Idempotency: for each (weekday, code) group, if an active master
--    suggestion already exists the whole group is skipped (neither suggestion
--    nor items are touched). On a fresh seed each group is created once and
--    its items are inserted in payload order (= source order, the driver
--    pre-sorts by source row).
-- 6. No daily selections are created by this step (spec §56).
-- 7. No client direct-write path: the master tables keep their SELECT-only
--    RLS from V6.4; this is the only write path.
--
-- Error tokens (English, developer-facing):
--   not_authenticated, no_active_profile, insufficient_role, invalid_items,
--   invalid_weekday, invalid_code, invalid_source_sheet, weekday_sheet_mismatch,
--   invalid_source_row, invalid_source_text, invalid_product_name,
--   invalid_shift, invalid_quantity, invalid_unit.
-- (invalid_shift also covers an EXISTING product whose default shift is
--  afternoon: such a product cannot be used in morning/night templates.)

create or replace function public.seed_v6_suggestion_templates(p_items jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_role text;
  v_item jsonb;
  v_weekday smallint;
  v_code text;
  v_sheet text;
  v_sheet_weekday smallint;
  v_row_raw text;
  v_text text;
  v_product_name text;
  v_product_norm text;
  v_shift text;
  v_qty_raw text;
  v_qty numeric;
  v_unit text;
  v_pair text;
  v_groups text[] := array[]::text[];
  v_created_groups text[] := array[]::text[];
  v_product_names text[] := array[]::text[];
  v_products jsonb := '[]'::jsonb;
  v_def jsonb;
  v_def_name text;
  v_def_norm text;
  v_def_shift text;
  v_def_unit text;
  v_product_id uuid;
  v_product_shift text;
  v_existing uuid;
  v_w smallint;
  v_c text;
  v_suggestions_created int := 0;
  v_suggestions_skipped int := 0;
  v_items_inserted int := 0;
  v_products_created int := 0;
  v_products_reused int := 0;
  v_sort_map jsonb := '{}'::jsonb;
  v_n int;
  v_db_count int;
  v_report jsonb := '[]'::jsonb;
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

  -- 2. Role gate: only admin seeds master templates.
  if v_role <> 'admin' then
    raise exception 'insufficient_role';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'invalid_items';
  end if;

  -- Pass 1: validate every row; collect (weekday, code) groups and distinct
  -- products in first-seen order.
  for v_item in select * from jsonb_array_elements(p_items) loop
    if (v_item->>'weekday') is null or (v_item->>'weekday') !~ '^[0-9]+$' then
      raise exception 'invalid_weekday';
    end if;
    v_weekday := (v_item->>'weekday')::smallint;
    if v_weekday not between 1 and 6 then
      raise exception 'invalid_weekday';
    end if;

    v_code := upper(trim(coalesce(v_item->>'code', '')));
    if v_code not in ('A', 'B', 'C', 'D', 'E') then
      raise exception 'invalid_code';
    end if;
    if v_code = 'E' and v_weekday <> 2 then
      raise exception 'invalid_code';
    end if;

    v_sheet := trim(coalesce(v_item->>'source_sheet', ''));
    if v_sheet not in ('LUNES', 'MARTES', 'MIÉRCOLES', 'JUEVES', 'VIERNES', 'SÁBADO') then
      raise exception 'invalid_source_sheet';
    end if;
    v_sheet_weekday := case v_sheet
      when 'LUNES' then 1
      when 'MARTES' then 2
      when 'MIÉRCOLES' then 3
      when 'JUEVES' then 4
      when 'VIERNES' then 5
      else 6
    end;
    if v_sheet_weekday <> v_weekday then
      raise exception 'weekday_sheet_mismatch';
    end if;

    v_row_raw := trim(coalesce(v_item->>'source_row', ''));
    if v_row_raw !~ '^[0-9]+$' or v_row_raw::int <= 0 then
      raise exception 'invalid_source_row';
    end if;

    v_text := v_item->>'source_text';
    if v_text is null or v_text = '' then
      raise exception 'invalid_source_text';
    end if;

    v_product_name := trim(coalesce(v_item->>'product_name', ''));
    if v_product_name = '' then
      raise exception 'invalid_product_name';
    end if;
    v_product_norm := lower(regexp_replace(v_product_name, '\s+', ' ', 'g'));

    v_shift := trim(coalesce(v_item->>'default_shift', ''));
    if v_shift not in ('morning', 'night') then
      raise exception 'invalid_shift';
    end if;

    v_qty_raw := trim(coalesce(v_item->>'suggested_quantity', ''));
    if v_qty_raw !~ '^-?[0-9]+(\.[0-9]+)?$' then
      raise exception 'invalid_quantity';
    end if;
    v_qty := v_qty_raw::numeric;
    if v_qty <= 0 then
      raise exception 'invalid_quantity';
    end if;

    v_unit := trim(coalesce(v_item->>'unit', ''));
    if v_unit = '' then
      raise exception 'invalid_unit';
    end if;

    v_pair := v_weekday || ':' || v_code;
    if not (v_pair = any(v_groups)) then
      v_groups := array_append(v_groups, v_pair);
    end if;
    if not (v_product_norm = any(v_product_names)) then
      v_product_names := array_append(v_product_names, v_product_norm);
      v_products := v_products || jsonb_build_object(
        'name', v_product_name,
        'norm', v_product_norm,
        'shift', v_shift,
        'unit', v_unit);
    end if;
  end loop;

  -- Pass 2: products — reuse by normalized name, create only when absent.
  for v_def in select * from jsonb_array_elements(v_products) loop
    v_def_name := v_def->>'name';
    v_def_norm := v_def->>'norm';
    v_def_shift := v_def->>'shift';
    v_def_unit := v_def->>'unit';
    select p.id, p.default_shift_code
    into v_product_id, v_product_shift
    from public.products p
    where p.active
      and lower(regexp_replace(p.name, '\s+', ' ', 'g')) = v_def_norm
    order by p.created_at
    limit 1;
    if v_product_id is null then
      insert into public.products (name, default_unit, default_shift_code)
      values (v_def_name, v_def_unit, v_def_shift)
      returning id into v_product_id;
      v_products_created := v_products_created + 1;
    else
      if v_product_shift not in ('morning', 'night') then
        raise exception 'invalid_shift';
      end if;
      v_products_reused := v_products_reused + 1;
    end if;
  end loop;

  -- Pass 3: suggestions — create missing (weekday, code) groups, skip
  -- existing active ones (idempotent re-runs are no-ops).
  foreach v_pair in array v_groups loop
    v_w := split_part(v_pair, ':', 1)::smallint;
    v_c := split_part(v_pair, ':', 2);
    select s.id into v_existing
    from public.production_suggestions s
    where s.weekday = v_w and s.code = v_c and s.active
    limit 1;
    if v_existing is null then
      insert into public.production_suggestions (weekday, code, sort_order)
      values (v_w, v_c, (v_w - 1) * 10 + position(v_c in 'ABCDE'))
      returning id into v_existing;
      v_created_groups := array_append(v_created_groups, v_pair);
      v_suggestions_created := v_suggestions_created + 1;
    else
      v_suggestions_skipped := v_suggestions_skipped + 1;
    end if;
  end loop;

  -- Pass 4: items — only for groups created in this run, in payload order
  -- (= source order). Pre-existing groups are never touched.
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_weekday := (v_item->>'weekday')::smallint;
    v_code := upper(trim(v_item->>'code'));
    v_pair := v_weekday || ':' || v_code;
    if not (v_pair = any(v_created_groups)) then
      continue;
    end if;

    v_product_norm := lower(regexp_replace(trim(v_item->>'product_name'), '\s+', ' ', 'g'));
    select p.id, p.default_shift_code
    into v_product_id, v_product_shift
    from public.products p
    where p.active
      and lower(regexp_replace(p.name, '\s+', ' ', 'g')) = v_product_norm
    order by p.created_at
    limit 1;

    v_n := coalesce((v_sort_map->>v_pair), '0')::int + 1;
    v_sort_map := v_sort_map || jsonb_build_object(v_pair, v_n);

    insert into public.production_suggestion_items
      (suggestion_id, product_id, shift_code, suggested_quantity, unit, source_text, sort_order)
    select s.id, v_product_id, v_product_shift,
           (v_item->>'suggested_quantity')::numeric,
           trim(v_item->>'unit'),
           v_item->>'source_text',
           v_n
    from public.production_suggestions s
    where s.weekday = v_weekday and s.code = v_code and s.active;

    v_items_inserted := v_items_inserted + 1;
  end loop;

  -- Report: actual DB count of items per (weekday, code), group order.
  foreach v_pair in array v_groups loop
    v_w := split_part(v_pair, ':', 1)::smallint;
    v_c := split_part(v_pair, ':', 2);
    select count(*) into v_db_count
    from public.production_suggestion_items i
    join public.production_suggestions s on s.id = i.suggestion_id
    where s.weekday = v_w and s.code = v_c and s.active and i.active;
    v_report := v_report || jsonb_build_array(v_w, v_c, v_db_count);
  end loop;

  return jsonb_build_object(
    'payload_items', jsonb_array_length(p_items),
    'suggestions_created', v_suggestions_created,
    'suggestions_skipped_existing', v_suggestions_skipped,
    'items_inserted', v_items_inserted,
    'products_created', v_products_created,
    'products_reused', v_products_reused,
    'per_weekday_code', v_report);
end;
$$;

revoke execute on function public.seed_v6_suggestion_templates(jsonb) from public, anon, service_role, authenticated;
grant execute on function public.seed_v6_suggestion_templates(jsonb) to authenticated;

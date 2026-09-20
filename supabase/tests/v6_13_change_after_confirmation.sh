#!/usr/bin/env bash
# V6.13 (spec §62) behavior tests: SAFE CHANGE AFTER CONFIRMATION.
#
# The repository has no DB-test framework, so these follow the established
# V6 pattern: each negative case runs in its own aborted transaction; the
# positive flows run in transactions that are rolled back at the end.
# Nothing persists.
#
# Coverage (spec §62, exact scenario):
#   Suggestion B is confirmed; Baguette is already in_progress; Chip and
#   Pebete are still pending; the user selects suggestion C.
#   * Baguette request preserved + locked: row byte-identical (quantity
#     5 never rewritten to C's 8), status stays in_progress, its item
#     stays linked (no duplicate snapshot item for the same product);
#   * Chip (B-only, pending) cancelled history-safe;
#   * Pebete (shared, pending, qty 2 -> 4 in C') request updated in place
#     while still pending (no duplicate);
#   * Hamburguesa (C-only) pending request created;
#   * an additional request for Chip is untouched;
#   * the new selection is DRAFT until re-confirmed;
#   * re-confirming is idempotent (no duplicates, nothing rewritten);
#   * a supervisor can execute the same change (operator already covered);
#   * the internal helper has no client grants;
#   * confirm's existing gates still hold (regression).
#
# Fixtures: two private suggestion rows (B'/C') with controlled items,
# created inside the rolled-back transactions (they never persist).
#
# Usage: bash supabase/tests/v6_13_change_after_confirmation.sh
set -u
DB=supabase_db_bakery-traceability
OPERATOR=9ba5032b-93bb-40fa-b665-a45a8c11aff1
SUPERVISOR=be18bd95-e3e4-488d-ab33-820ef8ad86d0
FAIL=0

# Run SQL inside begin/...;rollback; and print psql output (errors included).
run() {
  docker exec -i "$DB" psql -U postgres -d postgres -q -t -A -c "begin; $1 rollback;" 2>&1
}

# Print the raised error token (or empty on success).
token() {
  run "$1" | grep -oE 'ERROR:  [a-z_]+' | head -1 | sed 's/ERROR:  //'
}

jset() { # set jwt claims as $1 (DO block: produces no result line)
  echo "do \$d\$ begin perform set_config('request.jwt.claims', '{\"sub\": \"$1\"}', false); end \$d\$;"
}

check() { # $1 name, $2 expected, $3 actual
  if [ "$2" = "$3" ]; then
    echo "PASS  $1"
  else
    echo "FAIL  $1: expected [$2] got [$3]"
    FAIL=1
  fi
}

# A real active 'A' suggestion for the current business weekday (gates only).
SUG_TODAY=$(docker exec -i "$DB" psql -U postgres -d postgres -t -A -c \
  "select id from public.production_suggestions where active and code = 'A' and weekday = extract(isodow from public.get_business_date())::smallint limit 1;")
if [ -z "$SUG_TODAY" ]; then
  echo "SKIP  no active 'A' suggestion for the current business weekday; run on another day"
  exit 0
fi

DAY_ID="(select id from public.production_days where production_date = public.get_business_date())"
WEEKDAY="(extract(isodow from public.get_business_date())::smallint)"
ANY_OTHER_WEEKDAY_SUG="(select id from public.production_suggestions where active and weekday <> extract(isodow from public.get_business_date())::smallint limit 1)"

# Fixture products (stable live rows; names are business data).
BAGUETTE="(select id from public.products where name = 'Baguette' limit 1)"
CHIP="(select id from public.products where name = 'Chip' limit 1)"
PEBETE="(select id from public.products where name = 'Pan pebete' limit 1)"
HAMBURGUESA="(select id from public.products where name = 'Hamburguesa' limit 1)"

# Fixture suggestions B'/C' for the current weekday (private rows; the
# rollback erases them). B' has Baguette/Chip/Pebete; C' has Baguette
# (different qty)/Pebete/Hamburguesa.
fixture_sql="
create temporary table _v613 (sug_b uuid, sug_c uuid);
insert into _v613 values (null, null);
-- code is limited to A-E and (weekday, code) is unique among active rows,
-- so free the B/C slots for this weekday (the live rows are deactivated
-- inside the rolled-back transaction; the rollback restores them).
update public.production_suggestions set active = false
 where weekday = $WEEKDAY and code in ('B', 'C') and active;
with nb as (insert into public.production_suggestions (weekday, code, active, sort_order)
  values ($WEEKDAY, 'B', true, 90) returning id)
update _v613 set sug_b = (select id from nb);
with nc as (insert into public.production_suggestions (weekday, code, active, sort_order)
  values ($WEEKDAY, 'C', true, 91) returning id)
update _v613 set sug_c = (select id from nc);
insert into public.production_suggestion_items (suggestion_id, product_id, shift_code, suggested_quantity, unit, sort_order, active)
values ((select sug_b from _v613), $BAGUETTE, 'morning', 5, 'latas', 1, true),
       ((select sug_b from _v613), $CHIP, 'morning', 3, 'latas', 2, true),
       ((select sug_b from _v613), $PEBETE, 'morning', 2, 'latas', 3, true),
       ((select sug_c from _v613), $BAGUETTE, 'morning', 8, 'latas', 1, true),
       ((select sug_c from _v613), $PEBETE, 'morning', 4, 'latas', 2, true),
       ((select sug_c from _v613), $HAMBURGUESA, 'night', 1, 'carro', 3, true);
"

# ---- negative cases (each in its own aborted transaction) ----
check "choose_not_authenticated" \
  "not_authenticated" \
  "$(token "select public.choose_daily_production_suggestion($DAY_ID, '$SUG_TODAY');")"

check "choose_no_active_profile" \
  "no_active_profile" \
  "$(token "$(jset 99999999-9999-9999-9999-999999999999) select public.choose_daily_production_suggestion($DAY_ID, '$SUG_TODAY');")"

check "choose_production_day_not_found" \
  "production_day_not_found" \
  "$(token "$(jset $OPERATOR) select public.choose_daily_production_suggestion('00000000-0000-0000-0000-000000000000', '$SUG_TODAY');")"

check "choose_suggestion_not_found" \
  "suggestion_not_found" \
  "$(token "$(jset $OPERATOR) select public.choose_daily_production_suggestion($DAY_ID, '00000000-0000-0000-0000-000000000000');")"

check "choose_weekday_mismatch" \
  "weekday_mismatch" \
  "$(token "$(jset $OPERATOR) select public.choose_daily_production_suggestion($DAY_ID, $ANY_OTHER_WEEKDAY_SUG);")"

# The internal reconciliation helper must not be callable by clients
# (executed as the 'authenticated' role: EXECUTE privileges apply to the
# database role, and the psql user is a superuser).
check "helper_not_granted" \
  "permission" \
  "$(token "$(jset $OPERATOR) set role authenticated; select public.reconcile_daily_production_selection(null, $DAY_ID, '00000000-0000-0000-0000-000000000000');")"

# Regression: confirm's gates still hold after the V6.13 rewrite.
check "confirm_not_authenticated" \
  "not_authenticated" \
  "$(token "select public.confirm_daily_production();")"

check "confirm_no_active_profile" \
  "no_active_profile" \
  "$(token "$(jset 99999999-9999-9999-9999-999999999999) select public.confirm_daily_production();")"

check "confirm_no_selection_for_today" \
  "no_selection_for_today" \
  "$(token "$(jset $OPERATOR) delete from public.daily_production_selection_items; delete from public.daily_production_selections; select public.confirm_daily_production();")"

# ---- positive flow (operator), one transaction, rolled back at the end ----
flow_sql="
insert into public.production_days (production_date, status, opened_at, opened_by)
  values (public.get_business_date(), 'open', now(), '$OPERATOR')
  on conflict (production_date) do nothing;
$(jset $OPERATOR)
$fixture_sql
-- 1) Select B' (creation path): a draft must carry NO requests (§61).
select public.choose_daily_production_suggestion($DAY_ID, (select sug_b from _v613));
select 'CHECK|01_draft_has_no_requests' || (select count(*) from public.production_requests r where r.production_day_id = $DAY_ID and r.source_type = 'base');
-- 2) Confirm B': the three selected items get pending base requests.
select public.confirm_daily_production();
select 'CHECK|02_confirmed_three_pending' || (select count(*) from public.production_requests r where r.production_day_id = $DAY_ID and r.source_type = 'base' and r.status = 'pending' and r.created_by = '$OPERATOR');
-- 3) Baguette is already in_progress (started batch simulation).
update public.production_requests set status = 'in_progress'
 where production_day_id = $DAY_ID and source_type = 'base'
   and product_id = $BAGUETTE and created_by = '$OPERATOR';
-- An ADDITIONAL pending request for Chip (the B-only product): must survive.
insert into public.production_requests (production_day_id, source_type, shift_code, product_id, requested_quantity, unit, status, created_by)
 values ($DAY_ID, 'additional', 'morning', $CHIP, 7, 'lata', 'pending', '$OPERATOR');
-- Snapshot the exact in_progress and additional rows (byte-compare later).
create temporary table _v613_bag on commit drop as
 select row_to_json(t)::jsonb as row from (select * from public.production_requests where production_day_id = $DAY_ID and source_type = 'base' and product_id = $BAGUETTE and status = 'in_progress') t;
create temporary table _v613_addl on commit drop as
 select row_to_json(t)::jsonb as row from (select * from public.production_requests where production_day_id = $DAY_ID and source_type = 'additional') t;
-- 4) THE change of spec §62: with B confirmed, select C'.
select public.choose_daily_production_suggestion($DAY_ID, (select sug_c from _v613));
select 'CHECK|03_selection_draft' || (select status from public.daily_production_selections where production_day_id = $DAY_ID);
select 'CHECK|04_selection_on_c' || (select suggestion_id = (select sug_c from _v613) from public.daily_production_selections where production_day_id = $DAY_ID);
select 'CHECK|05_stamp_cleared' || (select confirmed_by is null and confirmed_at is null from public.daily_production_selections where production_day_id = $DAY_ID);
-- Baguette: exactly one request, byte-identical, in_progress, qty NOT 8.
select 'CHECK|06_bag_single_request' || (select count(*) from public.production_requests r where r.production_day_id = $DAY_ID and r.source_type = 'base' and r.product_id = $BAGUETTE);
select 'CHECK|07_bag_row_untouched' || (select (b.row = n.row) from _v613_bag b, (select row_to_json(t)::jsonb as row from (select * from public.production_requests where production_day_id = $DAY_ID and source_type = 'base' and product_id = $BAGUETTE) t) n);
select 'CHECK|08_bag_in_progress_qty5' || (select (r.status = 'in_progress' and r.requested_quantity = 5) from public.production_requests r where r.production_day_id = $DAY_ID and r.source_type = 'base' and r.product_id = $BAGUETTE);
-- The preserved item stays the single (linked) Baguette item.
select 'CHECK|09_bag_item_single_linked' || (
  select (count(*) = 1 and bool_and(i.production_request_id = (select r.id from public.production_requests r where r.production_day_id = $DAY_ID and r.source_type = 'base' and r.product_id = $BAGUETTE)))
  from public.daily_production_selection_items i
  where i.daily_selection_id = (select id from public.daily_production_selections where production_day_id = $DAY_ID)
    and i.product_id = $BAGUETTE
);
-- Chip: its PENDING base request is cancelled (B-only product, not in C).
select 'CHECK|10_chip_base_cancelled' || (
  select (count(*) > 0 and not exists (select 1 from public.production_requests r where r.production_day_id = $DAY_ID and r.source_type = 'base' and r.product_id = $CHIP and r.status <> 'cancelled'))
  from public.production_requests r where r.production_day_id = $DAY_ID and r.source_type = 'base' and r.product_id = $CHIP
);
-- The additional Chip request is untouched (byte-identical).
select 'CHECK|11_additional_untouched' || (select (a.row = n.row) from _v613_addl a, (select row_to_json(t)::jsonb as row from (select * from public.production_requests where production_day_id = $DAY_ID and source_type = 'additional') t) n);
-- Pebete: the SAME pending request, updated in place, linked, no duplicate.
select 'CHECK|12_pebete_updated_in_place' || (
  select (count(*) = 1 and bool_and(r.status = 'pending' and r.requested_quantity = 4 and r.unit = 'latas' and exists (select 1 from public.daily_production_selection_items i where i.daily_selection_id = (select id from public.daily_production_selections where production_day_id = $DAY_ID) and i.production_request_id = r.id)))
  from public.production_requests r where r.production_day_id = $DAY_ID and r.source_type = 'base' and r.product_id = $PEBETE
);
-- Hamburguesa: new pending request, linked, created by the operator.
select 'CHECK|13_hamburguesa_created' || (
  select (count(*) = 1 and bool_and(r.status = 'pending' and r.requested_quantity = 1 and r.unit = 'carro' and r.created_by = '$OPERATOR' and exists (select 1 from public.daily_production_selection_items i where i.daily_selection_id = (select id from public.daily_production_selections where production_day_id = $DAY_ID) and i.production_request_id = r.id)))
  from public.production_requests r where r.production_day_id = $DAY_ID and r.source_type = 'base' and r.product_id = $HAMBURGUESA
);
-- Snapshot integrity: 3 items (deduped), 4 base requests, no orphan pending.
select 'CHECK|14_item_count_three' || (select count(*) from public.daily_production_selection_items where daily_selection_id = (select id from public.daily_production_selections where production_day_id = $DAY_ID));
select 'CHECK|15_base_total_four' || (select count(*) from public.production_requests r where r.production_day_id = $DAY_ID and r.source_type = 'base');
select 'CHECK|16_no_orphan_pending_base' || (
  select count(*) from public.production_requests r
  where r.production_day_id = $DAY_ID and r.source_type = 'base' and r.status = 'pending'
    and not exists (select 1 from public.daily_production_selection_items i where i.daily_selection_id = (select id from public.daily_production_selections where production_day_id = $DAY_ID) and i.production_request_id = r.id)
);
-- 5) Re-confirm: idempotent, no duplicates, started row still untouched.
select public.confirm_daily_production();
select 'CHECK|17_still_confirmed' || (select (status = 'confirmed' and confirmed_by = '$OPERATOR') from public.daily_production_selections where production_day_id = $DAY_ID);
select 'CHECK|18_base_total_still_four' || (select count(*) from public.production_requests r where r.production_day_id = $DAY_ID and r.source_type = 'base');
select 'CHECK|19_bag_row_still_untouched' || (select (b.row = n.row) from _v613_bag b, (select row_to_json(t)::jsonb as row from (select * from public.production_requests where production_day_id = $DAY_ID and source_type = 'base' and product_id = $BAGUETTE) t) n);
select 'CHECK|20_chip_still_cancelled' || (select count(*) from public.production_requests r where r.production_day_id = $DAY_ID and r.source_type = 'base' and r.product_id = $CHIP and r.status <> 'cancelled');
"
out=$(run "$flow_sql")

check "draft_has_no_requests" "CHECK|01_draft_has_no_requests0" "$(echo "$out" | grep '^CHECK|01_')"
check "confirmed_three_pending" "CHECK|02_confirmed_three_pending3" "$(echo "$out" | grep '^CHECK|02_')"
check "selection_draft" "CHECK|03_selection_draftdraft" "$(echo "$out" | grep '^CHECK|03_')"
check "selection_on_c" "CHECK|04_selection_on_ctrue" "$(echo "$out" | grep '^CHECK|04_')"
check "stamp_cleared" "CHECK|05_stamp_clearedtrue" "$(echo "$out" | grep '^CHECK|05_')"
check "bag_single_request" "CHECK|06_bag_single_request1" "$(echo "$out" | grep '^CHECK|06_')"
check "bag_row_untouched" "CHECK|07_bag_row_untouchedtrue" "$(echo "$out" | grep '^CHECK|07_')"
check "bag_in_progress_qty5" "CHECK|08_bag_in_progress_qty5true" "$(echo "$out" | grep '^CHECK|08_')"
check "bag_item_single_linked" "CHECK|09_bag_item_single_linkedtrue" "$(echo "$out" | grep '^CHECK|09_')"
check "chip_base_cancelled" "CHECK|10_chip_base_cancelledtrue" "$(echo "$out" | grep '^CHECK|10_')"
check "additional_untouched" "CHECK|11_additional_untouchedtrue" "$(echo "$out" | grep '^CHECK|11_')"
check "pebete_updated_in_place" "CHECK|12_pebete_updated_in_placetrue" "$(echo "$out" | grep '^CHECK|12_')"
check "hamburguesa_created" "CHECK|13_hamburguesa_createdtrue" "$(echo "$out" | grep '^CHECK|13_')"
check "item_count_three" "CHECK|14_item_count_three3" "$(echo "$out" | grep '^CHECK|14_')"
check "base_total_four" "CHECK|15_base_total_four4" "$(echo "$out" | grep '^CHECK|15_')"
check "no_orphan_pending_base" "CHECK|16_no_orphan_pending_base0" "$(echo "$out" | grep '^CHECK|16_')"
check "still_confirmed" "CHECK|17_still_confirmedtrue" "$(echo "$out" | grep '^CHECK|17_')"
check "base_total_still_four" "CHECK|18_base_total_still_four4" "$(echo "$out" | grep '^CHECK|18_')"
check "bag_row_still_untouched" "CHECK|19_bag_row_still_untouchedtrue" "$(echo "$out" | grep '^CHECK|19_')"
check "chip_still_cancelled" "CHECK|20_chip_still_cancelled0" "$(echo "$out" | grep '^CHECK|20_')"

# RPC jsonb counters in the flow (4 jsonb lines: choose B', confirm,
# choose C', re-confirm).
draft_create_created=$(echo "$out" | grep -o '"requests_created": *[0-9]*' | sed -n '1p')
confirm_created=$(echo "$out" | grep -o '"requests_created": *[0-9]*' | sed -n '2p')
change_created=$(echo "$out" | grep -o '"requests_created": *[0-9]*' | sed -n '3p')
change_cancelled=$(echo "$out" | grep -o '"requests_cancelled": *[0-9]*' | sed -n '3p')
change_preserved=$(echo "$out" | grep -o '"requests_preserved": *[0-9]*' | sed -n '3p')
reconfirm_created=$(echo "$out" | grep -o '"requests_created": *[0-9]*' | sed -n '4p')
check "json_draft_create_creates_none" '"requests_created": 0' "$draft_create_created"
check "json_confirm_creates_three" '"requests_created": 3' "$confirm_created"
check "json_change_creates_one" '"requests_created": 1' "$change_created"
check "json_change_cancels_one" '"requests_cancelled": 1' "$change_cancelled"
check "json_change_preserves_one" '"requests_preserved": 1' "$change_preserved"
check "json_reconfirm_creates_none" '"requests_created": 0' "$reconfirm_created"

# ---- positive flow (supervisor), one transaction, rolled back at the end ----
sup_sql="
insert into public.production_days (production_date, status, opened_at, opened_by)
  values (public.get_business_date(), 'open', now(), '$SUPERVISOR')
  on conflict (production_date) do nothing;
$(jset $SUPERVISOR)
$fixture_sql
select public.choose_daily_production_suggestion($DAY_ID, (select sug_b from _v613));
select public.confirm_daily_production();
select public.choose_daily_production_suggestion($DAY_ID, (select sug_c from _v613));
select 'CHECK|21_sup_selection_draft_c' || (select (status = 'draft' and suggestion_id = (select sug_c from _v613)) from public.daily_production_selections where production_day_id = $DAY_ID);
select 'CHECK|22_sup_base_total_four' || (select count(*) from public.production_requests r where r.production_day_id = $DAY_ID and r.source_type = 'base');
select 'CHECK|23_sup_hamburguesa_pending' || (select count(*) from public.production_requests r where r.production_day_id = $DAY_ID and r.source_type = 'base' and r.product_id = $HAMBURGUESA and r.status = 'pending');
select 'CHECK|24_sup_chip_base_cancelled' || (select not exists (select 1 from public.production_requests r where r.production_day_id = $DAY_ID and r.source_type = 'base' and r.product_id = $CHIP and r.status <> 'cancelled'));
"
out2=$(run "$sup_sql")
check "sup_selection_draft_c" "CHECK|21_sup_selection_draft_ctrue" "$(echo "$out2" | grep '^CHECK|21_')"
check "sup_base_total_four" "CHECK|22_sup_base_total_four4" "$(echo "$out2" | grep '^CHECK|22_')"
check "sup_hamburguesa_pending" "CHECK|23_sup_hamburguesa_pending1" "$(echo "$out2" | grep '^CHECK|23_')"
check "sup_chip_base_cancelled" "CHECK|24_sup_chip_base_cancelledtrue" "$(echo "$out2" | grep '^CHECK|24_')"
check "sup_no_errors" "yes" "$(echo "$out2" | grep -q 'ERROR' && echo no || echo yes)"

exit $FAIL

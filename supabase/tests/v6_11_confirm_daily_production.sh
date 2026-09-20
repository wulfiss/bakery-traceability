#!/usr/bin/env bash
# V6.11 (spec §60) behavior tests for confirm_daily_production.
#
# The repository has no DB-test framework (vitest unit tests only), so these
# focused database tests follow the established V6 pattern: each negative
# case runs in its own aborted transaction; the positive flows run in
# transactions that are rolled back at the end. Nothing persists.
#
# Coverage (spec §60):
#   * authentication/profile gates;
#   * no selection for the current business day;
#   * selected items get pending base requests (created OR linked to old
#     base-generator leftovers), quantity/unit synced to the suggestion;
#   * unchecked items leave no active pending base production (linked
#     pending base is cancelled; old unlinked pending base is cancelled);
#   * in_progress/completed linked requests are preserved;
#   * additional requests are untouched (a new base request is still created
#     for the selected item);
#   * old products no longer selected are cancelled (history-safe
#     status = 'cancelled', never physically deleted);
#   * selection is confirmed with confirmed_by/confirmed_at;
#   * re-confirming is idempotent (no duplicate requests).
#
# Usage: bash supabase/tests/v6_11_confirm_daily_production.sh
set -u
DB=supabase_db_bakery-traceability
OPERATOR=9ba5032b-93bb-40fa-b665-a45a8c11aff1
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

# The current business day's weekday needs an active 'A' suggestion to snapshot.
SUG_TODAY=$(docker exec -i "$DB" psql -U postgres -d postgres -t -A -c \
  "select id from public.production_suggestions where active and code = 'A' and weekday = extract(isodow from public.get_business_date())::smallint;")
if [ -z "$SUG_TODAY" ]; then
  echo "SKIP  no active 'A' suggestion for the current business weekday; run on another day"
  exit 0
fi

# Item n (0-based) of the current day's selection.
item() {
  echo "(select id from public.daily_production_selection_items where daily_selection_id = (select id from public.daily_production_selections where production_day_id = (select id from public.production_days where production_date = public.get_business_date())) order by sort_order, id offset $1 limit 1)"
}

# A selected item that has NO duplicate (product, shift) partner in the same
# selection, and is not one of items 0-3 (used by other fixtures). Its old
# pending base cannot be absorbed by a selected partner, so confirm must
# cancel it (a partner-bearing item would be absorbed instead, which is a
# different, data-dependent path).
item_unique() {
  echo "(select i.id from public.daily_production_selection_items i where i.daily_selection_id = (select id from public.daily_production_selections where production_day_id = (select id from public.production_days where production_date = public.get_business_date())) and not exists (select 1 from public.daily_production_selection_items i2 where i2.daily_selection_id = i.daily_selection_id and i2.product_id = i.product_id and i2.shift_code = i.shift_code and i2.id <> i.id) and i.id not in ($(item 0), $(item 1), $(item 2), $(item 3)) order by i.sort_order, i.id limit 1)"
}

DAY_ID="(select id from public.production_days where production_date = public.get_business_date())"

# An "old product" no longer selected: not in the day's suggestion. Stable
# before and after confirm (the RPC never creates requests for it); the
# checks scope to created_by = operator, so committed rows never interfere.
OLD_PRODUCT="(select id from public.products where id not in (select product_id from public.daily_production_selection_items where daily_selection_id = (select id from public.daily_production_selections where production_day_id = $DAY_ID)) order by id limit 1)"

# Setup: current business day row + a selection from the real V6.8 RPC.
setup_today="
insert into public.production_days (production_date, status, opened_at, opened_by)
  values (public.get_business_date(), 'open', now(), '$OPERATOR')
  on conflict (production_date) do nothing;
$(jset $OPERATOR)
select public.choose_daily_production_suggestion($DAY_ID, '$SUG_TODAY');
"

# ---- negative cases (each in its own aborted transaction) ----
check "not_authenticated" \
  "not_authenticated" \
  "$(token "select public.confirm_daily_production();")"

check "no_active_profile" \
  "no_active_profile" \
  "$(token "$(jset 99999999-9999-9999-9999-999999999999) select public.confirm_daily_production();")"

# NOTE: no insufficient_role case here. profiles_role_check restricts role to
# exactly ('operator','supervisor','admin'), so no valid fixture can carry a
# disallowed role; the RPC branch is defense in depth (same as V6.8/V6.10).

check "no_selection_for_today" \
  "no_selection_for_today" \
  "$(token "$(jset $OPERATOR) delete from public.daily_production_selection_items; delete from public.daily_production_selections; select public.confirm_daily_production();")"

# ---- positive flow, one transaction, rolled back at the end ----
flow_sql="
$setup_today
-- (a) old base-generator leftover for item 0: pending base with stale qty.
insert into public.production_requests (production_day_id, source_type, shift_code, product_id, requested_quantity, unit, status, created_by)
  select $DAY_ID, 'base', i.shift_code, i.product_id, i.quantity + 7, i.unit, 'pending', '$OPERATOR'
  from public.daily_production_selection_items i where i.id = $(item 0);
-- (b) old product (not in the suggestion): pending base to be cancelled.
insert into public.production_requests (production_day_id, source_type, shift_code, product_id, requested_quantity, unit, status, created_by)
  values ($DAY_ID, 'base', 'morning', $OLD_PRODUCT, 3, 'lata', 'pending', '$OPERATOR');
-- (c) item 1 linked to an in_progress base request (must be preserved).
insert into public.production_requests (production_day_id, source_type, shift_code, product_id, requested_quantity, unit, status, created_by)
  select $DAY_ID, 'base', i.shift_code, i.product_id, 5, i.unit, 'in_progress', '$OPERATOR'
  from public.daily_production_selection_items i where i.id = $(item 1);
update public.daily_production_selection_items
  set production_request_id = (select id from public.production_requests where status = 'in_progress' and created_by = '$OPERATOR')
  where id = $(item 1);
-- (d) item 2 linked to a completed base request (must be preserved).
insert into public.production_requests (production_day_id, source_type, shift_code, product_id, requested_quantity, unit, status, created_by)
  select $DAY_ID, 'base', i.shift_code, i.product_id, 6, i.unit, 'completed', '$OPERATOR'
  from public.daily_production_selection_items i where i.id = $(item 2);
update public.daily_production_selection_items
  set production_request_id = (select id from public.production_requests where status = 'completed' and created_by = '$OPERATOR')
  where id = $(item 2);
-- (e) item 3 has an ADDITIONAL pending request for the same (product, shift);
--     it must be untouched while a new base request is created for the item.
insert into public.production_requests (production_day_id, source_type, shift_code, product_id, requested_quantity, unit, status, created_by)
  select $DAY_ID, 'additional', i.shift_code, i.product_id, 8, i.unit, 'pending', '$OPERATOR'
  from public.daily_production_selection_items i where i.id = $(item 3);
-- (f) an unchecked item (no duplicate partner) with an old pending base
--     request (must be cancelled, and no new request created for the item).
update public.daily_production_selection_items set is_selected = false where id = $(item_unique);
insert into public.production_requests (production_day_id, source_type, shift_code, product_id, requested_quantity, unit, status, created_by)
  select $DAY_ID, 'base', i.shift_code, i.product_id, 42, i.unit, 'pending', '$OPERATOR'
  from public.daily_production_selection_items i where id = $(item_unique);

-- Snapshot every request id before confirm; none may be physically deleted.
create temporary table _v611_pre_ids on commit drop as select id from public.production_requests;
select 'CHECK|15a_pre_total' || (select count(*) from _v611_pre_ids);
select public.confirm_daily_production();
select 'CHECK|15b_no_physical_deletes' || (select count(*) from _v611_pre_ids p where exists (select 1 from public.production_requests r where r.id = p.id));

select 'CHECK|01_selection_confirmed' || (select status from public.daily_production_selections where production_day_id = $DAY_ID);
select 'CHECK|02_confirmed_by_operator' || (select confirmed_by = '$OPERATOR' from public.daily_production_selections where production_day_id = $DAY_ID);
select 'CHECK|03_confirmed_at_set' || (select confirmed_at is not null from public.daily_production_selections where production_day_id = $DAY_ID);
select 'CHECK|04_item0_linked' || (select production_request_id is not null from public.daily_production_selection_items where id = $(item 0));
select 'CHECK|05_item0_request_pending_base' || (select r.status = 'pending' and r.source_type = 'base' from public.production_requests r where r.id = (select production_request_id from public.daily_production_selection_items where id = $(item 0)));
select 'CHECK|06_item0_qty_synced' || (select r.requested_quantity = i.quantity and r.unit = i.unit from public.daily_production_selection_items i join public.production_requests r on r.id = i.production_request_id where i.id = $(item 0));
select 'CHECK|07_item1_in_progress_preserved' || (select r.status = 'in_progress' from public.production_requests r where r.id = (select production_request_id from public.daily_production_selection_items where id = $(item 1)));
select 'CHECK|08_item2_completed_preserved' || (select r.status = 'completed' from public.production_requests r where r.id = (select production_request_id from public.daily_production_selection_items where id = $(item 2)));
select 'CHECK|09_item3_new_base_created' || (select r.source_type = 'base' and r.status = 'pending' and r.requested_quantity = i.quantity from public.daily_production_selection_items i join public.production_requests r on r.id = i.production_request_id where i.id = $(item 3));
select 'CHECK|10_additional_untouched' || (select count(*) from public.production_requests where source_type = 'additional' and status = 'pending' and created_by = '$OPERATOR' and production_day_id = $DAY_ID);
select 'CHECK|11_unchecked_old_cancelled' || (select ((count(*) > 0) and (count(*) filter (where status = 'cancelled') = count(*)))::text from public.production_requests where production_day_id = $DAY_ID and source_type = 'base' and created_by = '$OPERATOR' and product_id = (select product_id from public.daily_production_selection_items where id = $(item_unique)) and shift_code = (select shift_code from public.daily_production_selection_items where id = $(item_unique)));
select 'CHECK|12_unchecked_stays_unlinked' || (select production_request_id is null from public.daily_production_selection_items where id = $(item_unique));
select 'CHECK|13_old_product_cancelled' || (select ((count(*) > 0) and (count(*) filter (where status = 'cancelled') = count(*)))::text from public.production_requests where production_day_id = $DAY_ID and source_type = 'base' and created_by = '$OPERATOR' and product_id = $OLD_PRODUCT);
select 'CHECK|14_no_orphan_pending_base' || (select count(*) from public.production_requests r where r.production_day_id = $DAY_ID and r.source_type = 'base' and r.status = 'pending' and not exists (select 1 from public.daily_production_selection_items i where i.production_request_id = r.id));
"
out=$(run "$flow_sql")
check "flow_selection_confirmed"         "CHECK|01_selection_confirmedconfirmed"   "$(echo "$out" | grep '^CHECK|01_')"
check "flow_confirmed_by_operator"       "CHECK|02_confirmed_by_operatortrue"      "$(echo "$out" | grep '^CHECK|02_')"
check "flow_confirmed_at_set"            "CHECK|03_confirmed_at_settrue"           "$(echo "$out" | grep '^CHECK|03_')"
check "flow_item0_linked"                "CHECK|04_item0_linkedtrue"               "$(echo "$out" | grep '^CHECK|04_')"
check "flow_item0_request_pending_base"  "CHECK|05_item0_request_pending_basetrue" "$(echo "$out" | grep '^CHECK|05_')"
check "flow_item0_qty_synced"            "CHECK|06_item0_qty_syncedtrue"           "$(echo "$out" | grep '^CHECK|06_')"
check "flow_item1_in_progress_preserved" "CHECK|07_item1_in_progress_preservedtrue" "$(echo "$out" | grep '^CHECK|07_')"
check "flow_item2_completed_preserved"   "CHECK|08_item2_completed_preservedtrue"  "$(echo "$out" | grep '^CHECK|08_')"
check "flow_item3_new_base_created"      "CHECK|09_item3_new_base_createdtrue"     "$(echo "$out" | grep '^CHECK|09_')"
check "flow_additional_untouched"        "CHECK|10_additional_untouched1"          "$(echo "$out" | grep '^CHECK|10_')"
check "flow_unchecked_old_cancelled"     "CHECK|11_unchecked_old_cancelledtrue"    "$(echo "$out" | grep '^CHECK|11_')"
check "flow_unchecked_stays_unlinked"    "CHECK|12_unchecked_stays_unlinkedtrue"   "$(echo "$out" | grep '^CHECK|12_')"
check "flow_old_product_cancelled"       "CHECK|13_old_product_cancelledtrue"      "$(echo "$out" | grep '^CHECK|13_')"
check "flow_no_orphan_pending_base"      "CHECK|14_no_orphan_pending_base0"        "$(echo "$out" | grep '^CHECK|14_')"
# No physical deletes: all 14 request ids present before confirm (8 pre-
# existing + 6 fixtures) still exist after (cancelled rows included).
check "flow_pre_total"                   "CHECK|15a_pre_total14"                   "$(echo "$out" | grep '^CHECK|15a_')"
check "flow_no_physical_deletes"         "CHECK|15b_no_physical_deletes14"         "$(echo "$out" | grep '^CHECK|15b_')"
# jsonb text output renders as "key": "value" (space after the colon).
check "flow_json_status_confirmed"       "yes" \
  "$(echo "$out" | grep -q '"status": *"confirmed"' && echo yes || echo no)"

# ---- idempotent re-confirm, one transaction, rolled back at the end ----
reconfirm_sql="
$setup_today
select public.confirm_daily_production();
select public.confirm_daily_production();
select 'CHECK|20_reconfirm_no_duplicates' || (
  (select count(*) from public.production_requests r where r.production_day_id = $DAY_ID and r.source_type = 'base') =
  (select count(*) from public.daily_production_selection_items i where i.daily_selection_id = (select id from public.daily_production_selections where production_day_id = $DAY_ID) and i.is_selected)
);
select 'CHECK|21_still_confirmed' || (select status from public.daily_production_selections where production_day_id = $DAY_ID);
"
out2=$(run "$reconfirm_sql")
check "reconfirm_no_duplicates" "CHECK|20_reconfirm_no_duplicatestrue" "$(echo "$out2" | grep '^CHECK|20_')"
check "reconfirm_still_confirmed" "CHECK|21_still_confirmedconfirmed" "$(echo "$out2" | grep '^CHECK|21_')"
check "reconfirm_no_errors" "yes" \
  "$(echo "$out2" | grep -q 'ERROR' && echo no || echo yes)"

exit $FAIL

#!/usr/bin/env bash
# V6.10 (spec §59) behavior tests for toggle_daily_selection_item.
#
# The repository has no DB-test framework (vitest unit tests only), so these
# focused database tests follow the established V6 pattern: each negative
# case runs in its own aborted transaction; the positive flow runs in one
# transaction that is rolled back at the end. Nothing persists.
#
# Usage: bash supabase/tests/v6_10_toggle_daily_selection_item.sh
set -u
DB=supabase_db_bakery-traceability
ADMIN=8a271366-4b41-4d2f-813c-4d553c83b968
OPERATOR=9ba5032b-93bb-40fa-b665-a45a8c11aff1
SUPERVISOR=be18bd95-e3e4-488d-ab33-820ef8ad86d0
PRODUCT=ddf2c5c2-7ab6-4532-93b9-824d84ab59c2
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

# Item n (1-based) of the current day's selection.
item() {
  echo "(select id from public.daily_production_selection_items where daily_selection_id = (select id from public.daily_production_selections where production_day_id = (select id from public.production_days where production_date = public.get_business_date())) order by sort_order, id offset $1 limit 1)"
}

# Setup: current business day row + a selection from the real V6.8 RPC.
setup_today="
insert into public.production_days (production_date, status, opened_at, opened_by)
  values (public.get_business_date(), 'open', now(), '$OPERATOR')
  on conflict (production_date) do nothing;
$(jset $OPERATOR)
select public.choose_daily_production_suggestion((select id from public.production_days where production_date = public.get_business_date()), '$SUG_TODAY');
"

# ---- negative cases (each in its own aborted transaction) ----
check "not_authenticated" \
  "not_authenticated" \
  "$(token "select public.toggle_daily_selection_item('11111111-2222-3333-4444-555555555555');")"

check "no_active_profile" \
  "no_active_profile" \
  "$(token "$(jset 99999999-9999-9999-9999-999999999999) select public.toggle_daily_selection_item('11111111-2222-3333-4444-555555555555');")"

# NOTE: no insufficient_role case here. profiles_role_check restricts role to
# exactly ('operator','supervisor','admin'), so no valid fixture can carry a
# disallowed role; the RPC branch is defense in depth (same as V6.8's suite).

check "item_not_found" \
  "item_not_found" \
  "$(token "$(jset $OPERATOR) select public.toggle_daily_selection_item('11111111-2222-3333-4444-555555555555');")"

check "not_current_production_day" \
  "not_current_production_day" \
  "$(token "$(jset $OPERATOR) insert into public.production_days (production_date, status, opened_at, opened_by) values (date '2026-10-05', 'open', now(), '$OPERATOR'); select public.choose_daily_production_suggestion((select id from public.production_days where production_date = date '2026-10-05'), '13607106-210a-410f-8ae4-93946e8675b0'); select public.toggle_daily_selection_item((select id from public.daily_production_selection_items where daily_selection_id = (select id from public.daily_production_selections where production_day_id = (select id from public.production_days where production_date = date '2026-10-05')) order by sort_order, id limit 1));")"

# Locked items: linked to an in_progress / completed request.
for status in in_progress completed; do
  check "item_locked_$status" \
    "item_locked" \
    "$(token "$setup_today insert into public.production_requests (production_day_id, source_type, shift_code, product_id, requested_quantity, unit, reason_code, status, created_by) values ((select id from public.production_days where production_date = public.get_business_date()), 'additional', 'morning', '$PRODUCT', 1, 'lata', 'replenishment', '$status', '$OPERATOR'); update public.daily_production_selection_items set production_request_id = (select id from public.production_requests where status = '$status' and created_by = '$OPERATOR') where id = $(item 0); select public.toggle_daily_selection_item($(item 0));")"
done

# A locked item stays locked even when the selection is confirmed.
check "item_locked_wins_over_confirmed" \
  "item_locked" \
  "$(token "$setup_today update public.daily_production_selections set status = 'confirmed', confirmed_by = '$OPERATOR', confirmed_at = now() where production_day_id = (select id from public.production_days where production_date = public.get_business_date()); insert into public.production_requests (production_day_id, source_type, shift_code, product_id, requested_quantity, unit, reason_code, status, created_by) values ((select id from public.production_days where production_date = public.get_business_date()), 'additional', 'morning', '$PRODUCT', 1, 'lata', 'replenishment', 'in_progress', '$OPERATOR'); update public.daily_production_selection_items set production_request_id = (select id from public.production_requests where status = 'in_progress' and created_by = '$OPERATOR') where id = $(item 0); select public.toggle_daily_selection_item($(item 0));")"

# RLS: an authenticated user cannot write the items table directly (no DML
# policies exist; the RPC is the only write path). A real item must exist so
# the UPDATE has a row the SELECT policy makes visible: with no UPDATE policy
# the statement is a silent no-op (UPDATE 0) and the row keeps its value; a
# direct INSERT is rejected outright.
rls_out=$(run "$setup_today set role authenticated; with u as (update public.daily_production_selection_items set is_selected = false where id = $(item 0) returning 1) select 'CHECK|rls_updated_rows' || (select count(*) from u); select 'CHECK|rls_row_unchanged' || (select is_selected::text from public.daily_production_selection_items where id = $(item 0));")
check "rls_update_is_noop" \
  "CHECK|rls_updated_rows0" \
  "$(echo "$rls_out" | grep '^CHECK|rls_updated_rows')"
check "rls_row_unchanged_after_update" \
  "CHECK|rls_row_unchangedtrue" \
  "$(echo "$rls_out" | grep '^CHECK|rls_row_unchanged')"

rls_ins_out=$(run "$setup_today set role authenticated; insert into public.daily_production_selection_items (daily_selection_id, product_id, shift_code, quantity, unit) values ((select id from public.daily_production_selections where production_day_id = (select id from public.production_days where production_date = public.get_business_date())), '$PRODUCT', 'morning', 1, 'lata');")
check "rls_insert_rejected" \
  "yes" \
  "$(echo "$rls_ins_out" | grep -q 'violates row-level security policy' && echo yes || echo no)"

# ---- positive flow, one transaction, rolled back at the end ----
flow_sql="
$setup_today
select public.toggle_daily_selection_item($(item 0));
select 'CHECK|01_operator_uncheck' || (select is_selected::text from public.daily_production_selection_items where id = $(item 0));
select 'CHECK|02_status_draft' || (select status from public.daily_production_selections where production_day_id = (select id from public.production_days where production_date = public.get_business_date()));
select 'CHECK|03_updated_by_operator' || (select updated_by = '$OPERATOR' from public.daily_production_selections where production_day_id = (select id from public.production_days where production_date = public.get_business_date()));
select public.toggle_daily_selection_item($(item 0));
select 'CHECK|04_operator_recheck' || (select is_selected::text from public.daily_production_selection_items where id = $(item 0));
$(jset $SUPERVISOR)
select public.toggle_daily_selection_item($(item 1));
select 'CHECK|05_supervisor_uncheck' || (select is_selected::text from public.daily_production_selection_items where id = $(item 1));
update public.daily_production_selections set status = 'confirmed', confirmed_by = '$SUPERVISOR', confirmed_at = now() where production_day_id = (select id from public.production_days where production_date = public.get_business_date());
$(jset $ADMIN)
select public.toggle_daily_selection_item($(item 2));
select 'CHECK|06_confirmed_back_to_draft' || (select status from public.daily_production_selections where production_day_id = (select id from public.production_days where production_date = public.get_business_date()));
select 'CHECK|07_confirmation_stamp_reset' || (select confirmed_by is null from public.daily_production_selections where production_day_id = (select id from public.production_days where production_date = public.get_business_date()));
select 'CHECK|08_admin_uncheck' || (select is_selected::text from public.daily_production_selection_items where id = $(item 2));
insert into public.production_requests (production_day_id, source_type, shift_code, product_id, requested_quantity, unit, reason_code, status, created_by)
  values ((select id from public.production_days where production_date = public.get_business_date()), 'additional', 'morning', '$PRODUCT', 1, 'lata', 'replenishment', 'pending', '$OPERATOR');
update public.daily_production_selection_items set production_request_id = (select id from public.production_requests where status = 'pending' and created_by = '$OPERATOR') where id = $(item 1);
select public.toggle_daily_selection_item($(item 1));
select 'CHECK|09_pending_linked_not_locked' || (select is_selected::text from public.daily_production_selection_items where id = $(item 1));
select 'CHECK|10_request_untouched' || (select count(*) from public.production_requests where status = 'pending' and created_by = '$OPERATOR');
"
out=$(run "$flow_sql")
check "flow_operator_uncheck"            "CHECK|01_operator_uncheckfalse" "$(echo "$out" | grep '^CHECK|01_')"
check "flow_status_stays_draft"          "CHECK|02_status_draftdraft"     "$(echo "$out" | grep '^CHECK|02_')"
check "flow_selection_updated_by"        "CHECK|03_updated_by_operatortrue" "$(echo "$out" | grep '^CHECK|03_')"
check "flow_operator_recheck"            "CHECK|04_operator_rechecktrue"  "$(echo "$out" | grep '^CHECK|04_')"
check "flow_supervisor_uncheck"          "CHECK|05_supervisor_uncheckfalse" "$(echo "$out" | grep '^CHECK|05_')"
check "flow_confirmed_returns_to_draft"  "CHECK|06_confirmed_back_to_draftdraft" "$(echo "$out" | grep '^CHECK|06_')"
check "flow_confirmation_stamp_reset"    "CHECK|07_confirmation_stamp_resettrue" "$(echo "$out" | grep '^CHECK|07_')"
check "flow_admin_uncheck"               "CHECK|08_admin_uncheckfalse"    "$(echo "$out" | grep '^CHECK|08_')"
check "flow_pending_linked_toggles"      "CHECK|09_pending_linked_not_lockedtrue" "$(echo "$out" | grep '^CHECK|09_')"
check "flow_request_row_untouched"       "CHECK|10_request_untouched1"    "$(echo "$out" | grep '^CHECK|10_')"

exit $FAIL

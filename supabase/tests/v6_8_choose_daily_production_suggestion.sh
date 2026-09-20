#!/usr/bin/env bash
# V6.8 (spec §57) behavior tests for choose_daily_production_suggestion.
#
# The repository has no DB-test framework (vitest unit tests only), so these
# focused database tests follow the established V6 pattern: each negative
# case runs in its own aborted transaction; the positive flow runs in one
# transaction that is rolled back at the end. Nothing persists.
#
# Usage: bash supabase/tests/v6_8_choose_daily_production_suggestion.sh
set -u
DB=supabase_db_bakery-traceability
ADMIN=8a271366-4b41-4d2f-813c-4d553c83b968
OPERATOR=9ba5032b-93bb-40fa-b665-a45a8c11aff1
SUPERVISOR=be18bd95-e3e4-488d-ab33-820ef8ad86d0
SUG_1A=13607106-210a-410f-8ae4-93946e8675b0 # LUNES A (9 items)
SUG_1B=8143e74c-80cd-49ad-ba13-9f99ecda9fa6 # LUNES B (9 items)
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

# A Tuesday (weekday 2) suggestion for the weekday_mismatch case.
SUG_2A=$(docker exec -i "$DB" psql -U postgres -d postgres -t -A -c \
  "select id from public.production_suggestions where weekday=2 and code='A' and active;")

# ---- negative cases (each in its own aborted transaction) ----
check "not_authenticated" \
  "not_authenticated" \
  "$(token "select public.choose_daily_production_suggestion('11111111-2222-3333-4444-555555555555', '$SUG_1A');")"

check "no_active_profile" \
  "no_active_profile" \
  "$(token "$(jset 99999999-9999-9999-9999-999999999999) select public.choose_daily_production_suggestion('11111111-2222-3333-4444-555555555555', '$SUG_1A');")"

check "production_day_not_found" \
  "production_day_not_found" \
  "$(token "$(jset $OPERATOR) select public.choose_daily_production_suggestion('11111111-2222-3333-4444-555555555555', '$SUG_1A');")"

check "suggestion_not_found" \
  "suggestion_not_found" \
  "$(token "$(jset $OPERATOR) insert into public.production_days (production_date, status, opened_at, opened_by) values (date '2026-10-05', 'open', now(), '$OPERATOR'); select public.choose_daily_production_suggestion((select id from public.production_days where production_date = date '2026-10-05'), '11111111-2222-3333-4444-555555555555');")"

check "inactive_suggestion_not_found" \
  "suggestion_not_found" \
  "$(token "$(jset $OPERATOR) insert into public.production_days (production_date, status, opened_at, opened_by) values (date '2026-10-05', 'open', now(), '$OPERATOR'); insert into public.production_suggestions (weekday, code, active) values (1, 'A', false); select public.choose_daily_production_suggestion((select id from public.production_days where production_date = date '2026-10-05'), (select id from public.production_suggestions where active = false));")"

check "weekday_mismatch" \
  "weekday_mismatch" \
  "$(token "$(jset $OPERATOR) insert into public.production_days (production_date, status, opened_at, opened_by) values (date '2026-10-05', 'open', now(), '$OPERATOR'); select public.choose_daily_production_suggestion((select id from public.production_days where production_date = date '2026-10-05'), '$SUG_2A');")"

# ---- positive flow, one transaction, rolled back at the end ----
flow_sql="
insert into public.production_days (production_date, status, opened_at, opened_by) values (date '2026-10-05', 'open', now(), '$OPERATOR');
$(jset $OPERATOR)
select public.choose_daily_production_suggestion((select id from public.production_days where production_date = date '2026-10-05'), '$SUG_1A');
select public.choose_daily_production_suggestion((select id from public.production_days where production_date = date '2026-10-05'), '$SUG_1A');
select public.choose_daily_production_suggestion((select id from public.production_days where production_date = date '2026-10-05'), '$SUG_1B');
insert into public.production_requests (production_day_id, source_type, shift_code, product_id, requested_quantity, unit, reason_code, status, created_by)
  values ((select id from public.production_days where production_date = date '2026-10-05'), 'additional', 'morning', '$PRODUCT', 1, 'lata', 'replenishment', 'pending', '$OPERATOR');
update public.daily_production_selection_items
  set production_request_id = (select id from public.production_requests where source_type = 'additional' and created_by = '$OPERATOR')
  where daily_selection_id = (select id from public.daily_production_selections where production_day_id = (select id from public.production_days where production_date = date '2026-10-05'))
    and production_request_id is null
  and sort_order <= 2;
select public.choose_daily_production_suggestion((select id from public.production_days where production_date = date '2026-10-05'), '$SUG_1A');
select 'CHECK|' || (select count(*) from public.daily_production_selections where production_day_id = (select id from public.production_days where production_date = date '2026-10-05'));
select 'CHECK|' || (select count(*) from public.daily_production_selection_items where daily_selection_id = (select id from public.daily_production_selections where production_day_id = (select id from public.production_days where production_date = date '2026-10-05')));
select 'CHECK|' || (select count(*) from public.daily_production_selection_items where daily_selection_id = (select id from public.daily_production_selections where production_day_id = (select id from public.production_days where production_date = date '2026-10-05')) and production_request_id is not null);
select 'CHECK|' || (select count(*) from public.daily_production_selection_items i join public.production_suggestion_items m on m.id = i.source_suggestion_item_id join public.production_suggestions s on s.id = m.suggestion_id where i.daily_selection_id = (select id from public.daily_production_selections where production_day_id = (select id from public.production_days where production_date = date '2026-10-05')) and s.code = 'A' and i.production_request_id is null and not (i.sort_order between 1 and 9) );
"
flow_out=$(docker exec -i "$DB" psql -U postgres -d postgres -q -t -A -v ON_ERROR_STOP=1 -c "begin; $flow_sql rollback;" 2>&1)
if echo "$flow_out" | grep -q "^ERROR"; then
  echo "FAIL  positive_flow: transaction aborted"
  echo "$flow_out" | grep -m1 "^ERROR"
  FAIL=1
else
  json1=$(echo "$flow_out" | sed -n '1p')
  json2=$(echo "$flow_out" | sed -n '2p')
  json3=$(echo "$flow_out" | sed -n '3p')
  json4=$(echo "$flow_out" | sed -n '4p')
  # step 1: create (operator) — draft, changed, 9 snapshot, 0 preserved/removed
  check "flow.create.status"      "draft"                "$(echo "$json1" | sed -n 's/.*"status": "\([a-z]*\)".*/\1/p')"
  check "flow.create.changed"     "true"                 "$(echo "$json1" | sed -n 's/.*"changed_suggestion": \(true\|false\).*/\1/p')"
  check "flow.create.snapshot"    "9"                    "$(echo "$json1" | sed -n 's/.*"items_snapshot": \([0-9]*\).*/\1/p')"
  check "flow.create.preserved"   "0"                    "$(echo "$json1" | sed -n 's/.*"items_preserved": \([0-9]*\).*/\1/p')"
  check "flow.create.removed"     "0"                    "$(echo "$json1" | sed -n 's/.*"items_removed": \([0-9]*\).*/\1/p')"
  # step 2: same suggestion — unchanged, 9 replaced by fresh snapshot
  check "flow.resame.changed"     "false"                "$(echo "$json2" | sed -n 's/.*"changed_suggestion": \(true\|false\).*/\1/p')"
  check "flow.resame.removed"     "9"                    "$(echo "$json2" | sed -n 's/.*"items_removed": \([0-9]*\).*/\1/p')"
  check "flow.resame.snapshot"    "9"                    "$(echo "$json2" | sed -n 's/.*"items_snapshot": \([0-9]*\).*/\1/p')"
  # step 3: change A -> B
  check "flow.change.changed"     "true"                 "$(echo "$json3" | sed -n 's/.*"changed_suggestion": \(true\|false\).*/\1/p')"
  check "flow.change.snapshot"    "9"                    "$(echo "$json3" | sed -n 's/.*"items_snapshot": \([0-9]*\).*/\1/p')"
  # step 4: two items linked to a request, change B -> A — 2 preserved, 7 removed
  check "flow.preserve.preserved" "2"                    "$(echo "$json4" | sed -n 's/.*"items_preserved": \([0-9]*\).*/\1/p')"
  check "flow.preserve.removed"   "7"                    "$(echo "$json4" | sed -n 's/.*"items_removed": \([0-9]*\).*/\1/p')"
  check "flow.preserve.snapshot"  "9"                    "$(echo "$json4" | sed -n 's/.*"items_snapshot": \([0-9]*\).*/\1/p')"
  check "flow.on_selection"       "CHECK|1"              "$(echo "$flow_out" | grep '^CHECK|' | sed -n '1p')"
  check "flow.total_items_11"     "CHECK|11"             "$(echo "$flow_out" | grep '^CHECK|' | sed -n '2p')"
  check "flow.linked_kept"        "CHECK|2"              "$(echo "$flow_out" | grep '^CHECK|' | sed -n '3p')"
  check "flow.new_items_sorted"   "CHECK|0"              "$(echo "$flow_out" | grep '^CHECK|' | sed -n '4p')"
fi

# ---- roles: supervisor and admin can choose (separate days, rolled back) ----
check "role_supervisor" "draft" \
  "$(run "$(jset $SUPERVISOR) insert into public.production_days (production_date, status, opened_at, opened_by) values (date '2026-10-12', 'open', now(), '$SUPERVISOR'); select (public.choose_daily_production_suggestion((select id from public.production_days where production_date = date '2026-10-12'), '$SUG_1A'))::text;" | sed -n 's/.*"status": "\([a-z]*\)".*/\1/p')"
check "role_admin" "draft" \
  "$(run "$(jset $ADMIN) insert into public.production_days (production_date, status, opened_at, opened_by) values (date '2026-10-19', 'open', now(), '$ADMIN'); select (public.choose_daily_production_suggestion((select id from public.production_days where production_date = date '2026-10-19'), '$SUG_1A'))::text;" | sed -n 's/.*"status": "\([a-z]*\)".*/\1/p')"

# ---- nothing persisted ----
leftover=$(docker exec -i "$DB" psql -U postgres -d postgres -t -A -c \
  "select (select count(*) from public.production_days where production_date in (date '2026-10-05', date '2026-10-12', date '2026-10-19')) || '|' || (select count(*) from public.daily_production_selections where production_day_id in (select id from public.production_days where production_date in (date '2026-10-05', date '2026-10-12', date '2026-10-19')));")
check "nothing_persisted" "0|0" "$leftover"

echo
if [ "$FAIL" -eq 0 ]; then
  echo "ALL V6.8 BEHAVIOR TESTS PASSED"
else
  echo "V6.8 BEHAVIOR TESTS FAILED"
  exit 1
fi

#!/usr/bin/env bash
# V6.16 — Sunday partial acceptance evidence (V6 STEP 16, doc §65).
#
# The bakery has no production on Sundays (doc §5: no Sunday suggestion is
# invented), and the suggestion pages are pinned to the current business day
# via ensure_production_day. So the page-driven live flow (TEST 2-10 and the
# TEST 15 batch parts) cannot run when the business day is Sunday. This
# runner executes the parts of the acceptance that are independent of the
# business day, with the same PASS/FAIL discipline as
# v6_16_acceptance_tests.sh:
#
#   TEST 1  template availability per weekday (static) + the live Sunday
#           empty state on the suggestion screen
#   TEST 9  fixture phase: real choose -> confirm -> start -> change RPCs
#           inside a rolled-back transaction (TEST 7-9 quantity semantics,
#           zero residue)
#   TEST 11 admin access cards + operator role guard (live SSR)
#   TEST 12 auth tokens, RLS write blocks, silent-update no-op (the
#           authorized RPC path is proven by the TEST 9 fixture)
#   TEST 13 Saturday PARA LA TARDE rows never silently imported (CSV + DB)
#   TEST 14 history byte-identical before and after the fixture
#   TEST 15 V5 regression parts that need no live flow (login, shift,
#           material lot addition + coexistence, traceability)
#
# Deferred to the full suite on a Monday-Saturday business day: TEST 2-8,
# TEST 9 (live), TEST 10, TEST 12 (live authorized path) and the TEST 15
# batch/additional checks that depend on the live flow.
#
# Safe to run any day (all writes are rolled back or use the V616-TEST-LOT
# cleanup), but intended for the Sunday gap.
#
# Usage: bash supabase/tests/v6_16_acceptance_sunday_partial.sh
set -u
BASE=http://localhost:5173
DB=supabase_db_bakery-traceability
OPERATOR_EMAIL=operator@test.local
OPERATOR_PASSWORD=operator123
ADMIN_EMAIL=admin@test.local
ADMIN_PASSWORD=admin123
OPERATOR=9ba5032b-93bb-40fa-b665-a45a8c11aff1
ADMIN=8a271366-4b41-4d2f-813c-4d553c83b968
FAIL=0
declare -A FAILS=()

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK=$(mktemp -d)
DAY=""

# ---------------------------------------------------------------- helpers

# sql <query> -> autocommit read (prints rows, -t -A).
sql() {
  docker exec -i "$DB" psql -U postgres -d postgres -q -t -A -c "$1" 2>&1
}

# run <sql...> -> inside begin/...rollback (prints psql output incl. errors).
run() {
  docker exec -i "$DB" psql -U postgres -d postgres -q -t -A -c "begin; $1 rollback;" 2>&1
}

# jset <uuid> -> DO block setting request.jwt.claims for the current txn.
jset() {
  echo "do \$d\$ begin perform set_config('request.jwt.claims', '{\"sub\": \"$1\"}', false); end \$d\$;"
}

# err <sql...> -> full first error line (text after 'ERROR: ').
err() {
  run "$1" | grep '^ERROR' | head -1 | sed 's/^ERROR:  //'
}

# token <sql...> -> raised error token (or empty on success), inside a
# rolled-back transaction (negative tests: no write may persist).
token() {
  run "$1" | grep -oE 'ERROR:  [a-z_]+' | head -1 | sed 's/ERROR:  //'
}

# ck <test> <desc> <expected> <actual>
ck() {
  if [ "$3" = "$4" ]; then
    echo "PASS [$1] $2"
  else
    echo "FAIL [$1] $2: expected [$3] got [$4]"
    FAILS["$1"]=1
    FAIL=1
  fi
}

# contains_ck <test> <desc> <needle> <file>
contains_ck() {
  if grep -qF "$3" "$4"; then
    echo "PASS [$1] $2"
  else
    echo "FAIL [$1] $2 (missing: $3)"
    FAILS["$1"]=1
    FAIL=1
  fi
}

# status_and_location: headers on stdin -> "STATUS|LOCATION".
status_and_location() {
  tr -d '\r' | awk '
    $0 ~ /^HTTP/ {split($0, a, " "); status=a[2]; next}
    {n=index($0, ": "); if (n > 0) {
        key=tolower(substr($0, 1, n-1)); val=substr($0, n+2);
        if (key=="location") loc=val
    }}
    END {print status "|" loc}'
}

# get <jar> <path> <outfile> -> prints the HTTP status.
get() {
  curl -s -b "$1" -o "$3" -w '%{http_code}' "$BASE$2"
}

# get_resp <jar> <path> -> prints "STATUS|LOCATION" (body discarded).
get_resp() {
  curl -s -b "$1" -D - -o /dev/null "$BASE$2" | status_and_location
}

# login <email> <password> <jar>
login() {
  local status
  curl -s -c "$3" -X POST "$BASE/" \
    --data-urlencode "email=$1" \
    --data-urlencode "password=$2" \
    -o /dev/null
  status=$(curl -s -b "$3" -o /dev/null -w '%{http_code}' "$BASE/production")
  ck T15 "login $1 reaches /production" "200" "$status"
}

# set_shift_cookie <jar> <shift>
set_shift_cookie() {
  printf 'localhost\tFALSE\t/\tFALSE\t0\tbakery_shift\t%s\n' "$2" >> "$1"
}

# Wipe everything the suite can create for one business day, child-first, in
# one committed transaction (test environment only). Identical to the full
# suite's wipe_day: every FK involved is ON DELETE RESTRICT, so the order
# matters (selection items before requests, requests before days).
wipe_day() {
  local d="$1"
  [ -n "$d" ] || return 0
  docker exec -i "$DB" psql -U postgres -d postgres -q -c "
    begin;
    delete from parent_batch_inputs where child_batch_id in (select id from production_batches where production_day_id = '$d');
    delete from batch_outputs where batch_id in (select id from production_batches where production_day_id = '$d');
    delete from batch_requests where batch_id in (select id from production_batches where production_day_id = '$d')
       or production_request_id in (select id from production_requests where production_day_id = '$d');
    delete from batch_materials where batch_id in (select id from production_batches where production_day_id = '$d');
    delete from daily_production_selection_items where daily_selection_id in (select id from daily_production_selections where production_day_id = '$d');
    delete from production_requests where production_day_id = '$d';
    delete from daily_production_selections where production_day_id = '$d';
    delete from production_batches where production_day_id = '$d';
    delete from external_order_items where external_order_id in (select id from external_orders where order_number = 'V616-TEST');
    delete from external_orders where order_number = 'V616-TEST';
    delete from material_lots where supplier_lot = 'V616-TEST-LOT';
    delete from production_days where id = '$d';
    commit;" 2>&1 | grep -v '^DELETE\|^BEGIN\|^COMMIT' || true
}

cleanup() {
  wipe_day "$DAY"
  rm -rf "$WORK"
}
trap cleanup EXIT

# ------------------------------------------------------------ preconditions

if ! curl -s -o /dev/null --max-time 5 "$BASE/"; then
  echo "SKIP: dev server not reachable at $BASE (start it with npm run dev first)"
  exit 0
fi

echo "== preconditions"
WEEKDAY=$(sql "select extract(isodow from get_business_date())::smallint;")
echo "business day: $(sql 'select get_business_date();') (isodow $WEEKDAY)"
if [ "$WEEKDAY" != "7" ]; then
  echo "note: not Sunday — the full suite covers everything on a weekday; this runner still works"
fi
# Make the run re-runnable: clear any residue from a previously killed run.
wipe_day "$(sql "select id from production_days where production_date = get_business_date();" | tail -1)"
BASELINE=$(sql "select (select count(*) from daily_production_selections where production_day_id = (select id from production_days where production_date = get_business_date()))
  || '|' || (select count(*) from production_requests where production_day_id = (select id from production_days where production_date = get_business_date()))
  || '|' || (select count(*) from production_batches where production_day_id = (select id from production_days where production_date = get_business_date()));")
ck pre "clean baseline (selections|requests|batches for today)" "0|0|0" "$BASELINE"

: > "$WORK/jar_fresh"
login "$OPERATOR_EMAIL" "$OPERATOR_PASSWORD" "$WORK/jar_op"
login "$ADMIN_EMAIL" "$ADMIN_PASSWORD" "$WORK/jar_adm"

# Ensure today's production day exists (idempotent RPC, authorized path).
# Autocommit: the fixture below needs the row to persist.
DAY=$(sql "$(jset $OPERATOR) select public.ensure_production_day();" | tail -1)
ck pre "ensure_production_day returns a day id" 1 "$(printf '%s' "$DAY" | grep -cE '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')"

# TEST 14 snapshots, before the fixture touches anything.
T14_SNAP_BEFORE="$WORK/t14_snap_before.txt"
T14_COMPLETED_BEFORE="$WORK/t14_completed_before.txt"
sql "select md5(string_agg(s, '' order by s)) from (
  select (row_to_json(t))::text as s from production_requests t where t.status in ('in_progress','completed')
  union all select (row_to_json(t))::text from production_batches t
  union all select (row_to_json(t))::text from batch_materials t
) u;" > "$T14_SNAP_BEFORE" 2>&1
sql "select (row_to_json(t))::text from production_batches t where status = 'completed' order by id;" > "$T14_COMPLETED_BEFORE" 2>&1

# Fixture ids (stable live rows).
BAGUETTE=$(sql "select id from products where name = 'Baguette' limit 1;")
CHIP=$(sql "select id from products where name = 'Chip' limit 1;")
PEBETE=$(sql "select id from products where name = 'Pan pebete' limit 1;")
HAMBURGUESA=$(sql "select id from products where name = 'Hamburguesa' limit 1;")
# A real template suggestion for the auth-token checks: choose() validates
# auth -> active profile -> role BEFORE day/weekday, so a Monday template is
# a valid argument even on Sunday (the mismatch would be irrelevant).
SUG_MON_A=$(sql "select id from production_suggestions where active and weekday = 1 and code = 'A' limit 1;")

# ================================================================ TEST 1
echo ""
echo "== TEST 1: suggestion availability per weekday (no Sunday suggestion)"
AVAIL=$(sql "select weekday || ':' || string_agg(code, ',' order by code) || ' (n=' || count(*) || ')'
  from production_suggestions where active group by weekday order by weekday;")
echo "$AVAIL"
W1=$(printf '%s\n' "$AVAIL" | awk -F: '$1==1 {print $2}')
W2=$(printf '%s\n' "$AVAIL" | awk -F: '$1==2 {print $2}')
W3=$(printf '%s\n' "$AVAIL" | awk -F: '$1==3 {print $2}')
W4=$(printf '%s\n' "$AVAIL" | awk -F: '$1==4 {print $2}')
W5=$(printf '%s\n' "$AVAIL" | awk -F: '$1==5 {print $2}')
W6=$(printf '%s\n' "$AVAIL" | awk -F: '$1==6 {print $2}')
W7=$(printf '%s\n' "$AVAIL" | awk -F: '$1==7 {print $2}')
ck T1 "Monday -> A,B,C,D" "A,B,C,D (n=4)" "$W1"
ck T1 "Tuesday -> A,B,C,D,E" "A,B,C,D,E (n=5)" "$W2"
ck T1 "Wednesday -> A,B,C,D" "A,B,C,D (n=4)" "$W3"
ck T1 "Thursday -> A,B,C,D" "A,B,C,D (n=4)" "$W4"
ck T1 "Friday -> A,B,C,D" "A,B,C,D (n=4)" "$W5"
ck T1 "Saturday -> A,B,C,D" "A,B,C,D (n=4)" "$W6"
ck T1 "Sunday -> no options" "" "$W7"
ck T1 "25 active template options total" "25" "$(sql "select count(*) from production_suggestions where active;")"
if [ "$WEEKDAY" = "7" ]; then
  SUG_PAGE="$WORK/t1_sunday.html"
  ck T1 "SSR /production/suggestions (Sunday) is 200" "200" "$(get "$WORK/jar_op" /production/suggestions "$SUG_PAGE")"
  contains_ck T1 "Sunday screen offers no options" 'Sin opciones de producción para este día.' "$SUG_PAGE"
fi

# ============================================== TEST 9 fixture phase
# Controlled B'/C' suggestions (Baguette 5 vs 8, Pebete 2 vs 4, Chip only in
# B', Hamburguesa only in C') in a single rolled-back transaction, running
# the REAL choose -> confirm -> start -> change RPCs. Proves TEST 9's
# quantity semantics: pending updated, started never rewritten, removed
# line cancelled, new line added. Identical to the full suite's fixture.
echo ""
echo "== TEST 9 (fixture phase, rolled-back transaction): quantity semantics"
FIXTURE="
update public.production_suggestions set active = false where weekday = $WEEKDAY and code in ('B','C') and active;
with fb as (insert into public.production_suggestions (weekday, code, active, sort_order)
  values ($WEEKDAY, 'B', true, 90) returning id),
      fc as (insert into public.production_suggestions (weekday, code, active, sort_order)
  values ($WEEKDAY, 'C', true, 91) returning id)
insert into public.production_suggestion_items (suggestion_id, product_id, shift_code, suggested_quantity, unit, sort_order, active)
values ((select id from fb), '$BAGUETTE', 'morning', 5, 'latas', 1, true),
       ((select id from fb), '$CHIP', 'morning', 3, 'latas', 2, true),
       ((select id from fb), '$PEBETE', 'morning', 2, 'latas', 3, true),
       ((select id from fc), '$BAGUETTE', 'morning', 8, 'latas', 1, true),
       ((select id from fc), '$PEBETE', 'morning', 4, 'latas', 2, true),
       ((select id from fc), '$HAMBURGUESA', 'night', 1, 'carro', 3, true);
$(jset $OPERATOR)
select public.choose_daily_production_suggestion('$DAY', (select id from production_suggestions where weekday = $WEEKDAY and code = 'B' and active));
select public.confirm_daily_production();
select public.start_production_batch(p_production_request_id := (select id from production_requests where production_day_id = '$DAY' and product_id = '$BAGUETTE' and source_type = 'base'));
select 'BAGBEFORE|' || (select row_to_json(t)::text from (select * from production_requests t where production_day_id = '$DAY' and product_id = '$BAGUETTE' and source_type = 'base') t);
select public.choose_daily_production_suggestion('$DAY', (select id from production_suggestions where weekday = $WEEKDAY and code = 'C' and active));
select 'FIX|bag_single' || (select count(*) from production_requests where production_day_id = '$DAY' and product_id = '$BAGUETTE');
select 'FIX|bag_row' || (select row_to_json(t)::text from (select * from production_requests t where production_day_id = '$DAY' and product_id = '$BAGUETTE' and source_type = 'base') t);
select 'FIX|bag_qty5_in_progress' || (select (status = 'in_progress' and requested_quantity = 5) from production_requests where production_day_id = '$DAY' and product_id = '$BAGUETTE');
select 'FIX|chip_cancelled' || (select (count(*) = 1 and bool_and(status = 'cancelled')) from production_requests where production_day_id = '$DAY' and product_id = '$CHIP');
select 'FIX|pebete_updated_4' || (select (count(*) = 1 and bool_and(status = 'pending' and requested_quantity = 4)) from production_requests where production_day_id = '$DAY' and product_id = '$PEBETE');
select 'FIX|hamburguesa_added' || (select (count(*) = 1 and bool_and(status = 'pending' and requested_quantity = 1 and unit = 'carro' and shift_code = 'night')) from production_requests where production_day_id = '$DAY' and product_id = '$HAMBURGUESA');
select 'FIX|selection_draft_c' || (select (status = 'draft' and suggestion_id = (select id from production_suggestions where weekday = $WEEKDAY and code = 'C' and active)) from daily_production_selections where production_day_id = '$DAY');
"
FIX_OUT=$(run "$FIXTURE")
# The 'BAGBEFORE|' prefix is part of the SQL string (psql -t -A drops column
# labels, so `as bag_before` would have been invisible to the parser below).
BAG_BEFORE=$(printf '%s\n' "$FIX_OUT" | sed -n 's/^BAGBEFORE|//p')
BAG_ROW=$(printf '%s\n' "$FIX_OUT" | sed -n 's/^FIX|bag_row//p')
QTY5=$(printf '%s\n' "$FIX_OUT" | sed -n 's/^FIX|bag_qty5_in_progress//p')
ck T9 "fixture: choose B' + confirm + start Baguette(5) + change to C' raised no error" 0 \
  "$(printf '%s' "$FIX_OUT" | grep -c '^ERROR')"
ck T9 "fixture: exactly one Baguette request after the change" "FIX|bag_single1" \
  "$(printf '%s\n' "$FIX_OUT" | grep '^FIX|bag_single')"
# The started row must be byte-identical before and after the change to C'
# (locked: never rewritten to 8) and must still read qty 5 in_progress.
ck T9 "fixture: started Baguette row byte-identical, qty 5 in_progress (never rewritten to 8)" "identical" \
  "$( { [ "$BAG_BEFORE" = "$BAG_ROW" ] && [ "$QTY5" = "true" ]; } && echo identical || echo differs)"
ck T9 "fixture: Chip (absent from C') cancelled history-safe" "FIX|chip_cancelledtrue" \
  "$(printf '%s\n' "$FIX_OUT" | grep '^FIX|chip_cancelled')"
ck T9 "fixture: pending Pebete updated 2 -> 4" "FIX|pebete_updated_4true" \
  "$(printf '%s\n' "$FIX_OUT" | grep '^FIX|pebete_updated_4')"
ck T9 "fixture: Hamburguesa (new in C') added pending 1 carro night" "FIX|hamburguesa_addedtrue" \
  "$(printf '%s\n' "$FIX_OUT" | grep '^FIX|hamburguesa_added')"
ck T9 "fixture: selection back to draft on C'" "FIX|selection_draft_ctrue" \
  "$(printf '%s\n' "$FIX_OUT" | grep '^FIX|selection_draft_c')"

# ================================================================ TEST 14
echo ""
echo "== TEST 14: suggestion changes never modify history (in_progress/completed)"
T14_SNAP_AFTER="$WORK/t14_snap_after.txt"
sql "select md5(string_agg(s, '' order by s)) from (
  select (row_to_json(t))::text as s from production_requests t where t.status in ('in_progress','completed')
  union all select (row_to_json(t))::text from production_batches t
  union all select (row_to_json(t))::text from batch_materials t
) u;" > "$T14_SNAP_AFTER" 2>&1
ck T14 "in_progress/completed requests + batches + batch_materials identical after the changes" \
  "$(cat "$T14_SNAP_BEFORE")" "$(cat "$T14_SNAP_AFTER")"
sql "select (row_to_json(t))::text from production_batches t where status = 'completed' order by id;" > "$WORK/t14_completed_after.txt" 2>&1
ck T14 "completed batches across all days byte-identical (no completed batch modified)" 0 \
  "$(cmp -s "$T14_COMPLETED_BEFORE" "$WORK/t14_completed_after.txt" && echo 0 || echo 1)"

# ================================================================ TEST 11
echo ""
echo "== TEST 11: admin access cards (Suggested Production, Production, Raw Materials, Traceability)"
ADM_HUB="$WORK/t11_admin.html"
ck T11 "SSR /admin (admin) is 200" "200" "$(get "$WORK/jar_adm" /admin "$ADM_HUB")"
contains_ck T11 "admin hub: Suggested Production card" 'href="./production/suggestions"' "$ADM_HUB"
contains_ck T11 "admin hub: Production card" 'href="./production"' "$ADM_HUB"
contains_ck T11 "admin hub: Raw Materials card" 'href="./lots"' "$ADM_HUB"
contains_ck T11 "admin hub: Traceability card" 'href="./admin/traceability"' "$ADM_HUB"
RESP=$(get_resp "$WORK/jar_op" /admin)
ck T11 "operator /admin still redirects to /production (role guard)" "303|/production" "$RESP"

# ================================================================ TEST 12
echo ""
echo "== TEST 12: direct writes blocked; authorized RPC works; bad identities fail"
# choose() validates auth -> active profile -> role before day/weekday, so a
# Monday template is a valid argument for the identity tokens even on Sunday.
ck T12 "no token -> not_authenticated" "not_authenticated" \
  "$(token "select public.choose_daily_production_suggestion('$DAY', '$SUG_MON_A');")"
ck T12 "unknown sub -> no_active_profile" "no_active_profile" \
  "$(token "$(jset 99999999-9999-9999-9999-999999999999) select public.choose_daily_production_suggestion('$DAY', '$SUG_MON_A');")"
ck T12 "inactive profile -> no_active_profile" "no_active_profile" \
  "$(token "update profiles set active = false where id = '$OPERATOR'; $(jset $OPERATOR) select public.choose_daily_production_suggestion('$DAY', '$SUG_MON_A');")"
# Fully valid values are required: with NULLs the not-null constraint fires
# before RLS, so the denial could not be attributed to row-level security.
RLS1=$(err "set role authenticated; insert into production_suggestion_items (suggestion_id, product_id, shift_code, suggested_quantity, unit, sort_order, active) values ('$SUG_MON_A', '$BAGUETTE', 'morning', 1, 'latas', 1, true);")
ck T12 "client INSERT into production_suggestion_items denied by RLS" 1 \
  "$(printf '%s' "$RLS1" | grep -c 'row-level security')"
RLS2=$(err "set role authenticated; insert into daily_production_selections (production_day_id, suggestion_id, selected_by) values ('$DAY', '$SUG_MON_A', '$OPERATOR');")
ck T12 "client INSERT into daily_production_selections denied by RLS" 1 \
  "$(printf '%s' "$RLS2" | grep -c 'row-level security')"
RLS3=$(err "set role authenticated; insert into production_requests (production_day_id, source_type, shift_code, product_id, requested_quantity, unit, status, created_by) values ('$DAY', 'base', 'morning', '$BAGUETTE', 1, 'latas', 'pending', '$OPERATOR');")
ck T12 "client INSERT into production_requests denied by RLS" 1 \
  "$(printf '%s' "$RLS3" | grep -c 'row-level security')"
# Silent no-op check on a stable live row: today has no requests on Sunday,
# so use an existing historical request (the attempt is rolled back either
# way). A write policy would modify the row; without one it is a no-op.
HIST_REQ=$(sql "select id from production_requests limit 1;")
ck T12 "a live request row exists for the update no-op check" 1 "$(printf '%s' "$HIST_REQ" | grep -cE '^[0-9a-f-]{36}$')"
HIST_BEFORE=$(sql "select row_to_json(t)::text from (select * from production_requests t where t.id = '$HIST_REQ') t;")
RUN_UPD=$(run "set role authenticated; update production_requests set requested_quantity = requested_quantity + 1 where id = '$HIST_REQ';")
ck T12 "client UPDATE of a request row is a silent no-op (no write policy)" 0 \
  "$(printf '%s' "$RUN_UPD" | grep -cE '^ERROR')"
ck T12 "updated-attempt row unchanged" "$HIST_BEFORE" \
  "$(sql "select row_to_json(t)::text from (select * from production_requests t where t.id = '$HIST_REQ') t;")"
ck T12 "authorized RPC path works (operator choose/confirm/start/change in the TEST 9 fixture)" "ok" \
  "$(printf '%s' "$FIX_OUT" | grep -c '^ERROR' | awk '{print ($1 == 0) ? "ok" : "error"}')"

# ================================================================ TEST 13
echo ""
echo "== TEST 13: Saturday PARA LA TARDE rows never silently imported"
AMB_CSV="$ROOT/data/import-review-v6/production_suggestion_ambiguities.csv"
ITEMS_CSV="$ROOT/data/import-review-v6/production_suggestion_items.csv"
ck T13 "zero template rows contain PARA LA TARDE source text" "0" \
  "$(sql "select count(*) from production_suggestion_items where source_text like '%PARA LA TARDE%';")"
ck T13 "no template shift is afternoon (morning/night only)" "0" \
  "$(sql "select count(*) from production_suggestion_items where shift_code not in ('morning','night');")"
ck T13 "ambiguities CSV exists and flags 23 Saturday PARA LA TARDE rows" "23" \
  "$(grep -c 'do not infer' "$AMB_CSV" 2>/dev/null)"
ck T13 "every flagged row says shift_candidate=null, do not infer (§46)" "23" \
  "$(grep -c 'shift_candidate=null, do not infer (§46)' "$AMB_CSV" 2>/dev/null)"
# Row-identity check: the flagged SÁBADO afternoon rows (source rows 15-20)
# must not be among the rows that entered the seed payload (V6.7). A plain
# text intersection is NOT valid: a legitimate morning/night row may carry
# the same source text as an afternoon row (e.g. '10 latas trencitas').
PAYLOAD="$ROOT/data/import-review-v6/seed_payload.json"
ck T13 "no flagged SÁBADO afternoon row (sheet,row) present in the seed payload" 0 \
  "$(python3 - "$AMB_CSV" "$PAYLOAD" <<'PY'
import csv, json, sys
flagged = set()
with open(sys.argv[1], encoding="utf-8-sig") as f:
    for row in csv.DictReader(f):
        if row.get("source_sheet") == "SÁBADO" and "do not infer" in (row.get("notes") or ""):
            flagged.add((row.get("source_sheet"), int(row.get("source_row"))))
seeded = set()
with open(sys.argv[2], encoding="utf-8") as f:
    for item in json.load(f):
        seeded.add((item["source_sheet"], int(item["source_row"])))
overlap = flagged & seeded
print(len(overlap))
sys.stderr.write("flagged=%d seeded=%d overlap=%s\n" % (len(flagged), len(seeded), sorted(overlap)[:5]))
PY
)"
ck T13 "items CSV keeps the unresolved rows as review_required" "0" \
  "$(python3 - "$ITEMS_CSV" <<'PY'
import csv, sys
n_review = 0
n_unresolved_ok = 0
with open(sys.argv[1], encoding="utf-8-sig") as f:
    for row in csv.DictReader(f):
        if row.get("status") == "review_required":
            n_review += 1
            if not (row.get("matched_product_id") or "").strip():
                n_unresolved_ok += 1
print(0 if n_review > 0 and n_review == n_unresolved_ok else 1)
sys.stderr.write("review_required=%d\n" % n_review)
PY
)"

# ================================================================ TEST 15
echo ""
echo "== TEST 15: V5 regression (parts that need no live flow)"
HOME_PAGE="$WORK/t15_home.html"
ck T15 "login form at / is 200 with email + password inputs" "200" "$(get "$WORK/jar_fresh" / "$HOME_PAGE" 2>/dev/null || curl -s -c "$WORK/jar_fresh" -o "$HOME_PAGE" -w '%{http_code}' "$BASE/")"
contains_ck T15 "login form email input" 'type="email"' "$HOME_PAGE"
contains_ck T15 "login form password input" 'type="password"' "$HOME_PAGE"
# Shift selection renders on the production screen (cookie is never
# authorization; the header shows the selected shift even with no requests).
set_shift_cookie "$WORK/jar_op" morning
M_PAGE="$WORK/t15_morning.html"
ck T15 "SSR /production (MAÑANA cookie) is 200" "200" "$(get "$WORK/jar_op" /production "$M_PAGE")"
contains_ck T15 "MAÑANA view shows Turno: MAÑANA" 'Turno: MAÑANA' "$M_PAGE"
# Material lot addition (V5) + coexistence (V5.5: add opens a new current
# lot WITHOUT closing the other current lots of the material).
HARINA=$(sql "select id from raw_materials where name = 'Harina 000' limit 1;")
HARINA_BRAND=$(sql "select brand_id from material_lots ml join raw_materials rm on rm.id = ml.raw_material_id where rm.name = 'Harina 000' and ml.is_current limit 1;")
HARINA_PREV_CURRENT=$(sql "select count(*) from material_lots ml join raw_materials rm on rm.id = ml.raw_material_id where rm.name = 'Harina 000' and ml.is_current;")
# Autocommit: the lot must persist (cleanup removes V616-TEST-LOT on exit).
LOT_ID=$(sql "$(jset $OPERATOR) select public.add_material_lot('$HARINA', '$HARINA_BRAND', 'V616-TEST-LOT', get_business_date()::date);" | tail -1)
ck T15 "add_material_lot (operator) created a lot" 1 "$(printf '%s' "$LOT_ID" | grep -cE '^[0-9a-f-]{36}$')"
ck T15 "new lot is current and previous current lots coexist (V5.5)" "$HARINA_PREV_CURRENT" \
  "$(sql "select count(*) from material_lots ml join raw_materials rm on rm.id = ml.raw_material_id where rm.name = 'Harina 000' and ml.is_current and ml.id <> '$LOT_ID';")"
# Deferred (need the live suggestion flow; covered by the full suite on a
# weekday): "batch carries multiple material lots" and "additional request
# without reason survived the whole flow".
# Traceability page.
TR_PAGE="$WORK/t15_trace.html"
ck T15 "SSR /admin/traceability (admin) is 200" "200" "$(get "$WORK/jar_adm" /admin/traceability "$TR_PAGE")"

# ================================================================ summary
echo ""
echo "================================================"
echo "Sunday partial evidence (day-independent acceptance parts)"
echo "Deferred to the full suite on Monday-Saturday: TEST 2, 3, 4, 5, 6, 7, 8, 9 (live), 10, 12 (live) + TEST 15 batch/additional checks"
for t in 1 9 11 12 13 14 15; do
  if [ "${FAILS[T$t]:-0}" = "1" ]; then
    echo "TEST $t: FAIL"
  else
    echo "TEST $t: PASS"
  fi
done
if [ "$FAIL" = 0 ]; then
  echo "V6.16 SUNDAY PARTIAL EVIDENCE: ALL CHECKS PASS"
else
  echo "V6.16 SUNDAY PARTIAL EVIDENCE: FAILURES PRESENT"
fi
exit "$FAIL"

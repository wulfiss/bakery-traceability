#!/usr/bin/env bash
# V6.16 (spec §65) V6 ACCEPTANCE SUITE.
#
# Runs the complete spec §65 acceptance battery (TEST 1-15) against the
# local Supabase Docker stack and the RUNNING dev server
# (npm run dev -> http://localhost:5173). If the server is not reachable
# the suite SKIPs (exit 0), the same way v6_14 skips. It also SKIPs when
# the current business day is Sunday (no production suggestions exist).
#
# Coverage (spec §65):
#   TEST 1  suggestion availability: Mon/Wed-Thu-Fri-Sat -> A-D, Tue -> A-E,
#           no Sunday option (25 active template rows).
#   TEST 2  every option preview shows products and quantities before
#           selection (SSR of /production/suggestions, no selection yet).
#   TEST 3  operator can choose: selection created, items default selected.
#   TEST 4  admin can change the same shared selection: one row, no
#           duplicate admin-only selection.
#   TEST 5  uncheck one pending item, confirm: unchecked item absent from
#           base production, checked items present.
#   TEST 6  shift split: MAÑANA / NOCHE views show only their own requests.
#   TEST 7  change before any batch starts: pending base production fully
#           reconciles to the new option after re-confirm.
#   TEST 8  change after a batch starts: the started (locked) request is
#           never rewritten, only still-pending lines reconcile.
#   TEST 9  quantity difference: pending quantities are updated by the
#           change; a started request's quantity is never rewritten.
#           (fixture phase: controlled B'/C' quantities in a rolled-back
#           transaction with the REAL choose/confirm/start/change RPCs;
#           live phase: the pending updates of TEST 8's changes.)
#   TEST 10 external_order and additional requests are untouched by the
#           suggestion changes.
#   TEST 11 admin access cards: Suggested Production, Production, Raw
#           Materials, Traceability (plus operator /admin -> 303).
#   TEST 12 direct browser writes to the V6 tables are blocked by RLS;
#           the authorized RPC path works; inactive/unauthorized
#           identities fail with the exact tokens.
#   TEST 13 Saturday PARA LA TARDE rows were never silently imported:
#           zero template rows carry them and they remain flagged in the
#           V6.6 import review CSVs.
#   TEST 14 historical integrity: suggestion changes never modify
#           completed/in-progress requests, batches or batch_materials.
#   TEST 15 V5 regression: login at /, MAÑANA/NOCHE selection, material
#           lot addition with coexistence, multiple lots in one batch,
#           additional request without reason, traceability page.
#
# The live flow runs on the CURRENT business day (clean baseline required:
# no selection, no requests, no batches for today). The TEST 9 fixture
# phase runs inside a single rolled-back transaction before the live flow.
# A trap cleanup removes everything the suite creates for today.
#
# Dev credentials (local Docker profiles, fixed for development):
#   operator@test.local / operator123
#   supervisor@test.local / supervisor123
#   admin@test.local / admin123
#
# Usage: bash supabase/tests/v6_16_acceptance_tests.sh
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

# token_ac <sql...> -> like token, but AUTOCOMMIT (live writes that must
# persist: choose/toggle/confirm/start). Empty on success.
token_ac() {
  sql "$1" | grep -oE 'ERROR:  [a-z_]+' | head -1 | sed 's/ERROR:  //'
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

# not_contains_ck <test> <desc> <needle> <file>
not_contains_ck() {
  if grep -qF "$3" "$4"; then
    echo "FAIL [$1] $2 (unexpected: $3)"
    FAILS["$1"]=1
    FAIL=1
  else
    echo "PASS [$1] $2"
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
# one committed transaction (test environment only). Note the actual column
# names: parent_batch_inputs has child_batch_id/parent_batch_output_id and
# batch_requests has batch_id/production_request_id. Every FK involved is
# ON DELETE RESTRICT, so this exact order matters:
#   daily_production_selection_items -> production_requests
#   production_requests / production_batches / daily_production_selections -> production_days
# (An earlier revision deleted production_requests before the selection
# items and never deleted production_batches at all; the whole transaction
# aborted on the first restrict violation and nothing was cleaned, leaving
# the next run with a dirty baseline.)
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

echo "== preconditions: clean baseline for the current business day"
# Make the suite re-runnable on the shared dev database: a previous run whose
# trap failed (or was killed) may have left today's state behind; wipe it
# before asserting a clean baseline.
wipe_day "$(sql "select id from production_days where production_date = get_business_date();" | tail -1)"
WEEKDAY=$(sql "select extract(isodow from get_business_date())::smallint;")
# Sunday (isodow 7) has no production suggestions: the live flow of this
# suite (TEST 2-9, 12, 15) cannot run on it, so skip like an unreachable
# server and re-run on Monday-Saturday.
if [ "$WEEKDAY" = "7" ]; then
  echo "SKIP: business day is Sunday (no production suggestions exist); re-run on Monday-Saturday"
  exit 0
fi
BASELINE=$(sql "select (select count(*) from daily_production_selections where production_day_id = (select id from production_days where production_date = get_business_date()))
  || '|' || (select count(*) from production_requests where production_day_id = (select id from production_days where production_date = get_business_date()))
  || '|' || (select count(*) from production_batches where production_day_id = (select id from production_days where production_date = get_business_date()));")
ck pre "clean baseline (selections|requests|batches for today)" "0|0|0" "$BASELINE"

login "$OPERATOR_EMAIL" "$OPERATOR_PASSWORD" "$WORK/jar_op"
login "$ADMIN_EMAIL" "$ADMIN_PASSWORD" "$WORK/jar_adm"

# Ensure today's production day exists (idempotent RPC, authorized path).
# Autocommit: the live flow below needs the row to persist.
DAY=$(sql "$(jset $OPERATOR) select public.ensure_production_day();" | tail -1)
ck pre "ensure_production_day returns a day id" 1 "$(printf '%s' "$DAY" | grep -cE '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')"

# TEST 14 snapshot of every completed batch, before the live flow touches anything.
T14_COMPLETED_BEFORE="$WORK/t14_completed_before.txt"
sql "select (row_to_json(t))::text from production_batches t where status = 'completed' order by id;" > "$T14_COMPLETED_BEFORE" 2>&1

# Fixture ids (stable live rows).
BAGUETTE=$(sql "select id from products where name = 'Baguette' limit 1;")
CHIP=$(sql "select id from products where name = 'Chip' limit 1;")
PEBETE=$(sql "select id from products where name = 'Pan pebete' limit 1;")
HAMBURGUESA=$(sql "select id from products where name = 'Hamburguesa' limit 1;")
AREPANE=$(sql "select id from products where name = 'Pan árabe' limit 1;")
PERNIL=$(sql "select id from products where name = 'Pan pernil' limit 1;")
TRENCITAS=$(sql "select id from products where name = 'Trencitas dulces' limit 1;")
CUCIA=$(sql "select id from products where name = 'Cara sucia' limit 1;")
LACTAL=$(sql "select id from products where name = 'Pan lactal' limit 1;")
CHIPACITOS=$(sql "select id from products where name = 'Chipacitos' limit 1;")
SUG_B=$(sql "select id from production_suggestions where active and weekday = $WEEKDAY and code = 'B' limit 1;")
SUG_C=$(sql "select id from production_suggestions where active and weekday = $WEEKDAY and code = 'C' limit 1;")
SUG_A=$(sql "select id from production_suggestions where active and weekday = $WEEKDAY and code = 'A' limit 1;")

# ================================================================ TEST 1
echo ""
echo "== TEST 1: suggestion availability per weekday"
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

# ================================================================ TEST 2
echo ""
echo "== TEST 2: option previews show products and quantities before selection"
ck T2 "no selection exists before choosing" "0" \
  "$(sql "select count(*) from daily_production_selections where production_day_id = '$DAY';")"
SUG_PAGE="$WORK/t2_suggestions.html"
ck T2 "SSR /production/suggestions (operator, unselected) is 200" "200" "$(get "$WORK/jar_op" /production/suggestions "$SUG_PAGE")"
contains_ck T2 "preview renders option cards A-D" 'OPCIÓN A' "$SUG_PAGE"
contains_ck T2 "preview card B shows its full count (9 productos)" '9 productos' "$SUG_PAGE"
contains_ck T2 "preview card A count (8 productos)" '8 productos' "$SUG_PAGE"
contains_ck T2 "preview MAÑANA group with product + quantity" 'Cara sucia — 3 latas' "$SUG_PAGE"
contains_ck T2 "preview A night quantities (Trencitas 15 latas)" 'Trencitas dulces — 15 latas' "$SUG_PAGE"
contains_ck T2 "preview C night quantities (Pan pernil 10 kg)" 'Pan pernil — 10 kg' "$SUG_PAGE"
contains_ck T2 "preview C night quantities (Pan árabe 8 latas)" 'Pan árabe — 8 latas' "$SUG_PAGE"
contains_ck T2 "preview night group header" 'NOCHE' "$SUG_PAGE"
contains_ck T2 "preview offers to expand full contents (VER TODOS (5) on B night)" 'VER TODOS (5)' "$SUG_PAGE"
RESP=$(get_resp "$WORK/jar_op" /production/suggestions/review)
ck T2 "review page redirects before a selection (no early review)" "303" "$(printf '%s' "$RESP" | cut -d'|' -f1)"

# ============================================== TEST 9 fixture phase
# Controlled B'/C' suggestions (Baguette 5 vs 8, Pebete 2 vs 4, Chip only in
# B', Hamburguesa only in C') in a single rolled-back transaction, running
# the REAL choose -> confirm -> start -> change RPCs. Proves TEST 9's
# quantity semantics: pending updated, started never rewritten, removed
# line cancelled, new line added.
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

# ================================================================ TEST 3
echo ""
echo "== TEST 3: operator chooses the daily suggestion (B)"
ck T3 "operator choose B raised no error" "" "$(token_ac "$(jset $OPERATOR) select public.choose_daily_production_suggestion('$DAY', '$SUG_B');")"
ck T3 "exactly one daily selection" "1" \
  "$(sql "select count(*) from daily_production_selections where production_day_id = '$DAY';")"
ck T3 "selection is draft on suggestion B, chosen by operator" "draft|B|$OPERATOR" \
  "$(sql "select s.status || '|' || g.code || '|' || s.selected_by from daily_production_selections s join production_suggestions g on g.id = s.suggestion_id where s.production_day_id = '$DAY';")"
ck T3 "all B items snapshotted and default-selected (9)" "9" \
  "$(sql "select count(*) from daily_production_selection_items where daily_selection_id = (select id from daily_production_selections where production_day_id = '$DAY') and is_selected;")"

# ================================================================ TEST 4
echo ""
echo "== TEST 4: admin changes the same shared selection (C), no duplicate"
ck T4 "admin change to C raised no error" "" "$(token_ac "$(jset $ADMIN) select public.choose_daily_production_suggestion('$DAY', '$SUG_C');")"
ck T4 "still exactly one daily selection (no admin-only duplicate)" "1" \
  "$(sql "select count(*) from daily_production_selections where production_day_id = '$DAY';")"
ck T4 "selection now on C, still draft, chooser kept, updated by admin" "draft|C|$OPERATOR|$ADMIN" \
  "$(sql "select s.status || '|' || g.code || '|' || s.selected_by || '|' || s.updated_by from daily_production_selections s join production_suggestions g on g.id = s.suggestion_id where s.production_day_id = '$DAY';")"
ck T4 "snapshot re-created from C (8 items, all selected)" "8" \
  "$(sql "select count(*) from daily_production_selection_items where daily_selection_id = (select id from daily_production_selections where production_day_id = '$DAY') and is_selected;")"
ck T4 "no template row was modified by the change (V6 templates untouched)" "0" \
  "$(sql "select count(*) from production_suggestion_items where updated_at > now() - interval '10 minutes';")"

# ================================================================ TEST 5
echo ""
echo "== TEST 5: uncheck one pending item, then confirm"
ITEM_ARABE=$(sql "select i.id from daily_production_selection_items i where i.daily_selection_id = (select id from daily_production_selections where production_day_id = '$DAY') and i.product_id = '$AREPANE';")
ck T5 "toggle Pan árabe (unchecked) raised no error" "" "$(token_ac "$(jset $OPERATOR) select public.toggle_daily_selection_item('$ITEM_ARABE');")"
# psql -t -A renders booleans as f/t (not false/true).
ck T5 "item unchecked in the daily snapshot" "f" \
  "$(sql "select is_selected from daily_production_selection_items where id = '$ITEM_ARABE';")"
ck T5 "confirm raised no error" "" "$(token_ac "$(jset $OPERATOR) select public.confirm_daily_production();")"
ck T5 "selection confirmed" "confirmed" \
  "$(sql "select status from daily_production_selections where production_day_id = '$DAY';")"
ck T5 "7 base pending requests (C minus unchecked Pan árabe)" "7" \
  "$(sql "select count(*) from production_requests where production_day_id = '$DAY' and source_type = 'base' and status = 'pending';")"
ck T5 "unchecked Pan árabe absent from base production" "0" \
  "$(sql "select count(*) from production_requests where production_day_id = '$DAY' and source_type = 'base' and product_id = '$AREPANE';")"
# Query order is shift_code, product_id (uuid lexical): morning CUCIA,
# PEBETE, CHIP, BAGUETTE -> 2|3|8|4; night PERNIL, TRENCITAS, CHIPACITOS -> 10|10|2.
ck T5 "checked items present with template quantities" \
  "2|3|8|4|10|10|2" \
  "$(sql "select coalesce(string_agg(r.requested_quantity::text, '|' order by r.shift_code, r.product_id), '') from production_requests r where r.production_day_id = '$DAY' and r.source_type = 'base' and r.status = 'pending' and r.product_id in ('$CUCIA','$BAGUETTE','$CHIP','$PEBETE','$CHIPACITOS','$TRENCITAS','$PERNIL') and r.product_id <> '$CUCIA' or (r.product_id = '$CUCIA');")"
# product_id (uuid) ascending: PERNIL, CUCIA, TRENCITAS, CHIPACITOS, PEBETE, CHIP, BAGUETTE.
ck T5 "per-product quantities match C" \
  "$PERNIL:10|$CUCIA:2|$TRENCITAS:10|$CHIPACITOS:2|$PEBETE:3|$CHIP:8|$BAGUETTE:4" \
  "$(sql "select product_id::text || ':' || requested_quantity::text from production_requests where production_day_id = '$DAY' and source_type = 'base' and status = 'pending' order by product_id;" | tr '\n' '|' | sed 's/|$//')"

# ================================================================ TEST 6
echo ""
echo "== TEST 6: MAÑANA / NOCHE views show only their own requests"
ck T6 "DB: 4 morning pending requests" "4" \
  "$(sql "select count(*) from production_requests where production_day_id = '$DAY' and source_type = 'base' and status = 'pending' and shift_code = 'morning';")"
ck T6 "DB: 3 night pending requests (unchecked árabe excluded)" "3" \
  "$(sql "select count(*) from production_requests where production_day_id = '$DAY' and source_type = 'base' and status = 'pending' and shift_code = 'night';")"
set_shift_cookie "$WORK/jar_op" morning
M_PAGE="$WORK/t6_morning.html"
ck T6 "SSR /production (MAÑANA cookie) is 200" "200" "$(get "$WORK/jar_op" /production "$M_PAGE")"
contains_ck T6 "MAÑANA view shows Turno: MAÑANA" 'Turno: MAÑANA' "$M_PAGE"
# The h2 carries a Svelte scoped class (e.g. "group-name svelte-1beqb4y"),
# so match the stable fragment '>NAME</h2>' instead of the full class list.
contains_ck T6 "MAÑANA view lists Cara sucia" '>Cara sucia</h2>' "$M_PAGE"
contains_ck T6 "MAÑANA view lists Baguette" '>Baguette</h2>' "$M_PAGE"
contains_ck T6 "MAÑANA view lists Chip" '>Chip</h2>' "$M_PAGE"
contains_ck T6 "MAÑANA view lists Pan pebete" '>Pan pebete</h2>' "$M_PAGE"
not_contains_ck T6 "MAÑANA view has no Chipacitos group" '>Chipacitos</h2>' "$M_PAGE"
not_contains_ck T6 "MAÑANA view has no Trencitas group" '>Trencitas dulces</h2>' "$M_PAGE"
not_contains_ck T6 "MAÑANA view has no Pan pernil group" '>Pan pernil</h2>' "$M_PAGE"
set_shift_cookie "$WORK/jar_op" night
N_PAGE="$WORK/t6_night.html"
ck T6 "SSR /production (NOCHE cookie) is 200" "200" "$(get "$WORK/jar_op" /production "$N_PAGE")"
contains_ck T6 "NOCHE view shows Turno: NOCHE" 'Turno: NOCHE' "$N_PAGE"
contains_ck T6 "NOCHE view lists Chipacitos" '>Chipacitos</h2>' "$N_PAGE"
contains_ck T6 "NOCHE view lists Trencitas" '>Trencitas dulces</h2>' "$N_PAGE"
contains_ck T6 "NOCHE view lists Pan pernil" '>Pan pernil</h2>' "$N_PAGE"
not_contains_ck T6 "NOCHE view has no Cara sucia group" '>Cara sucia</h2>' "$N_PAGE"
not_contains_ck T6 "NOCHE view has no Baguette group" '>Baguette</h2>' "$N_PAGE"

# ================================================================ TEST 7
echo ""
echo "== TEST 7: change before any batch starts -> pending fully reconciles"
ck T7 "change to B (no batches started yet) raised no error" "" "$(token_ac "$(jset $OPERATOR) select public.choose_daily_production_suggestion('$DAY', '$SUG_B');")"
ck T7 "selection back to draft on B" "draft|B" \
  "$(sql "select s.status || '|' || g.code from daily_production_selections s join production_suggestions g on g.id = s.suggestion_id where s.production_day_id = '$DAY';")"
ck T7 "pending fully reconciled to B: 9 requests incl. Pan lactal and Pan árabe" "9" \
  "$(sql "select count(*) from production_requests where production_day_id = '$DAY' and source_type = 'base' and status = 'pending';")"
# product_id (uuid) ascending: PERNIL, CUCIA, TRENCITAS, CHIPACITOS, LACTAL, PEBETE, CHIP, AREPANE, BAGUETTE.
ck T7 "per-product quantities match B (incl. new lines)" \
  "$PERNIL:6|$CUCIA:2|$TRENCITAS:10|$CHIPACITOS:2|$LACTAL:0.5|$PEBETE:3|$CHIP:8|$AREPANE:7|$BAGUETTE:4" \
  "$(sql "select product_id::text || ':' || requested_quantity::text from production_requests where production_day_id = '$DAY' and source_type = 'base' and status = 'pending' order by product_id;" | tr '\n' '|' | sed 's/|$//')"
ck T7 "change to C raised no error" "" "$(token_ac "$(jset $OPERATOR) select public.choose_daily_production_suggestion('$DAY', '$SUG_C');")"
ck T7 "re-confirm raised no error" "" "$(token_ac "$(jset $OPERATOR) select public.confirm_daily_production();")"
ck T7 "selection confirmed again" "confirmed" \
  "$(sql "select status from daily_production_selections where production_day_id = '$DAY';")"
ck T7 "pending base production matches C: 8 requests" "8" \
  "$(sql "select count(*) from production_requests where production_day_id = '$DAY' and source_type = 'base' and status = 'pending';")"
# 0 pending + 1 cancelled: the reconciliation cancelled the row history-safe.
# (Count filters on status; a plain `and status = 'pending' || '|' || 0` would
#  parse as a string comparison and always return 0|0.)
ck T7 "no request left for the C-absent Pan lactal besides a cancelled one" "0|1" \
  "$(sql "select count(*) filter (where status = 'pending') || '|' || count(*) filter (where status = 'cancelled') from production_requests where production_day_id = '$DAY' and source_type = 'base' and product_id = '$LACTAL';")"

# ============================================== TEST 10 fixtures
# Independent sources created BEFORE the after-start changes: one external
# order item and one additional request WITHOUT reason (V5.7). Snapshotted
# here; byte-compared at the end (nothing may touch them).
echo ""
echo "== TEST 10: external order + additional (no reason) created, snapshotted"
# create_external_order / add_external_order_item require a supervisor or
# admin profile (role check inside the RPCs) - the operator would get
# 'insufficient_role'. The additional request below stays an operator path.
EXT_ID=$(sql "$(jset $ADMIN) select public.create_external_order('V616-TEST', 'Cliente Aceptación', get_business_date()::date, '10:00', 'suite V6.16');" | tail -1)
ck T10 "external order created" 1 "$(printf '%s' "$EXT_ID" | grep -cE '^[0-9a-f-]{36}$')"
sql "$(jset $ADMIN) select public.add_external_order_item('$EXT_ID', '$HAMBURGUESA', 2, 'carro', 'morning', NULL);" > "$WORK/t10_ext_item.txt" 2>&1
grep -q '^ERROR' "$WORK/t10_ext_item.txt" && ck T10 "external order item raised no error" "no-error" "$(head -1 "$WORK/t10_ext_item.txt")" || ck T10 "external order item raised no error" "no-error" "no-error"
ADD_ID=$(sql "$(jset $OPERATOR) select public.create_additional_production_request('$DAY', '$HAMBURGUESA', 1, 'carro', 'morning', NULL, NULL);" | tail -1)
ck T10 "additional request (reason NULL, V5.7) created" 1 "$(printf '%s' "$ADD_ID" | grep -cE '^[0-9a-f-]{36}$')"
# The external-order request row only materializes when /production loads
# (its server runs ensure_external_order_requests); mirror that app step so
# the snapshot captures a real external_order row, not just the additional one.
EXT_CREATED=$(sql "$(jset $OPERATOR) select public.ensure_external_order_requests('$DAY');" | tail -1)
ck T10 "ensure_external_order_requests created the item row" "1" "$EXT_CREATED"
T10_SNAP_BEFORE="$WORK/t10_before.json"
sql "select row_to_json(t)::text from (select * from production_requests t where t.id in (select id from production_requests where production_day_id = '$DAY' and source_type in ('external_order','additional')) order by id) t;" > "$T10_SNAP_BEFORE" 2>&1
ck T10 "two independent-source rows snapshotted" "2" "$(wc -l < "$T10_SNAP_BEFORE")"
ck T10 "additional row stores reason_code = NULL" "1" \
  "$(sql "select count(*) from production_requests where id = '$ADD_ID' and reason_code is null and reason_note is null;")"

# ================================================================ TEST 8
echo ""
echo "== TEST 8: change after a batch starts -> started line locked"
BAG_REQ=$(sql "select id from production_requests where production_day_id = '$DAY' and source_type = 'base' and product_id = '$BAGUETTE';")
# All current lots at start time; start_production_batch copies exactly these
# into batch_materials (V5.5: several lots per raw material may be current).
LOTS_AT_START=$(sql "select count(*) from material_lots where is_current;")
# Autocommit: the batch must persist for TEST 12/14/15 checks.
START_OUT=$(sql "$(jset $OPERATOR) select public.start_production_batch(p_production_request_id := '$BAG_REQ');" 2>&1)
ck T8 "real start_production_batch (Baguette) raised no error" 0 "$(printf '%s' "$START_OUT" | grep -c '^ERROR')"
BATCH=$(sql "select id from production_batches where production_day_id = '$DAY' and status = 'in_progress';")
ck T8 "one in-progress batch created" 1 "$(printf '%s' "$BATCH" | grep -cE '^[0-9a-f-]{36}$')"
# Snapshot the started (now locked) Baguette row AFTER the pending ->
# in_progress transition: a later change must never rewrite it.
BAG_AFTER_START=$(sql "select row_to_json(t)::text from (select * from production_requests t where t.id = '$BAG_REQ') t;")
BATCH_CODE=$(sql "select batch_code from production_batches where id = '$BATCH';")
echo "   (batch code: $BATCH_CODE)"
ck T8 "batch code format PAN-DDMMYY-M-NNN" 1 "$(printf '%s' "$BATCH_CODE" | grep -cE '^PAN-190926-M-[0-9]{3}$')"
ck T8 "batch started by the operator, shift morning" "$OPERATOR|morning" \
  "$(sql "select started_by || '|' || shift_code from production_batches where id = '$BATCH';")"
ck T8 "Batchuette request is in_progress, qty 4" "in_progress|4" \
  "$(sql "select status || '|' || requested_quantity::text from production_requests where id = '$BAG_REQ';")"
# TEST 14 snapshot S1 (after start + before the after-start change).
T14_SNAP="$WORK/t14_snap.txt"
sql "select md5(string_agg(s, '' order by s)) from (
  select (row_to_json(t))::text as s from production_requests t where t.status in ('in_progress','completed')
  union all select (row_to_json(t))::text from production_batches t
  union all select (row_to_json(t))::text from batch_materials t
) u;" > "$T14_SNAP" 2>&1
echo "   (T14 S1 = $(cat "$T14_SNAP"))"
# Change the suggestion AFTER the start: C -> A.
ck T8 "change to A after the start raised no error" "" "$(token_ac "$(jset $OPERATOR) select public.choose_daily_production_suggestion('$DAY', '$SUG_A');")"
BAG_AFTER_LIVE=$(sql "select row_to_json(t)::text from (select * from production_requests t where t.id = '$BAG_REQ') t;")
ck T8 "started Baguette request byte-identical (locked, never rewritten)" 0 \
  "$(printf '%s' "$BAG_AFTER_START" | cmp -s - <(printf '%s' "$BAG_AFTER_LIVE") && echo 0 || echo 1)"
ck T8 "still exactly one Baguette request (no duplicate snapshot row)" "1" \
  "$(sql "select count(*) from production_requests where production_day_id = '$DAY' and product_id = '$BAGUETTE';")"
ck T8 "batch still in_progress with its material lots intact" "in_progress|$LOTS_AT_START" \
  "$(sql "select status || '|' || count(*) from production_batches b left join batch_materials m on m.batch_id = b.id where b.id = '$BATCH' group by status;")"
# A has 8 template lines; 7 become/remain pending, Baguette is in_progress
# (locked), and the C-absent Pan lactal row stays cancelled from TEST 7.
ck T8 "pending reconciled to A: 7 pending + 1 in_progress + 1 cancelled (lactal)" \
  "7|1|1" \
  "$(sql "select count(*) filter (where status = 'pending') || '|' || count(*) filter (where status = 'in_progress') || '|' || count(*) filter (where status = 'cancelled') from production_requests where production_day_id = '$DAY' and source_type = 'base';")"
# product_id (uuid) ascending: PERNIL, CUCIA, TRENCITAS, CHIPACITOS, PEBETE, CHIP, AREPANE, BAGUETTE.
ck T8 "pending quantities match A (pernil 10->6, trencitas 10->15, árabe 8->7, cara 2->3)" \
  "$PERNIL:6|$CUCIA:3|$TRENCITAS:15|$CHIPACITOS:2|$PEBETE:3|$CHIP:8|$AREPANE:7|$BAGUETTE:4" \
  "$(sql "select product_id::text || ':' || requested_quantity::text from production_requests where production_day_id = '$DAY' and source_type = 'base' and status in ('pending','in_progress') order by product_id;" | tr '\n' '|' | sed 's/|$//')"
ck T8 "selection back to draft on A (awaiting re-confirm)" "draft|A" \
  "$(sql "select s.status || '|' || g.code from daily_production_selections s join production_suggestions g on g.id = s.suggestion_id where s.production_day_id = '$DAY';")"

# ================================================================ TEST 9
echo ""
echo "== TEST 9 (live): pending quantities updated, started never rewritten"
ck T9 "live change A -> B raised no error" "" "$(token_ac "$(jset $OPERATOR) select public.choose_daily_production_suggestion('$DAY', '$SUG_B');")"
# B has 9 template lines: 8 pending + the locked in_progress Baguette.
# product_id (uuid) ascending: PERNIL, CUCIA, TRENCITAS, CHIPACITOS, LACTAL, PEBETE, CHIP, AREPANE, BAGUETTE.
ck T9 "live: pending cara sucia updated 3 -> 2 (B) and trencitas 15 -> 10 (B)" \
  "$PERNIL:6|$CUCIA:2|$TRENCITAS:10|$CHIPACITOS:2|$LACTAL:0.5|$PEBETE:3|$CHIP:8|$AREPANE:7|$BAGUETTE:4" \
  "$(sql "select product_id::text || ':' || requested_quantity::text from production_requests where production_day_id = '$DAY' and source_type = 'base' and status in ('pending','in_progress') order by product_id;" | tr '\n' '|' | sed 's/|$//')"
BAG_AFTER_T9=$(sql "select row_to_json(t)::text from (select * from production_requests t where t.id = '$BAG_REQ') t;")
ck T9 "live: started Baguette still byte-identical after the second change" 0 \
  "$(printf '%s' "$BAG_AFTER_START" | cmp -s - <(printf '%s' "$BAG_AFTER_T9") && echo 0 || echo 1)"
sql "select md5(string_agg(s, '' order by s)) from (
  select (row_to_json(t))::text as s from production_requests t where t.status in ('in_progress','completed')
  union all select (row_to_json(t))::text from production_batches t
  union all select (row_to_json(t))::text from batch_materials t
) u;" > "$WORK/t14_snap2.txt" 2>&1

# ================================================================ TEST 14
echo ""
echo "== TEST 14: suggestion changes never modify history (in_progress/completed)"
ck T14 "in_progress/completed requests + batches + batch_materials identical after the changes" \
  "$(cat "$T14_SNAP")" "$(cat "$WORK/t14_snap2.txt")"
# production_batches has no updated_at column: byte-compare the full set of
# completed batches against the pre-live snapshot taken in the preconditions.
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
ck T12 "no token -> not_authenticated" "not_authenticated" \
  "$(token "select public.choose_daily_production_suggestion('$DAY', '$SUG_A');")"
ck T12 "unknown sub -> no_active_profile" "no_active_profile" \
  "$(token "$(jset 99999999-9999-9999-9999-999999999999) select public.choose_daily_production_suggestion('$DAY', '$SUG_A');")"
ck T12 "inactive profile -> no_active_profile" "no_active_profile" \
  "$(token "update profiles set active = false where id = '$OPERATOR'; $(jset $OPERATOR) select public.choose_daily_production_suggestion('$DAY', '$SUG_A');")"
# Fully valid values are required: with NULLs the not-null constraint fires
# before RLS, so the denial could not be attributed to row-level security.
RLS1=$(err "set role authenticated; insert into production_suggestion_items (suggestion_id, product_id, shift_code, suggested_quantity, unit, sort_order, active) values ('$SUG_A', '$BAGUETTE', 'morning', 1, 'latas', 1, true);")
ck T12 "client INSERT into production_suggestion_items denied by RLS" 1 \
  "$(printf '%s' "$RLS1" | grep -c 'row-level security')"
RLS2=$(err "set role authenticated; insert into daily_production_selections (production_day_id, suggestion_id, selected_by) values ('$DAY', '$SUG_A', '$OPERATOR');")
ck T12 "client INSERT into daily_production_selections denied by RLS" 1 \
  "$(printf '%s' "$RLS2" | grep -c 'row-level security')"
RLS3=$(err "set role authenticated; insert into production_requests (production_day_id, source_type, shift_code, product_id, requested_quantity, unit, status, created_by) values ('$DAY', 'base', 'morning', '$BAGUETTE', 1, 'latas', 'pending', '$OPERATOR');")
ck T12 "client INSERT into production_requests denied by RLS" 1 \
  "$(printf '%s' "$RLS3" | grep -c 'row-level security')"
RUN_UPD=$(run "set role authenticated; update production_requests set requested_quantity = requested_quantity + 1 where id = '$BAG_REQ';")
ck T12 "client UPDATE of a request row is a silent no-op (no write policy)" 0 \
  "$(printf '%s' "$RUN_UPD" | grep -cE '^ERROR')"
ck T12 "updated-attempt row unchanged" "$BAG_AFTER_T9" \
  "$(sql "select row_to_json(t)::text from (select * from production_requests t where t.id = '$BAG_REQ') t;")"
ck T12 "authorized RPC path works (operator choose succeeded in TEST 3-9)" "ok" \
  "$(printf '%s' "$START_OUT" | grep -c '^ERROR' | awk '{print ($1 == 0) ? "ok" : "error"}')"

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
echo "== TEST 15: V5 regression"
HOME_PAGE="$WORK/t15_home.html"
ck T15 "login form at / is 200 with email + password inputs" "200" "$(get "$WORK/jar_fresh" / "$HOME_PAGE" 2>/dev/null || curl -s -c "$WORK/jar_fresh" -o "$HOME_PAGE" -w '%{http_code}' "$BASE/")"
contains_ck T15 "login form email input" 'type="email"' "$HOME_PAGE"
contains_ck T15 "login form password input" 'type="password"' "$HOME_PAGE"
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
# Multiple lots in one batch: the TEST 8 batch copied its current lots.
ck T15 "batch carries multiple material lots (3 distinct raw materials)" "3" \
  "$(sql "select count(distinct raw_material_id) from batch_materials where batch_id = '$BATCH';")"
# Additional without reason: verified with the TEST 10 fixture row.
ck T15 "additional request without reason survived the whole flow" "pending|NULL" \
  "$(sql "select status || '|' || coalesce(reason_code, 'NULL') from production_requests where id = '$ADD_ID';")"
# Traceability page.
TR_PAGE="$WORK/t15_trace.html"
ck T15 "SSR /admin/traceability (admin) is 200" "200" "$(get "$WORK/jar_adm" /admin/traceability "$TR_PAGE")"

# ================================================================ TEST 10 (final)
echo ""
echo "== TEST 10 (final): independent sources untouched by the changes"
sql "select row_to_json(t)::text from (select * from production_requests t where t.id in (select id from production_requests where production_day_id = '$DAY' and source_type in ('external_order','additional')) order by id) t;" > "$WORK/t10_after.json" 2>&1
ck T10 "external order + additional rows byte-identical after all changes" 0 \
  "$(cmp -s "$T10_SNAP_BEFORE" "$WORK/t10_after.json" && echo 0 || echo 1)"
ck T10 "independent rows are not linked to the daily selection" "0" \
  "$(sql "select count(*) from daily_production_selection_items i join production_requests r on r.id = i.production_request_id where r.source_type in ('external_order','additional');")"

# ================================================================ summary
echo ""
echo "================================================"
# ck() records failures under keys like 'T5', so the summary must look up
# the same 'T<n>' keys (a bare <n> would always read empty).
for t in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
  if [ "${FAILS[T$t]:-0}" = "1" ]; then
    echo "TEST $t: FAIL"
  else
    echo "TEST $t: PASS"
  fi
done
if [ "$FAIL" = 0 ]; then
  echo "V6 ACCEPTANCE SUITE: ALL TESTS PASS"
else
  echo "V6 ACCEPTANCE SUITE: FAILURES PRESENT"
fi
exit "$FAIL"

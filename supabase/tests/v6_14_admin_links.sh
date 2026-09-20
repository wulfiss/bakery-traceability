#!/usr/bin/env bash
# V6.14 (spec §63) role tests: ADMIN LINKS TO WORKING FEATURES.
#
# The role guards are SvelteKit server loads (not SQL), so this test runs
# against the RUNNING dev server (npm run dev -> http://localhost:5173) and
# verifies role behavior end-to-end through real SSR responses. If the
# server is not reachable the test SKIPs (exit 0), the same way other V6
# scripts skip when their preconditions are not met.
#
# Coverage (spec §63):
#   * unauthenticated /admin -> 303 to / ;
#   * operator: /admin, /admin/traceability and /admin/external-orders all
#     303 to /production — sharing Suggested Production does NOT grant
#     operator any /admin access;
#   * supervisor (current role policy preserved): /admin hub 200 with the
#     shared links (Producción sugerida, Producción, Materias primas,
#     Pedidos externos) and WITHOUT the admin-only links (Trazabilidad,
#     Recetas, ...); /admin/external-orders 200; /admin/traceability 303
#     to /admin/external-orders;
#   * admin: /admin 200 with the four spec §63 cards (Producción sugerida,
#     Producción, Materias primas, Trazabilidad); /admin/traceability 200;
#   * "admin can return to Admin easily": supervisor+ see
#     "Volver a Administración" on /production/suggestions, /production,
#     /lots and /production/suggestions/review; operators see nothing;
#   * "operators access Suggested Production from /production": the
#     operator's /production page (shift selected, nothing confirmed yet)
#     offers "ELEGIR PRODUCCIÓN" -> /production/suggestions.
#
# The review-page check is stateful: it chooses today's first active
# suggestion through the real form action as the operator, asserts the
# review page for admin and operator, then cleans up (trap) so nothing
# persists. It is skipped when a selection for today already exists.
#
# Dev credentials (local Docker profiles, fixed for development):
#   operator@test.local / operator123
#   supervisor@test.local / supervisor123
#   admin@test.local / admin123
#
# Usage: bash supabase/tests/v6_14_admin_links.sh
set -u
BASE=http://localhost:5173
DB=supabase_db_bakery-traceability
OPERATOR_EMAIL=operator@test.local
OPERATOR_PASSWORD=operator123
SUPERVISOR_EMAIL=supervisor@test.local
SUPERVISOR_PASSWORD=supervisor123
ADMIN_EMAIL=admin@test.local
ADMIN_PASSWORD=admin123
FAIL=0

WORK=$(mktemp -d)
CLEANUP_SELECTION=0
cleanup() {
  if [ "$CLEANUP_SELECTION" = 1 ]; then
    docker exec -i "$DB" psql -U postgres -d postgres -q -c \
      "delete from daily_production_selection_items where daily_selection_id in (select id from daily_production_selections where production_day_id = (select id from production_days where production_date = get_business_date()));" \
      >/dev/null 2>&1
    docker exec -i "$DB" psql -U postgres -d postgres -q -c \
      "delete from daily_production_selections where production_day_id = (select id from production_days where production_date = get_business_date());" \
      >/dev/null 2>&1
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT

if ! curl -s -o /dev/null --max-time 5 "$BASE/"; then
  echo "SKIP: dev server not reachable at $BASE (start it with npm run dev first)"
  exit 0
fi

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAIL=1; }

# check <desc> <expected> <actual>
check() {
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected: $2, got: $3)"; fi
}

# get <jar> <path> <outfile> -> prints the HTTP status of a GET.
get() {
  curl -s -b "$1" -o "$3" -w '%{http_code}' "$BASE$2"
}

# status_and_location: reads raw response headers on stdin and prints
# "STATUS|LOCATION" (empty parts when absent).
status_and_location() {
  tr -d '\r' | awk '
    $0 ~ /^HTTP\// {split($0, a, " "); status=a[2]; next}
    {n=index($0, ": "); if (n > 0) {
        key=tolower(substr($0, 1, n-1)); val=substr($0, n+2);
        if (key=="location") loc=val
    }}
    END {print status "|" loc}'
}

# get_resp <jar> <path> -> prints "STATUS|LOCATION" (body discarded).
get_resp() {
  curl -s -b "$1" -D - -o /dev/null "$BASE$2" | status_and_location
}

# post_resp <jar> <path> <data> -> prints "STATUS|LOCATION".
# SvelteKit answers form actions from a non-HTML client with a JSON
# envelope ({"type":"redirect","status":303,"location":"..."}) on HTTP 200,
# so the envelope wins over the headers when it is present.
post_resp() {
  local headers body
  headers=$(mktemp); body=$(mktemp)
  curl -s -b "$1" -X POST "$BASE$2" --data "$3" -D "$headers" -o "$body"
  local jstatus jloc
  jstatus=$(grep -oE '"status":[0-9]+' "$body" | head -1 | cut -d: -f2)
  jloc=$(grep -oE '"location":"[^"]*"' "$body" | head -1 | sed 's/^"location":"//; s/"$//')
  if [ -n "$jstatus" ]; then
    echo "${jstatus}|${jloc}"
  else
    status_and_location < "$headers"
  fi
  rm -f "$headers" "$body"
}

# contains <desc> <needle> <file>
contains() {
  if grep -qF "$2" "$3"; then pass "$1"; else fail "$1 (missing: $2)"; fi
}

# not_contains <desc> <needle> <file>
not_contains() {
  if grep -qF "$2" "$3"; then fail "$1 (unexpected: $2)"; else pass "$1"; fi
}

# login <email> <password> <jar>
login() {
  local status
  curl -s -c "$2" -X POST "$BASE/" \
    --data-urlencode "email=$1" \
    --data-urlencode "password=$3" \
    -o /dev/null
  status=$(curl -s -b "$2" -o /dev/null -w '%{http_code}' "$BASE/production")
  check "login $1" "200" "$status"
}

# set_shift <jar> — append the non-sensitive shift-preference cookie
# (equivalent to selecting a shift through the UI; no server state).
set_shift() {
  printf 'localhost\tFALSE\t/\tFALSE\t0\tbakery_shift\tmorning\n' >> "$1"
}

login "$OPERATOR_EMAIL" "$WORK/operator.jar" "$OPERATOR_PASSWORD"
login "$SUPERVISOR_EMAIL" "$WORK/supervisor.jar" "$SUPERVISOR_PASSWORD"
login "$ADMIN_EMAIL" "$WORK/admin.jar" "$ADMIN_PASSWORD"

echo "--- unauthenticated ---"
check "anon /admin -> 303 /" "303|/" "$(get_resp "" /admin)"

echo "--- operator: no /admin access ---"
check "operator /admin -> 303 /production" "303|/production" \
  "$(get_resp "$WORK/operator.jar" /admin)"
check "operator /admin/traceability -> 303 /production" "303|/production" \
  "$(get_resp "$WORK/operator.jar" /admin/traceability)"
check "operator /admin/external-orders -> 303 /production" "303|/production" \
  "$(get_resp "$WORK/operator.jar" /admin/external-orders)"

echo "--- supervisor: current role policy ---"
# NOTE: SvelteKit SSR renders the hub links as relative hrefs
# (href="./production/..."), so the needles match the rendered form.
get "$WORK/supervisor.jar" /admin "$WORK/sup_admin.html" >/dev/null
check "supervisor /admin -> 200" "200" "$(get "$WORK/supervisor.jar" /admin /dev/null)"
contains "supervisor hub: Producción sugerida card" 'href="./production/suggestions"' "$WORK/sup_admin.html"
contains "supervisor hub: Producción card" 'href="./production"' "$WORK/sup_admin.html"
contains "supervisor hub: Materias primas card" 'href="./lots"' "$WORK/sup_admin.html"
contains "supervisor hub: Pedidos externos card" 'href="./admin/external-orders"' "$WORK/sup_admin.html"
not_contains "supervisor hub hides Trazabilidad" 'href="./admin/traceability"' "$WORK/sup_admin.html"
not_contains "supervisor hub hides Recetas" 'href="./admin/recipes"' "$WORK/sup_admin.html"
check "supervisor /admin/external-orders -> 200" "200" \
  "$(get "$WORK/supervisor.jar" /admin/external-orders /dev/null)"
check "supervisor /admin/traceability -> 303 /admin/external-orders" "303|/admin/external-orders" \
  "$(get_resp "$WORK/supervisor.jar" /admin/traceability)"

echo "--- admin: all four spec cards + traceability ---"
get "$WORK/admin.jar" /admin "$WORK/admin_hub.html" >/dev/null
check "admin /admin -> 200" "200" "$(get "$WORK/admin.jar" /admin /dev/null)"
contains "admin hub: Producción sugerida card" 'href="./production/suggestions"' "$WORK/admin_hub.html"
contains "admin hub: Producción card" 'href="./production"' "$WORK/admin_hub.html"
contains "admin hub: Materias primas card" 'href="./lots"' "$WORK/admin_hub.html"
contains "admin hub: Trazabilidad card" 'href="./admin/traceability"' "$WORK/admin_hub.html"
check "admin /admin/traceability -> 200" "200" \
  "$(get "$WORK/admin.jar" /admin/traceability /dev/null)"

echo "--- back-to-Admin link on shared pages ---"
# get() prints the status; capture it and keep the body for the link checks.
st=$(get "$WORK/admin.jar" /production/suggestions "$WORK/ad_sug.html")
check "admin /production/suggestions -> 200" "200" "$st"
contains "admin suggestions: Volver a Administración" 'Volver a Administración' "$WORK/ad_sug.html"
get "$WORK/supervisor.jar" /production/suggestions "$WORK/sup_sug.html" >/dev/null
contains "supervisor suggestions: Volver a Administración" 'Volver a Administración' "$WORK/sup_sug.html"
st=$(get "$WORK/operator.jar" /production/suggestions "$WORK/op_sug.html")
check "operator /production/suggestions -> 200" "200" "$st"
not_contains "operator suggestions: no back-to-Admin link" 'Volver a Administración' "$WORK/op_sug.html"

get "$WORK/admin.jar" /lots "$WORK/ad_lots.html" >/dev/null
contains "admin lots: Volver a Administración" 'Volver a Administración' "$WORK/ad_lots.html"
get "$WORK/operator.jar" /lots "$WORK/op_lots.html" >/dev/null
not_contains "operator lots: no back-to-Admin link" 'Volver a Administración' "$WORK/op_lots.html"

echo "--- /production with shift selected ---"
set_shift "$WORK/admin.jar"
set_shift "$WORK/supervisor.jar"
set_shift "$WORK/operator.jar"
st=$(get "$WORK/admin.jar" /production "$WORK/ad_prod.html")
check "admin /production -> 200" "200" "$st"
contains "admin production: Volver a Administración" 'Volver a Administración' "$WORK/ad_prod.html"
get "$WORK/supervisor.jar" /production "$WORK/sup_prod.html" >/dev/null
contains "supervisor production: Volver a Administración" 'Volver a Administración' "$WORK/sup_prod.html"
st=$(get "$WORK/operator.jar" /production "$WORK/op_prod.html")
check "operator /production -> 200" "200" "$st"
not_contains "operator production: no back-to-Admin link" 'Volver a Administración' "$WORK/op_prod.html"
contains "operator production: ELEGIR PRODUCCIÓN (path to Suggested Production)" 'ELEGIR PRODUCCIÓN' "$WORK/op_prod.html"

echo "--- review page (stateful; cleans up) ---"
SELECTIONS_TODAY=$(docker exec -i "$DB" psql -U postgres -d postgres -q -t -A \
  -c "select count(*) from daily_production_selections d join production_days p on p.id = d.production_day_id where p.production_date = get_business_date();")
if [ "$SELECTIONS_TODAY" != "0" ]; then
  echo "SKIP: a selection already exists for today (review-page check)"
else
  SUG_ID=$(docker exec -i "$DB" psql -U postgres -d postgres -q -t -A \
    -c "select s.id from production_suggestions s join production_days p on p.id = (select id from production_days where production_date = get_business_date()) where s.active = true and s.weekday = extract(isodow from p.production_date) order by s.code limit 1;")
  if [ -z "$SUG_ID" ]; then
    echo "SKIP: no active suggestion for today (review-page check)"
  else
    r=$(post_resp "$WORK/operator.jar" /production/suggestions?/choose "suggestion_id=$SUG_ID")
    check "operator choose -> 303 /production/suggestions/review" "303|/production/suggestions/review" "$r"
    CLEANUP_SELECTION=1
    st=$(get "$WORK/admin.jar" /production/suggestions/review "$WORK/ad_rev.html")
    check "admin review -> 200" "200" "$st"
    contains "admin review: Volver a Administración" 'Volver a Administración' "$WORK/ad_rev.html"
    get "$WORK/operator.jar" /production/suggestions/review "$WORK/op_rev.html" >/dev/null
    not_contains "operator review: no back-to-Admin link" 'Volver a Administración' "$WORK/op_rev.html"
  fi
fi

if [ "$FAIL" = 0 ]; then
  echo "V6.14 role tests: all checks passed."
else
  echo "V6.14 role tests: FAILURES present."
fi
exit "$FAIL"

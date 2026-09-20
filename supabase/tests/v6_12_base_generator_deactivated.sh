#!/usr/bin/env bash
# V6.12 (spec §61) behavior tests: the legacy base generator is deactivated.
#
# ensure_base_production_requests must no longer create 'base' production
# requests from production_plan_items (the confirmed daily suggestion via
# confirm_daily_production is the sole source of base production), while its
# signature, auth gates, day validation and return type stay intact so
# existing callers keep working.
#
# The repository has no DB-test framework (vitest unit tests only), so these
# focused database tests follow the established V6 pattern: each negative
# case runs in its own aborted transaction; the positive flow runs in a
# transaction that is rolled back at the end. Nothing persists.
#
# Coverage (spec §61):
#   * not_authenticated / no_active_profile / production_day_not_found
#     tokens preserved;
#   * a valid plan item for the current business weekday NO LONGER creates a
#     base request (the old behavior would have created one);
#   * the function returns integer 0;
#   * the legacy planning table production_plan_items still exists (spec: do
#     not remove legacy planning tables);
#   * the function still has the (uuid) -> integer signature.
#
# Usage: bash supabase/tests/v6_12_base_generator_deactivated.sh
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

DAY_ID="(select id from public.production_days where production_date = public.get_business_date())"
# A product with NO active committed plan item for (today's weekday,
# 'morning', 'lata'), so the inserted fixture cannot collide with the
# partial unique index (weekday, shift_code, product_id, unit) where active.
PRODUCT_ID="(select p.id from public.products p where not exists (select 1 from public.production_plan_items i where i.active and i.weekday = extract(isodow from public.get_business_date())::smallint and i.product_id = p.id and i.shift_code = 'morning' and i.unit = 'lata') order by p.id limit 1)"

# ---- negative cases (each in its own aborted transaction) ----
check "not_authenticated" \
  "not_authenticated" \
  "$(token "select public.ensure_base_production_requests($DAY_ID);")"

check "no_active_profile" \
  "no_active_profile" \
  "$(token "$(jset 99999999-9999-9999-9999-999999999999) select public.ensure_base_production_requests($DAY_ID);")"

check "production_day_not_found" \
  "production_day_not_found" \
  "$(token "$(jset $OPERATOR) select public.ensure_base_production_requests('99999999-9999-9999-9999-999999999999'::uuid);")"

# ---- positive flow (one rolled-back transaction) ----
OUT=$(run "
$(jset $OPERATOR)
insert into public.production_days (production_date, status, opened_at, opened_by)
  values (public.get_business_date(), 'open', now(), '$OPERATOR')
  on conflict (production_date) do nothing;
-- A plan item that the OLD generator would have turned into a base request
-- for the current business weekday (morning, first product, qty 5).
insert into public.production_plan_items
  (weekday, shift_code, product_id, planned_quantity, unit, sort_order, active)
  values (extract(isodow from public.get_business_date())::smallint, 'morning', $PRODUCT_ID, 5, 'lata', 99, true);
-- Snapshot the day's request counts, then call the deactivated generator in
-- the same statement: deltas are data-independent (committed rows for the
-- day, if any, cancel out).
with base_before as (
  select count(*) bc from public.production_requests
  where production_day_id = (select id from public.production_days where production_date = public.get_business_date())
    and source_type = 'base'
), all_before as (
  select count(*) ac from public.production_requests
  where production_day_id = (select id from public.production_days where production_date = public.get_business_date())
)
select 'ret=' || public.ensure_base_production_requests($DAY_ID)
  || ' delta_base=' || (
     select (select count(*) from public.production_requests
             where production_day_id = (select id from public.production_days where production_date = public.get_business_date())
               and source_type = 'base') - bc)
  || ' delta_all=' || (
     select (select count(*) from public.production_requests
             where production_day_id = (select id from public.production_days where production_date = public.get_business_date())) - ac)
from base_before, all_before;
")

check "returns_zero" "ret=0" "$(echo "$OUT" | grep -oE 'ret=[0-9]+' | head -1)"
check "no_base_request_created" "delta_base=0" "$(echo "$OUT" | grep -oE 'delta_base=-?[0-9]+' | head -1)"
check "no_request_of_any_source_created" "delta_all=0" "$(echo "$OUT" | grep -oE 'delta_all=-?[0-9]+' | head -1)"

# ---- structural checks (read-only, committed state) ----
check "legacy_plan_table_still_exists" \
  "1" \
  "$(docker exec -i "$DB" psql -U postgres -d postgres -t -A -c "select count(*) from information_schema.tables where table_schema = 'public' and table_name = 'production_plan_items';")"

check "signature_uuid_to_integer" \
  "public.ensure_base_production_requests(p_production_day_id uuid)integer" \
  "$(docker exec -i "$DB" psql -U postgres -d postgres -t -A -c "select n.nspname || '.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')' || pg_get_function_result(p.oid) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where p.proname = 'ensure_base_production_requests';")"

exit $FAIL

# SECURITY.md — Bakery Traceability

Write-access model for the bakery traceability MVP. Keep this file current when
RLS policies, grants, or RPCs change.

## Key handling

- The browser app only ever uses the Supabase **publishable** key
  (`PUBLIC_SUPABASE_PUBLISHABLE_KEY`) through `@supabase/ssr` (cookie-based
  session, server-side client in `src/lib/supabase/server.ts`).
- `service_role` is never bundled into, sent to, or referenced by client code.
  It is only used server-side (migrations, seed scripts, admin API operations).

## Roles

- Auth: Supabase email/password. One app role per user in `profiles.role`:
  `operator`, `supervisor`, `admin` (check-constrained). `profiles.active`
  gates all data access.
- Authorization lives in server/database security. Hiding a button in the UI is
  never authorization.

## Row Level Security (current state)

- RLS is **enabled on all 21 business tables** (never disable it; verify in
  `pg_class.relrowsecurity`).
- The only policies are **SELECT-only**, granted to the `authenticated`
  Postgres role, and gated on the requesting user having an active profile:

  | Scope            | Tables                                                                                                                                                                           | Policy pattern                                                                         |
  | ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
  | Master data (U1) | raw_materials, brands, raw_material_brands, material_lots, products, recipes, recipe_versions, recipe_ingredients, recipe_products, recipe_product_inputs, production_plan_items | `FOR SELECT TO authenticated USING (exists (… profiles … id = auth.uid() and active))` |
  | Operational (U2) | production_days, production_requests, production_batches, batch_materials, batch_outputs, batch_requests, parent_batch_inputs, external_orders, external_order_items             | same pattern                                                                           |
  | Profiles (U1)    | profiles                                                                                                                                                                         | `FOR SELECT TO authenticated USING (id = auth.uid())` (own row; not recursive)         |

- There are **no INSERT/UPDATE/DELETE policies on any business table**.
  Authenticated users hold DML grants but RLS denies every direct write.
  An operator cannot rewrite traceability history through the client — or at
  all — while this state holds.

## Controlled write strategy

Mutations that matter for traceability must go through narrow, transactional
operations (SECURITY DEFINER RPCs), not browser table writes:

| Area                  | Controlled operation(s)                                                                  | Status        |
| --------------------- | ---------------------------------------------------------------------------------------- | ------------- |
| Business date         | `get_business_date()`                                                                    | created (X0)  |
| Production day        | `ensure_production_day(...)`                                                             | created (X1)  |
| Base requests         | `ensure_base_production_requests(...)`                                                   | created (Y1)  |
| External requests     | `ensure_external_order_requests(...)`                                                    | created (Z1)  |
| Additional requests   | `create_additional_production_request(...)`                                              | created (AB1) |
| Batch code            | `next_batch_code(...)`                                                                   | created (AD1) |
| Material lot change   | `change_current_material_lot(...)`                                                       | created (W2)  |
| Batch lifecycle       | `start_production_batch(...)`                                                            | created (AF1) |
| Batch completion      | `complete_production_batch(...)`                                                         | created (AI1) |
| External orders       | `create_external_order(...)`                                                             | created (AK2) |
| External order items  | `add_external_order_item(...)`                                                           | created (AK3) |
| Raw materials (admin) | `create_raw_material(...)` / `update_raw_material(...)` / `set_raw_material_active(...)` | created (AL1) |
| Brands (admin)        | `create_brand(...)` / `update_brand(...)` / `set_brand_active(...)`                      | created (AL2) |

Until the remaining RPCs exist, the write paths are the controlled operations
above plus the server-side (service role) path used by migrations and seed
scripts.

Table mutation classification:

- **Immutable traceability history** (append-mostly, never UPDATE/DELETE):
  `batch_materials`, `batch_outputs`, `batch_requests`, `parent_batch_inputs`,
  `production_batches` (once started), `recipe_versions`,
  `recipe_ingredients`, `recipe_products`, `recipe_product_inputs`.
- **Controlled operational state**: `production_days` (creation only through
  `ensure_production_day`), `production_requests`, `material_lots` (`is_current`
  switch only through `change_current_material_lot`), `production_batches`.
- **Master data** (admin UI since AL1 for `raw_materials` and AL2 for `brands`;
  no browser write path for the rest): `raw_materials` (admin-controlled
  create/edit/soft-deactivate since AL1), `brands` (admin-controlled
  create/edit/soft-deactivate since AL2; names are NOT uniqueness-constrained —
  the F2 spec requires only a non-empty name, so duplicate names are allowed),
  `raw_material_brands`, `products`, `recipes`,
  `production_plan_items`. `external_orders` and `external_order_items` have
  controlled creation RPCs since AK2/AK3 (header + items; no editing/cancel yet).

## RPC security checklist (applies to every future function)

- Choose SECURITY INVOKER / DEFINER deliberately; document the reason.
- SECURITY DEFINER functions must:
  - require `auth.uid()` to be non-null,
  - validate the caller's `profiles` row is `active` (and role where needed),
  - set an explicit safe `search_path`,
  - `REVOKE EXECUTE FROM PUBLIC` (and from the app roles, see the U4 finding
    below), and
  - `GRANT EXECUTE` only to the minimum required Postgres role.
- Never trust UI-hidden controls; every authorization check is in the database
  or server layer.

## Audit (U4, updated in W2, X0, X1, Y1, Z1, AB1, AD1, AF1, AI1, AK2, AK3, AL1 and AL2)

Functions in schema `public` (current state):

| Function                                                                            | Kind                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | Security                                                                                                                       | Execute granted to                 |
| ----------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------- |
| `reject_parent_batch_self_reference()`                                              | BEFORE INSERT/UPDATE trigger guard on `parent_batch_inputs` (a batch cannot consume its own output)                                                                                                                                                                                                                                                                                                                                                                                                                          | INVOKER (deliberate: pure read-only guard)                                                                                     | `postgres` (owner), `service_role` |
| `change_current_material_lot(uuid, uuid, text, date)`                               | Controlled write RPC: atomically closes the prior current lot of a raw material and creates the new one (in_use, is_current)                                                                                                                                                                                                                                                                                                                                                                                                 | DEFINER (deliberate: performs close/insert no app role may do; all auth checks in-body)                                        | `authenticated` only               |
| `get_business_date()`                                                               | Read-only helper: current date in `America/Argentina/Cordoba`, single source for `production_date`                                                                                                                                                                                                                                                                                                                                                                                                                           | INVOKER (deliberate: no writes, no privilege escalation)                                                                       | `authenticated` only               |
| `ensure_production_day()`                                                           | Controlled write RPC: idempotently creates the current business production day (status open) or returns the existing one                                                                                                                                                                                                                                                                                                                                                                                                     | DEFINER (deliberate: performs the insert no app role may do; all auth checks in-body)                                          | `authenticated` only               |
| `ensure_base_production_requests(uuid)`                                             | Controlled write RPC: idempotently creates `source_type=base` requests from the active weekly plan of the stored date's weekday                                                                                                                                                                                                                                                                                                                                                                                              | DEFINER (deliberate: performs the inserts no app role may do; all auth checks in-body)                                         | `authenticated` only               |
| `ensure_external_order_requests(uuid)`                                              | Controlled write RPC: idempotently creates `source_type=external_order` requests from the non-cancelled external orders of the stored date                                                                                                                                                                                                                                                                                                                                                                                   | DEFINER (deliberate: performs the inserts no app role may do; all auth checks in-body)                                         | `authenticated` only               |
| `create_additional_production_request(uuid, uuid, numeric, text, text, text, text)` | Controlled write RPC: creates one `source_type=additional`, `status=pending` request with a required `reason_code` (non-empty `reason_note` when `other`); returns the new request id                                                                                                                                                                                                                                                                                                                                        | DEFINER (deliberate: performs the insert no app role may do; all auth checks in-body)                                          | `authenticated` only               |
| `start_production_batch(uuid)`                                                      | Controlled write RPC: atomic all-or-nothing batch start for one pending request — auth/profile check, active recipe resolution, required current-lot validation (`missing_material_lot: <names>`), in-transaction safe code via `next_batch_code`, exact lot snapshot into `batch_materials`, request link + status advance; request row locked `FOR UPDATE` against concurrent double-starts                                                                                                                                | DEFINER (deliberate: performs batch/batch_materials/batch_requests/request writes no app role may do; all auth checks in-body) | `authenticated` only               |
| `complete_production_batch(uuid, numeric, text)`                                    | Controlled write RPC: atomic all-or-nothing completion of an in-progress single-product batch — auth/profile check, batch row locked `FOR UPDATE` (concurrent completion fails with `batch_not_in_progress`), actual quantity/unit validation, `batch_outputs` insert, batch `completed` + `finished_at`/`finished_by`, linked request `completed`, `allocated_quantity` backfill only when null; never modifies `batch_materials`                                                                                           | DEFINER (deliberate: performs batch/request/output writes no app role may do; all auth checks in-body)                         | `authenticated` only               |
| `create_external_order(text, text, date, text, text)`                               | Controlled write RPC: creates one `external_orders` header (status `pending`, `created_by` = acting user, returns the new order id) — auth/profile check, supervisor/admin role check (`insufficient_role` otherwise), trimmed non-empty order number + customer name, non-null requested date, optional delivery time (blank → null, invalid format → `invalid_delivery_time`), duplicate number → `order_number_exists`                                                                                                    | DEFINER (deliberate: performs the external_orders write no app role may do; all auth checks in-body)                           | `authenticated` only               |
| `add_external_order_item(uuid, uuid, numeric, text, text, text)`                    | Controlled write RPC: adds one product item to an existing external order (returns the new item id) — auth/profile check, supervisor/admin role check (`insufficient_role` otherwise), order must exist (`order_not_found`), product must exist and be active (`product_not_available`), positive quantity (`invalid_quantity`), non-empty unit (`invalid_unit`), shift in morning/afternoon/night (`invalid_shift`); the submitted final shift is stored verbatim and never recalculated from `products.default_shift_code` | DEFINER (deliberate: performs the external_order_items write no app role may do; all auth checks in-body)                      | `authenticated` only               |
| `next_batch_code(uuid, text)`                                                       | Read-only helper: next `PAN-DDMMYY-X-NNN` batch code from the stored `production_date`; sequence resets by `production_date + shift_code`; transaction-scoped advisory lock (per day+shift) makes generate-then-insert in one transaction concurrency-safe                                                                                                                                                                                                                                                                   | INVOKER (deliberate: no writes of its own, no privilege escalation; the calling RPC keeps its authorization checks)            | `authenticated` only               |
| `create_raw_material(text, text)`                                                   | Controlled write RPC (admin master data): trims name/unit, rejects blanks (`invalid_name`, `invalid_unit`), case-insensitive name uniqueness (`raw_material_name_exists`); inserts `raw_materials`; admin-only in-body gate (`insufficient_role` for operator/supervisor)                                                                                                                                                                                                                                                    | DEFINER (deliberate: performs the raw_materials insert no app role may do; all auth checks in-body)                            | `authenticated` only               |
| `update_raw_material(uuid, text, text)`                                             | Controlled write RPC (admin master data): material must exist (`raw_material_not_found`); trims name/unit, rejects blanks (`invalid_name`, `invalid_unit`); case-insensitive name uniqueness excluding the row itself (`raw_material_name_exists`); updates name/default_unit/updated_at; admin-only in-body gate (`insufficient_role`)                                                                                                                                                                                      | DEFINER (deliberate: performs the raw_materials update no app role may do; all auth checks in-body)                            | `authenticated` only               |
| `set_raw_material_active(uuid, boolean)`                                            | Controlled write RPC (admin master data): material must exist (`raw_material_not_found`); soft toggle of `active` (deactivation sets `active = false`; never a physical delete, because `material_lots`, `batch_materials`, `raw_material_brands` and `recipe_ingredients` reference `raw_materials` with RESTRICT FKs); admin-only in-body gate (`insufficient_role`)                                                                                                                                                       | DEFINER (deliberate: performs the raw_materials update no app role may do; all auth checks in-body)                            | `authenticated` only               |
| `create_brand(text)`                                                                | Controlled write RPC (admin master data): trims name, rejects blanks (`invalid_name`); inserts `brands`. Brand names are NOT uniqueness-constrained (the F2 spec requires only a non-empty name, unlike raw_materials) — duplicate names are allowed by design; admin-only in-body gate (`insufficient_role`)                                                                                                                                                                                                                | DEFINER (deliberate: performs the brands insert no app role may do; all auth checks in-body)                                   | `authenticated` only               |
| `update_brand(uuid, text)`                                                          | Controlled write RPC (admin master data): brand must exist (`brand_not_found`); trims name, rejects blanks (`invalid_name`); updates name/updated_at; no uniqueness check (see `create_brand`); admin-only in-body gate (`insufficient_role`)                                                                                                                                                                                                                                                                                | DEFINER (deliberate: performs the brands update no app role may do; all auth checks in-body)                                   | `authenticated` only               |
| `set_brand_active(uuid, boolean)`                                                   | Controlled write RPC (admin master data): brand must exist (`brand_not_found`); soft toggle of `active` (deactivation sets `active = false`; never a physical delete, because `material_lots` and `raw_material_brands` reference `brands` with RESTRICT FKs); admin-only in-body gate (`insufficient_role`)                                                                                                                                                                                                                 | DEFINER (deliberate: performs the brands update no app role may do; all auth checks in-body)                                   | `authenticated` only               |

Findings applied by migration `20260911050000_rpc_security_hardening.sql`:

- Supabase's default privileges **explicitly grant EXECUTE to `anon`,
  `authenticated` and `service_role` for every function `postgres` creates**
  (visible in `pg_proc.proacl`), independent of `PUBLIC`.
- The trigger guard lost EXECUTE for `anon` and `authenticated`; it is only
  executable by the role that can write `parent_batch_inputs` (the trigger
  fires with the privileges of the inserting role).
- Rule for every future RPC migration: include explicit `REVOKE EXECUTE` for
  `anon`/`authenticated` (and `PUBLIC`) and grant only the minimum role. If a
  role needs to fire the trigger by writing the table, that same migration
  must grant EXECUTE explicitly.

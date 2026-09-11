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

| Area                | Controlled operation(s)                                         | Status                      |
| ------------------- | --------------------------------------------------------------- | --------------------------- |
| Business date       | `get_business_date()`                                           | created (X0)                |
| Production day      | `ensure_production_day(...)`                                    | created (X1)                |
| Base requests       | `ensure_base_production_requests(...)`                          | created (Y1)                |
| External requests   | `ensure_external_order_requests(...)`                           | created (Z1)                |
| Material lot change | `change_current_material_lot(...)`                              | created (W2)                |
| Batch lifecycle     | `start_production_batch(...)`, `complete_production_batch(...)` | to be created (later phase) |

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
- **Master data** (admin UI in later phases; no browser write path today):
  `raw_materials`, `brands`, `raw_material_brands`, `products`, `recipes`,
  `production_plan_items`, `external_orders`, `external_order_items`.

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

## Audit (U4, updated in W2, X0, X1, Y1 and Z1)

Functions in schema `public` (current state):

| Function                                              | Kind                                                                                                                                       | Security                                                                                | Execute granted to                 |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------- | ---------------------------------- |
| `reject_parent_batch_self_reference()`                | BEFORE INSERT/UPDATE trigger guard on `parent_batch_inputs` (a batch cannot consume its own output)                                        | INVOKER (deliberate: pure read-only guard)                                              | `postgres` (owner), `service_role` |
| `change_current_material_lot(uuid, uuid, text, date)` | Controlled write RPC: atomically closes the prior current lot of a raw material and creates the new one (in_use, is_current)               | DEFINER (deliberate: performs close/insert no app role may do; all auth checks in-body) | `authenticated` only               |
| `get_business_date()`                                 | Read-only helper: current date in `America/Argentina/Cordoba`, single source for `production_date`                                         | INVOKER (deliberate: no writes, no privilege escalation)                                | `authenticated` only               |
| `ensure_production_day()`                             | Controlled write RPC: idempotently creates the current business production day (status open) or returns the existing one                   | DEFINER (deliberate: performs the insert no app role may do; all auth checks in-body)   | `authenticated` only               |
| `ensure_base_production_requests(uuid)`               | Controlled write RPC: idempotently creates `source_type=base` requests from the active weekly plan of the stored date's weekday            | DEFINER (deliberate: performs the inserts no app role may do; all auth checks in-body)  | `authenticated` only               |
| `ensure_external_order_requests(uuid)`                | Controlled write RPC: idempotently creates `source_type=external_order` requests from the non-cancelled external orders of the stored date | DEFINER (deliberate: performs the inserts no app role may do; all auth checks in-body)  | `authenticated` only               |

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

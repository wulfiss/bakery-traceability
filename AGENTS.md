# AGENTS.md — Bakery Traceability

Non-negotiable rules for every agent working in this repository.

## Stack

- SvelteKit + Svelte 5 + TypeScript (strict, SSR by default).
- Supabase PostgreSQL + Auth + RLS (configured in later phases).
- No ORM (no Prisma, no Drizzle). Plain Supabase JS client and SQL migrations.
- SvelteKit Form Actions for normal writes; `use:enhance` only when it improves mobile UX.
- Mobile-first: primary target width 360px–430px.

## Language rules

- All development and internal naming uses **English**: tables, columns, TypeScript
  names, functions, RPC names, filenames, routes, comments, migrations, tests,
  internal enum/check values, developer logs, technical documentation.
- All end-user-visible UI text is **hardcoded Spanish**.
- Real bakery product names remain in Spanish (they are business data).
- **No i18n** (no Paraglide, i18next, svelte-i18n, locale routing, translation catalogs).

## Business timezone

- Fixed business timezone: `America/Argentina/Cordoba`.
- Never derive `production_date` from UTC, `toISOString()`, browser timezone,
  Node process timezone, or the database session timezone.
- Use `get_business_date()` (PostgreSQL), then the stored `production_days.production_date`.
  Downstream operations (weekday, batch-code date) use the stored date, never a
  recalculated "today".

## Production shifts

- Exactly three internal shift codes: `morning`, `afternoon`, `night`.
- Spanish UI labels: `MAÑANA`, `TARDE`, `NOCHE`.
- The operator selects the shift once when entering Production; it is persisted as a
  non-sensitive UI preference (cookie `bakery_shift`) and is **never** authorization.
- No formal shift sessions: no clock-in/clock-out, no attendance, no
  start/end time configuration, no `shift_sessions` table.
- Never infer the shift from the current time.
- Historical shift is copied into `production_requests` and `production_batches`;
  a later change to `products.default_shift_code` must never rewrite history.

## Production sources

- Exactly three internal `source_type` values: `base`, `external_order`, `additional`.
- `base` comes from the weekly plan (weekday + shift + product + planned quantity).
- `external_order` items carry an assigned shift (defaulted from the product,
  overridable by supervisor/admin).
- `additional` defaults to the currently selected shift and requires `reason_code`
  (`replenishment`, `increased_demand`, `remake`, `other`); `other` also requires a
  non-empty `reason_note`. For `base` and `external_order`, reason fields are null.

## Traceability rules

- Recipes are versioned; a recipe may have at most one `active` version
  (enforced by a partial unique index).
- A recipe can produce one or multiple products; a produced item can later be an
  input for another batch.
- At most one material lot may be `is_current = true` per raw material
  (partial unique index).
- When a batch starts, copy the exact current material lots into `batch_materials`
  (append-mostly / immutable).
- Never reconstruct historical traceability from `material_lots.is_current`.
- Production records are never physically deleted; use `active = false`,
  `status = cancelled`, `status = closed`, `status = retired`.
- Batch code format: `PAN-DDMMYY-X-NNN` where X is `M` (morning), `T` (afternoon),
  `N` (night). Sequence resets by `production_date + shift_code`. Generation must be
  concurrency-safe (no plain `count(*) + 1`).

## Security

- Keep RLS enabled on all business tables.
- Never put `service_role` in browser code.
- Critical production writes use narrow controlled transactional operations/RPCs
  (e.g. `change_current_material_lot`, `ensure_production_day`,
  `start_production_batch`, `complete_production_batch`), not unrestricted client
  table writes.
- `SECURITY DEFINER` RPCs must require `auth.uid()`, validate the active profile,
  validate role where needed, use an explicit safe `search_path`, revoke execution
  from `PUBLIC`, and grant only the minimum role needed.
- Roles: `operator`, `supervisor`, `admin`. Authorization lives in server/database
  security; hiding a button is not authorization.

## MVP exclusions

- No AI features in the final app (the LLM is only a development tool).
- No Realtime, no offline write synchronization, no QR/barcode yet.
- No complex dashboards, no HACCP module, no cooking-temperature module,
  no full nonconformity system, no ERP integration, no accounting stock,
  no purchasing, no invoicing.
- No multi-site support, no Capacitor native wrapper yet.

## Working rules

- Work only on the requested baby step; never "build the whole application".
- Inspect relevant files and git status/diff before editing.
- No unrelated refactors, no package upgrades, no architecture changes,
  no unrequested dependencies.
- Prefer simple code; keep business logic out of Svelte UI components when practical.
- Run the relevant checks after changes (`npm run check`, `npm run build`,
  `npm run lint`, `npm test`); fix any regression introduced before moving on.
- Never ignore failing checks.
- If business information is missing and is not required for the current step,
  do not invent it — leave code unchanged and report the exact missing decision.
- End each step with a short report (files created/modified, commands executed,
  verification results, remaining items), then STOP.

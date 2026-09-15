# AGENTS.md — Bakery Traceability

Non-negotiable rules for every agent working in this repository.

## Stack

- SvelteKit + Svelte 5 + TypeScript (strict, SSR by default).
- Supabase PostgreSQL + Auth + RLS (configured in later phases).
- No ORM (no Prisma, no Drizzle). Plain Supabase JS client and SQL migrations.
- SvelteKit Form Actions for normal writes; `use:enhance` only when it improves mobile UX.
- Mobile-first: primary target width 360px–430px.
- Supabase selects: in this toolchain (supabase-js 2.116 under TypeScript 6) the inferred
  select result type does not resolve in `svelte-check`, so `await`ed results must have their
  `.data` explicitly annotated with the selected shape from `src/lib/types/database.types.ts`
  (e.g. `const lots: Pick<Database['public']['Tables']['material_lots']['Row'], 'id' | ...>[] =
(await supabase.from('material_lots').select('id, ...')).data ?? []`).
  `Promise.all` around builders loses the types as well — await queries sequentially.
  `.returns()`/`.overrideTypes()` do not help (they inherit the unresolved type).

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

- Operational shifts are `morning` and `night` only: every new request, batch,
  plan item, product default and external order item must use one of these two
  codes. `afternoon` survives only in pre-V5 history (the shift CHECK
  constraints were re-added `NOT VALID`, so historical rows keep their code).
- Spanish UI labels: `MAÑANA`, `TARDE`, `NOCHE`. `TARDE` remains in the
  display-only label maps for historical rows; no new UI offers it.
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
- `additional` defaults to the currently selected shift. Since V5.7 the UI no
  longer asks for a reason and new additional requests save
  `reason_code = NULL` / `reason_note = NULL`. The columns stay nullable for
  backward compatibility (historical rows keep their reasons); the RPC still
  accepts an optional reason — a provided code must be one of
  `replenishment`, `increased_demand`, `remake`, `other`, and `other` still
  requires a non-empty `reason_note`. For `base` and `external_order`, reason
  fields are null.

## Routing

- The login form lives at the root route `/`. `/login` is redirect-only:
  to `/production` when the visitor is authenticated, to `/` otherwise.
- Authenticated visitors hitting `/` are redirected to `/production`; the
  `(protected)` route group redirects unauthenticated visitors to `/`.

## Traceability rules

- Recipes are versioned; a recipe may have at most one `active` version
  (enforced by a partial unique index).
- A recipe can produce one or multiple products; a produced item can later be an
  input for another batch.
- Multiple material lots of the same raw material may be `is_current = true`
  at once (the single-current-lot partial unique index was dropped in V5.5).
  `change_current_material_lot` still closes the other current lots of the
  material when it opens a new one; `add_material_lot` opens a new current
  lot without closing the others (that is how coexistence arises);
  `use_other_material_lot` is the mid-batch "use another lot" path.
- The operator adds material lots from the production screens (a new lot from
  `/production` for a batch in progress; current-lot management from `/lots`)
  through those controlled RPCs — never through direct table writes.
- When a batch starts, copy the exact current material lots into `batch_materials`
  (append-mostly / immutable). A lot opened mid-batch is appended to the
  running batch's `batch_materials`; the rows recorded earlier are never
  rewritten.
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

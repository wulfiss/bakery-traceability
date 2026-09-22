# Bakery Traceability — Progress Report (what was built, what is left)

> Generated: after the previous session ended (latest commit `8f02eee`, Sep 21 12:07).
> App: `bakery-traceability` — SvelteKit + Svelte 5 + TypeScript, Supabase (PostgreSQL + Auth + RLS), Spanish hardcoded UI, English internal identifiers, mobile-first.

---

## 1. What was built so far

### 1.1 Baseline (pre-V5 phases, all committed)

From the git history, the MVP baseline is fully in place and accepted:

- **Auth & roles** — Supabase Auth, login form at `/` (root route), `/login` redirect-only, role authorization (`operator` / `supervisor` / `admin`) enforced in server route guards (Phase AT).
- **Production flow** — `/production` grouped by product with per-source contributions and totals (AN1); MAÑANA / NOCHE shift views (cookie `bakery_shift`, never authorization).
- **Batches & traceability** — `start_production_batch` / `complete_production_batch` RPCs with concurrency-safe batch codes `PAN-DDMMYY-X-NNN`; multi-output completion (AO1–AO3); source-lot selection in the UI (AP1–AP2); backward traceability search (AQ) and forward traceability by supplier lot (AR), both in `/admin/traceability`.
- **Material lots** — `add_material_lot`, `change_current_material_lot`, `use_other_material_lot` RPCs; multiple current lots per raw material coexist (V5.5); missing-lot recovery "AGREGAR LOTE" with preselected material (V5.4); lots added directly from `/production` (V5.3); `batch_materials` append-mostly / immutable.
- **Admin CRUD** — products, recipes (versioned, one active), planning (AL3–AL5); import review CSVs for products, raw materials/brands, recipes, mapping, planning (AM1–AM3).
- **PWA** — manifest, icons, service worker, offline banner (AS).

### 1.2 V5 change set (committed, accepted)

- **V5.2** — retired the `afternoon` (TARDE) shift for new operations; history preserved (CHECK constraints re-added `NOT VALID`).
- **V5.5** — link additional material lots to a batch in progress.
- **V5.6** — login moved to `/`, `/login` redirect-only.
- **V5.7** — additional production without mandatory reason.
- **V5.8** — docs (AGENTS.md / SECURITY.md) and generated types re-verified.
- **V5.9** — acceptance: shifts invariant + E2E, all 7 tests PASS.

### 1.3 V6 — Suggested Production (committed, accepted at V6.16)

All 16 baby steps of `BAKERY_TRACEABILITY_MVP_V6_SUGGESTED_PRODUCTION_DSH.md` were implemented:

| Step | What was built |
|---|---|
| V6.1–V6.2 | Migration preflight and baseline resolution. |
| V6.3 | Admin navigation entries (Producción sugerida, Producción, Materias primas, Trazabilidad). |
| V6.4 | Master template tables `production_suggestions` / `production_suggestion_items` + RLS. |
| V6.5 | Daily snapshot tables `daily_production_selections` / `daily_production_selection_items` + RLS. |
| V6.6 | Workbook → review CSV extraction (`data/import-review-v6/`): 25 option templates, 344 item rows, ambiguities CSV for Saturday "PARA LA TARDE". |
| V6.7 | Reviewed seeding of templates via admin-only `seed_v6_suggestion_templates` (241 payload items; Sunday never invented). |
| V6.8 | `choose_daily_production_suggestion` RPC (operator/supervisor/admin, shared daily selection, change-safe). |
| V6.9 | Suggestion preview page (`/production/suggestions`) showing products + quantities of every option **before** selection. |
| V6.10 | Review UI with check/uncheck (`toggle_daily_selection_item`), daily snapshot only, templates untouched. |
| V6.11 | `confirm_daily_production` RPC generating the day's `base` requests from the confirmed snapshot. |
| V6.12 | `/production` integration; legacy weekly-plan generator `ensure_base_production_requests` deactivated (no-op). |
| V6.13 | Safe suggestion change **after** confirmation: started/completed lines locked and byte-identical, pending lines reconciled (quantity update / history-safe cancel / new lines added), external + additional sources untouched. |
| V6.14 | Final admin access integration (all four cards reuse existing routes/RPCs; operator /admin still guarded). |
| V6.15 | Types regenerated; AGENTS.md / SECURITY.md updated for the V6 rules. |
| V6.16 | Acceptance suite TEST 1–15 (committed, evidence in `v6_16_acceptance_run*.log`). |

**Acceptance status (latest run, `v6_16_acceptance_run9.log`, Sep 21 12:06):**

```text
TEST 1 … TEST 15: PASS
V6 ACCEPTANCE SUITE: ALL TESTS PASS
```

Quality gates at that point were clean: `npm run check`, `npm test`, `npm run build`, `npm run lint` all exit 0 (evidence: `v616_npm_checks.log`).

---

## 2. What was left unfinished in the previous session

### 2.1 V6.17 — in progress, **uncommitted**, not verified

After the V6.16 acceptance passed, a new unrequested step (marked "V6.17" in code comments) was started and **left in the working tree** (files modified Sep 21 15:37–15:49, after the last clean quality-gate run):

What already exists in the working tree:

- **New page `/production/new-lot`** (`+page.svelte` + `+page.server.ts`, untracked): add a material lot from its own page, with material/brand options, `?material=<id>` preselection from the missing-lot recovery, and redirect back to `/production` on success.
- **`/production` (`+page.svelte`, modified)**: the old inline "AGREGAR MATERIA PRIMA" form was removed and replaced by a link to `/production/new-lot`; running batches now show an "EN PRODUCCIÓN" link to their batch detail; completed ones show "COMPLETADO".
- **Batch detail (`[batchId]/+page.svelte`, modified)**: "IR A PRODUCCIÓN" back link.
- **Suggestions review (`suggestions/review/+page.server.ts`, modified)**: after CONFIRMAR PRODUCCIÓN the operator is redirected (303) to `/production`.

What is **not done** for V6.17:

1. **Dead code still in `/production/+page.server.ts`**: the `openLot` and `addLot` actions (and the `message` / `addLotOpen` form-state plumbing they feed) remain, although the UI no longer calls them. They should be removed (the add-lot logic now lives on the new page).
2. **Quality gates not re-run** after the V6.17 edits (`npm run check`, `npm test`, `npm run build`, `npm run lint`).
3. **No acceptance/E2E re-run** of the lot-addition flow (V5 regression TEST 15 covered the old inline form; the flow now goes through `/production/new-lot`).
4. **Nothing committed** — `git status` shows 3 modified files + the untracked `new-lot/` directory (plus the pre-existing untracked `.pre-v52-backup.sql` backup artifact).

### 2.2 Human review still required (by design, never auto-resolved)

- **Saturday "PARA LA TARDE" rows** — shift-ambiguous source rows that were **never** imported as morning/night (verified by acceptance TEST 13: zero template rows contain them; they remain flagged in `data/import-review-v6/production_suggestion_ambiguities.csv` with `shift_candidate=null`, do-not-infer). They need an **explicit human decision** before they can be included in any template.
- **`review_required` item rows** — 319 of the 344 extracted item rows in `production_suggestion_items.csv` are marked `review_required` (241 were seeded from the reviewed payload per `seed_summary.txt`). The remaining rows stay unresolved until explicitly reviewed.
- These are spec-mandated stop points (V6 §46–47, §6), not defects — no agent should "fix" them without a human decision.

### 2.3 Explicitly out of scope for V6 (not unfinished work)

- **No template editor** in V6 (spec §48) — templates are imported only, read-only in the app.
- Realtime, AI features, offline production writes, inventory subtraction, attendance, QR/barcode, HACCP, multi-site — all MVP exclusions per AGENTS.md.
- Per spec §71 (stop condition), **V6 itself is complete** as of the committed V6.16 acceptance; V6.17 is an extra improvement that began after that.

---

## 3. Recommended next steps (to resume where the previous session stopped)

1. Finish V6.17 cleanup: delete the unused `openLot`/`addLot` actions and `message`/`addLotOpen` state from `src/routes/(protected)/production/+page.server.ts` (and its now-dead `addLotErrorMessages` helper if fully orphaned).
2. Run the quality gates: `npm run check`, `npm test`, `npm run build`, `npm run lint`.
3. Manually verify the new lot flow end-to-end: missing-lot recovery on `/production` → `/production/new-lot?material=…` → lot created → back on `/production` → INICIAR succeeds; plus "EN PRODUCCIÓN" link from the list to the batch page and the CONFIRMAR → `/production` redirect.
4. Commit V6.17 as its own phase commit (evidence: check/build/lint output), following the repo's "one baby step, then STOP" rule.
5. (Only with a human decision) resolve the Saturday "PARA LA TARDE" ambiguities and the remaining `review_required` rows, then re-seed if needed.

---

## 4. Evidence files

| File | What it shows |
|---|---|
| `bakery-traceability/.git` log | All committed phases (V1→AT, V5.2→V5.9, V6.1→V6.16). |
| `v6_16_acceptance_run9.log` | Full V6 acceptance suite, 15/15 PASS (latest run). |
| `v616_npm_checks.log` | check/test/build/lint all exit 0 (pre-V6.17). |
| `BAKERY_TRACEABILITY_MVP_V6_SUGGESTED_PRODUCTION_DSH.md` | V6 spec, baby steps, acceptance tests, stop condition. |
| `bakery-traceability/data/import-review-v6/` | Workbook extraction: suggestions, items (319 review_required), ambiguities CSV, seed payload + summary. |
| `bakery-traceability/AGENTS.md`, `SECURITY.md` | Current rules incl. the V6 Suggested Production section. |

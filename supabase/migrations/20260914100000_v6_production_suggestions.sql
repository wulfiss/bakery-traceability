-- V6.4: master suggested-production catalog (spec §42-§48, §53).
--
-- production_suggestions: the master per-weekday suggestion codes
-- (A/B/C/D/E). This is the MASTER layer of the three-layer model
-- (spec §69): master suggestion -> daily selection -> request batch; the
-- layers are never collapsed into one table.
--
-- production_suggestion_items: the items that compose a suggestion. Only
-- items with a matched product plus a valid quantity/unit/shift are
-- eligible to live here (spec §47). shift_code is the matched product's
-- reviewed operational shift: morning/night only (AGENTS.md; the new table
-- has no history, so the CHECK is added VALID, unlike the NOT VALID
-- re-adding done in V5.2 for historical tables). Workbook TARDE rows are
-- never seeded here; they remain in the import review (spec §46).
--
-- No data is inserted in this step: the workbook import (and the product
-- master data it requires) happens in a later V6 step. No client
-- direct-write policies: later writes go through SECURITY DEFINER RPCs.

create table public.production_suggestions (
  id uuid primary key default gen_random_uuid(),
  weekday smallint not null check (weekday between 1 and 7),
  code text not null check (code in ('A', 'B', 'C', 'D', 'E')),
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.production_suggestions is
  'Master suggested-production catalog by weekday and code (A-E). Weekday: 1 = Monday ... 7 = Sunday. Master layer only; daily selections and request batches are later layers that reference it.';

-- At most one active row per weekday + code (Mon A-D, Tue A-E, Wed-Sat A-D).
create unique index production_suggestions_one_active_per_weekday_code
  on public.production_suggestions (weekday, code)
  where active;

create table public.production_suggestion_items (
  id uuid primary key default gen_random_uuid(),
  suggestion_id uuid not null references public.production_suggestions (id) on delete restrict,
  product_id uuid not null references public.products (id) on delete restrict,
  shift_code text not null check (shift_code in ('morning', 'night')),
  suggested_quantity numeric not null check (suggested_quantity > 0),
  unit text not null,
  source_text text,
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.production_suggestion_items is
  'Items composing a master production suggestion. shift_code is the matched product''s reviewed operational shift (morning/night only); source_text preserves the exact workbook cell text for traceability (spec §43).';

alter table public.production_suggestions enable row level security;
alter table public.production_suggestion_items enable row level security;

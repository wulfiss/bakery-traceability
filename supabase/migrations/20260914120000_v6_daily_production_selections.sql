-- V6.5: daily selection schema (spec §54, §69).
--
-- daily_production_selections: the DAILY layer of the three-layer model
-- (spec §69): master suggestion -> DAILY SELECTION -> request batch. One
-- selection per production day: the production day's chosen suggestion
-- (master layer), its status (draft until CONFIRMAR PRODUCCIÓN) and the
-- audit trail of who selected/updated/confirmed it.
--
-- daily_production_selection_items: the day's item list, editable after
-- choosing (check/uncheck via is_selected; quantities/units overridable).
-- source_suggestion_item_id links back to the master item when this row
-- came from one (nullable: items added on the day that have no master
-- counterpart). production_request_id links to the reconciled request
-- once CONFIRMAR PRODUCCIÓN creates requests (filled in by a later V6
-- step; the column is added now so this step does not ALTER
-- production_requests or its history).
--
-- shift_code: morning/night only (AGENTS.md); the table is new, so the
-- CHECK is added VALID. No data is inserted; no client direct-write
-- policies; writes happen later through SECURITY DEFINER RPCs only.

create table public.daily_production_selections (
  id uuid primary key default gen_random_uuid(),
  production_day_id uuid not null unique references public.production_days (id) on delete restrict,
  suggestion_id uuid not null references public.production_suggestions (id) on delete restrict,
  status text not null check (status in ('draft', 'confirmed')),
  selected_by uuid not null references auth.users (id),
  selected_at timestamptz not null,
  updated_by uuid not null references auth.users (id),
  updated_at timestamptz not null,
  confirmed_by uuid references auth.users (id),
  confirmed_at timestamptz
);

comment on table public.daily_production_selections is
  'Daily selection: one row per production day holding the chosen master suggestion (spec §69 daily layer). status draft until CONFIRMAR PRODUCCION; confirmed_*/updated_* audit columns record who changed state and when.';

create table public.daily_production_selection_items (
  id uuid primary key default gen_random_uuid(),
  daily_selection_id uuid not null references public.daily_production_selections (id) on delete restrict,
  source_suggestion_item_id uuid references public.production_suggestion_items (id) on delete restrict,
  product_id uuid not null references public.products (id) on delete restrict,
  shift_code text not null check (shift_code in ('morning', 'night')),
  quantity numeric not null check (quantity > 0),
  unit text not null,
  is_selected boolean not null default true,
  production_request_id uuid references public.production_requests (id) on delete restrict,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.daily_production_selection_items is
  'Editable item list of a daily production selection. is_selected drives the check/uncheck UI; source_suggestion_item_id traces the row back to the master item (null for items added on the day); production_request_id is filled when confirmation reconciles the request batch (later V6 step).';

alter table public.daily_production_selections enable row level security;
alter table public.daily_production_selection_items enable row level security;

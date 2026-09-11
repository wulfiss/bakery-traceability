-- Phase O1: production batches.

create table public.production_batches (
  id uuid primary key default gen_random_uuid(),
  production_day_id uuid not null references public.production_days (id) on delete restrict,
  recipe_version_id uuid not null references public.recipe_versions (id) on delete restrict,
  shift_code text not null check (shift_code in ('morning', 'afternoon', 'night')),
  batch_code text not null unique,
  status text not null check (status in ('in_progress', 'completed', 'cancelled')),
  started_at timestamptz not null,
  started_by uuid not null references auth.users (id),
  finished_at timestamptz,
  finished_by uuid references auth.users (id),
  notes text,
  created_at timestamptz not null default now()
);

comment on table public.production_batches is
  'Production batches. shift_code is copied from the production request (historical). Batch code format: PAN-DDMMYY-X-NNN (X = M/T/N), generated in later phases.';

alter table public.production_batches enable row level security;

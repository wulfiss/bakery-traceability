-- Phase M1: production day (one row per business date).

create table public.production_days (
  id uuid primary key default gen_random_uuid(),
  production_date date not null unique,
  status text not null check (status in ('open', 'closed')),
  opened_at timestamptz,
  opened_by uuid references auth.users (id),
  closed_at timestamptz,
  closed_by uuid references auth.users (id),
  created_at timestamptz not null default now()
);

comment on table public.production_days is
  'One row per business date (America/Argentina/Cordoba). Created by ensure_production_day in later phases.';

alter table public.production_days enable row level security;

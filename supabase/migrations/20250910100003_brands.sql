-- Phase F2: brands for raw materials.

create table public.brands (
  id uuid primary key default gen_random_uuid(),
  name text not null check (btrim(name) <> ''),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.brands is 'Raw material brands (Lealtad, Dos Anclas, Calsa, ...).';

alter table public.brands enable row level security;

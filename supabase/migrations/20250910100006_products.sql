-- Phase H1: finished products with their default production shift.

create table public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  default_unit text not null,
  default_shift_code text not null check (default_shift_code in ('morning', 'afternoon', 'night')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.products is
  'Finished products. default_shift_code is the normal/default shift only: historical shift is copied into production requests and batches, it is never re-inferred from here.';

alter table public.products enable row level security;

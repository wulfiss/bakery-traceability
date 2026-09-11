-- Phase I1: recipes (production formulas).

create table public.recipes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.recipes is
  'A recipe is a production formula/preparation, not necessarily one finished product.';

alter table public.recipes enable row level security;

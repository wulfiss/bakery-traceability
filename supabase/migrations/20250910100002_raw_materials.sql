-- Phase F1: raw material master data.

create table public.raw_materials (
  id uuid primary key default gen_random_uuid(),
  name text not null check (btrim(name) <> ''),
  default_unit text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.raw_materials is
  'Raw materials (flour, salt, yeast, ...). Case-insensitive unique name.';

-- Clean case-insensitive uniqueness strategy for name.
create unique index raw_materials_name_lower_key
  on public.raw_materials (lower(name));

alter table public.raw_materials enable row level security;

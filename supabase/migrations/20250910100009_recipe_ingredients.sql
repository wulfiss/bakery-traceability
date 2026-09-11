-- Phase I3: raw-material ingredients of a recipe version.

create table public.recipe_ingredients (
  id uuid primary key default gen_random_uuid(),
  recipe_version_id uuid not null references public.recipe_versions (id) on delete restrict,
  raw_material_id uuid not null references public.raw_materials (id) on delete restrict,
  quantity numeric not null check (quantity > 0),
  unit text not null,
  sort_order integer not null default 0,
  optional boolean not null default false,
  created_at timestamptz not null default now(),
  unique (recipe_version_id, raw_material_id)
);

comment on table public.recipe_ingredients is
  'Raw materials required by one recipe version (one row per material).';

alter table public.recipe_ingredients enable row level security;

-- Phase J1: previously produced products used as inputs of a recipe.

create table public.recipe_product_inputs (
  id uuid primary key default gen_random_uuid(),
  recipe_version_id uuid not null references public.recipe_versions (id) on delete restrict,
  source_product_id uuid not null references public.products (id) on delete restrict,
  quantity numeric check (quantity > 0),
  unit text,
  required boolean not null default true,
  created_at timestamptz not null default now()
);

comment on table public.recipe_product_inputs is
  'Declares that a recipe can require a previously produced product as input (e.g. Masa Pan Galleta -> Pan Galleta). Historical batches are linked later via parent_batch_inputs.';

alter table public.recipe_product_inputs enable row level security;

-- Phase I4: products produced by a recipe.

create table public.recipe_products (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references public.recipes (id) on delete restrict,
  product_id uuid not null references public.products (id) on delete restrict,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique (recipe_id, product_id)
);

comment on table public.recipe_products is
  'Links a recipe/preparation to one or multiple products it produces.';

alter table public.recipe_products enable row level security;

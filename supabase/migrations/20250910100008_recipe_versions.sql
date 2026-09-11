-- Phase I2: versioned recipe content.

create table public.recipe_versions (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references public.recipes (id) on delete restrict,
  version_number integer not null check (version_number > 0),
  status text not null check (status in ('draft', 'active', 'retired')),
  effective_from date,
  effective_to date,
  notes text,
  created_at timestamptz not null default now(),
  unique (recipe_id, version_number)
);

comment on table public.recipe_versions is
  'Versions of a recipe. Historical batches keep pointing at the version used at batch start.';

-- At most one active version per recipe.
create unique index recipe_versions_one_active_per_recipe
  on public.recipe_versions (recipe_id)
  where status = 'active';

alter table public.recipe_versions enable row level security;

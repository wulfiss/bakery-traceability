-- Phase F3: link between raw materials and the brands they use.

create table public.raw_material_brands (
  id uuid primary key default gen_random_uuid(),
  raw_material_id uuid not null references public.raw_materials (id) on delete restrict,
  brand_id uuid not null references public.brands (id) on delete restrict,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (raw_material_id, brand_id)
);

comment on table public.raw_material_brands is
  'Which brands are valid for each raw material. Restrictive FKs: master data is not deleted while linked.';

alter table public.raw_material_brands enable row level security;

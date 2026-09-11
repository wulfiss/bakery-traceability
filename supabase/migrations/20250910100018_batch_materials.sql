-- Phase O2: historical snapshot of the material lots used by a batch.

create table public.batch_materials (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.production_batches (id) on delete restrict,
  raw_material_id uuid not null references public.raw_materials (id) on delete restrict,
  material_lot_id uuid not null references public.material_lots (id) on delete restrict,
  recipe_quantity numeric check (recipe_quantity > 0),
  recipe_unit text,
  created_at timestamptz not null default now(),
  unique (batch_id, raw_material_id, material_lot_id)
);

comment on table public.batch_materials is
  'Snapshot of the exact current material lots at batch start. Append-mostly: historical traceability must never be reconstructed from material_lots.is_current.';

alter table public.batch_materials enable row level security;

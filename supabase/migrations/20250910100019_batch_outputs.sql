-- Phase O3: outputs of a batch.

create table public.batch_outputs (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.production_batches (id) on delete restrict,
  product_id uuid not null references public.products (id) on delete restrict,
  quantity numeric not null check (quantity > 0),
  unit text not null,
  created_at timestamptz not null default now()
);

comment on table public.batch_outputs is 'Products produced by a batch (one row per product, supports multi-output recipes).';

alter table public.batch_outputs enable row level security;

-- Phase G1: material lots (received/opened units of a raw material).

create table public.material_lots (
  id uuid primary key default gen_random_uuid(),
  raw_material_id uuid not null references public.raw_materials (id) on delete restrict,
  brand_id uuid not null references public.brands (id) on delete restrict,
  supplier_lot text not null,
  expiry_date date,
  received_at timestamptz,
  opened_at timestamptz,
  closed_at timestamptz,
  is_current boolean not null default false,
  status text not null check (status in ('available', 'in_use', 'closed', 'discarded')),
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now()
);

comment on table public.material_lots is
  'Lots of a raw material used in production. At most one lot is current per raw material.';

-- Critical rule: at most one is_current = true per raw_material_id.
create unique index material_lots_one_current_per_raw_material
  on public.material_lots (raw_material_id)
  where is_current;

alter table public.material_lots enable row level security;

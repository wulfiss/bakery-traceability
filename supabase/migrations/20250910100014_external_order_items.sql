-- Phase L2: items of an external order.

create table public.external_order_items (
  id uuid primary key default gen_random_uuid(),
  external_order_id uuid not null references public.external_orders (id) on delete restrict,
  product_id uuid not null references public.products (id) on delete restrict,
  quantity numeric not null check (quantity > 0),
  unit text not null,
  shift_code text not null check (shift_code in ('morning', 'afternoon', 'night')),
  notes text,
  created_at timestamptz not null default now()
);

comment on table public.external_order_items is
  'Order items. shift_code is the actual planned production shift for this item (defaulted from the product, overridable by supervisor/admin).';

alter table public.external_order_items enable row level security;

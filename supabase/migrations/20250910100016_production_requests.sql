-- Phase N1: unified production requests (base, external order, additional).

create table public.production_requests (
  id uuid primary key default gen_random_uuid(),
  production_day_id uuid not null references public.production_days (id) on delete restrict,
  source_type text not null check (source_type in ('base', 'external_order', 'additional')),
  shift_code text not null check (shift_code in ('morning', 'afternoon', 'night')),
  product_id uuid not null references public.products (id) on delete restrict,
  requested_quantity numeric not null check (requested_quantity > 0),
  unit text not null,
  external_order_item_id uuid references public.external_order_items (id) on delete restrict,
  reason_code text check (reason_code in ('replenishment', 'increased_demand', 'remake', 'other')),
  reason_note text,
  status text not null check (status in ('pending', 'in_progress', 'completed', 'cancelled')),
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),

  -- base: no order item, no reason.
  constraint production_requests_base_integrity check (
    source_type <> 'base'
    or (external_order_item_id is null and reason_code is null and reason_note is null)
  ),

  -- external_order: exactly one order item, no reason.
  constraint production_requests_external_order_integrity check (
    source_type <> 'external_order'
    or (external_order_item_id is not null and reason_code is null and reason_note is null)
  ),

  -- additional: no order item, reason required; "other" requires a non-empty note.
  constraint production_requests_additional_integrity check (
    source_type <> 'additional'
    or (
      external_order_item_id is null
      and reason_code is not null
      and (reason_code <> 'other' or (reason_note is not null and btrim(reason_note) <> ''))
    )
  )
);

comment on table public.production_requests is
  'Unified production requests. shift_code is historical: it is never re-inferred from products.default_shift_code.';

alter table public.production_requests enable row level security;

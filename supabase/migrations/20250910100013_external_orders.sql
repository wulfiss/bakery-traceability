-- Phase L1: external (customer) orders.

create table public.external_orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  customer_name text not null,
  requested_date date not null,
  delivery_time time,
  status text not null check (status in ('pending', 'in_production', 'completed', 'cancelled')),
  notes text,
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.external_orders is 'External customer orders.';

alter table public.external_orders enable row level security;

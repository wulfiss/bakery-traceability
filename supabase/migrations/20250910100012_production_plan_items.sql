-- Phase K1: weekly base production plan.

create table public.production_plan_items (
  id uuid primary key default gen_random_uuid(),
  weekday smallint not null check (weekday between 1 and 7),
  shift_code text not null check (shift_code in ('morning', 'afternoon', 'night')),
  product_id uuid not null references public.products (id) on delete restrict,
  planned_quantity numeric not null check (planned_quantity > 0),
  unit text not null,
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.production_plan_items is
  'Base production plan by weekday and shift. Weekday: 1 = Monday ... 7 = Sunday.';

-- At most one active row per weekday + shift + product + unit.
create unique index production_plan_items_one_active_per_key
  on public.production_plan_items (weekday, shift_code, product_id, unit)
  where active;

alter table public.production_plan_items enable row level security;

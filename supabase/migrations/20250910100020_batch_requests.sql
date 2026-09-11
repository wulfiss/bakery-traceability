-- Phase O4: link between batches and the production requests they cover.

create table public.batch_requests (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.production_batches (id) on delete restrict,
  production_request_id uuid not null references public.production_requests (id) on delete restrict,
  allocated_quantity numeric check (allocated_quantity > 0),
  created_at timestamptz not null default now(),
  unique (batch_id, production_request_id)
);

comment on table public.batch_requests is
  'Links one or more production requests to a batch. Restrictive FKs: history is never cascade-deleted.';

alter table public.batch_requests enable row level security;

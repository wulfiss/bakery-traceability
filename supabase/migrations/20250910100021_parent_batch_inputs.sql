-- Phase O5: produced-product-as-input traceability (batch consumes output of a parent batch).

create table public.parent_batch_inputs (
  id uuid primary key default gen_random_uuid(),
  child_batch_id uuid not null references public.production_batches (id) on delete restrict,
  parent_batch_output_id uuid not null references public.batch_outputs (id) on delete restrict,
  quantity numeric check (quantity > 0),
  unit text,
  created_at timestamptz not null default now()
);

comment on table public.parent_batch_inputs is
  'Links a child batch to the batch output it consumed as input (e.g. Pan Leche Redondo produced from Masa Pan Galleta).';

create or replace function public.reject_parent_batch_self_reference()
returns trigger
language plpgsql
as $$
declare
  parent_batch uuid;
begin
  select batch_id
  into parent_batch
  from public.batch_outputs
  where id = new.parent_batch_output_id;

  if parent_batch is not null and parent_batch = new.child_batch_id then
    raise exception 'a batch cannot consume its own output as input';
  end if;

  return new;
end;
$$;

-- Prevent obvious self-reference (a batch using its own output).
create trigger parent_batch_inputs_no_self_reference
  before insert or update of child_batch_id, parent_batch_output_id
  on public.parent_batch_inputs
  for each row
  execute function public.reject_parent_batch_self_reference();

alter table public.parent_batch_inputs enable row level security;

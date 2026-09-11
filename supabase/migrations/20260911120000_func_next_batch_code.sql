-- Phase AD1: safe bakery batch-code generation.
--
-- Format: PAN-DDMMYY-X-NNN where X is M (morning), T (afternoon), N (night)
-- and NNN is a 1-based sequence that resets by production_date + shift_code.
-- Examples: PAN-100926-M-001, PAN-100926-T-001, PAN-100926-N-001.
--
-- The date is always read from the stored production_days.production_date
-- (never recalculated from the session clock), per the business timezone rule.
--
-- Concurrency strategy (documented per AD1):
--   The function takes a transaction-scoped advisory lock keyed by
--   (production_date, shift_code):
--
--     pg_advisory_xact_lock(hashtext(production_date || '|' || shift_code))
--
--   The lock is held by the CALLER'S transaction until commit/rollback
--   (advisory xact locks are transaction-scoped regardless of which function
--   takes them). The intended usage is therefore, inside a single transaction
--   (e.g. the start_production_batch RPC):
--     1. call next_batch_code(...)  -> advisory lock acquired, suffix scanned
--     2. insert the batch with that code
--     3. commit                    -> lock released
--   Because the max-suffix scan and the later insert always occur within the
--   same locked transaction, two concurrent generators for the same
--   day+shift can never observe the same max and thus can never produce the
--   same code. Sessions for different day+shift pairs never block each other.
--   This is the replacement for the race-prone plain count(*) + 1.
--   The existing UNIQUE constraint on production_batches.batch_code remains as
--   the final backstop (a violation there would indicate a bug, not a race).
--   Gap tolerance: a code generated but whose transaction rolls back leaves a
--   number gap; gaps are allowed, uniqueness is the invariant.
--
-- The function is read-only (no writes of its own), so it uses SECURITY
-- INVOKER like get_business_date() -- no privilege escalation, no auth
-- re-check needed here; the caller (e.g. start_production_batch) keeps its
-- own authorization checks. Sequence beyond 999: the suffix simply widens
-- to 4+ digits (lpad only pads, never truncates); uniqueness is preserved.

create or replace function public.next_batch_code(p_production_day_id uuid, p_shift_code text)
returns text
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_production_date date;
  v_letter char(1);
  v_next int;
  v_code text;
begin
  select production_date into v_production_date
  from public.production_days
  where id = p_production_day_id;

  if v_production_date is null then
    raise exception 'production_day_not_found';
  end if;

  v_letter := case p_shift_code
    when 'morning' then 'M'
    when 'afternoon' then 'T'
    when 'night' then 'N'
    else null
  end;

  if v_letter is null then
    raise exception 'invalid_shift';
  end if;

  -- Serialize code generation per (production_date, shift_code) for the whole
  -- caller transaction (see header comment for the strategy).
  perform pg_advisory_xact_lock(hashtext(v_production_date::text || '|' || p_shift_code));

  select coalesce(max(regexp_replace(batch_code, '^.*-([0-9]+)$', '\1')::int), 0) + 1
    into v_next
  from public.production_batches
  where batch_code like 'PAN-' || to_char(v_production_date, 'DDMMYY') || '-' || v_letter || '-%';

  v_code := 'PAN-' || to_char(v_production_date, 'DDMMYY') || '-' || v_letter || '-' || lpad(v_next::text, 3, '0');

  return v_code;
end;
$$;

comment on function public.next_batch_code(uuid, text) is
  'Generates the next PAN-DDMMYY-X-NNN batch code for a production day and shift; sequence resets by stored production_date + shift_code; transaction-scoped advisory lock makes generation concurrency-safe when the batch insert happens in the same transaction.';

revoke execute on function public.next_batch_code(uuid, text) from public;
revoke execute on function public.next_batch_code(uuid, text) from anon, authenticated, service_role;
grant execute on function public.next_batch_code(uuid, text) to authenticated;

-- Phase X1: idempotent "ensure the current business production day exists".
--
-- Why an RPC: app roles (anon/authenticated) have SELECT-only RLS policies on
-- production_days (U2); the create-if-missing transition must be a narrow
-- server/database operation, not a client table write.
--
-- Behavior (single transaction, idempotent):
--   1. require auth.uid() non-null with an active profile (any of the three
--      app roles; the role column is DB-constrained to operator/supervisor/admin);
--   2. take the date from public.get_business_date() (America/Argentina/Cordoba) —
--      never from a browser-supplied "today";
--   3. if a production_days row already exists for that date, return its id;
--   4. otherwise create it with status='open', opened_at=now(),
--      opened_by=caller; the unique production_date constraint plus
--      ON CONFLICT DO NOTHING makes the create race-safe (a concurrent call
--      loses the insert and both callers return the same row).
--   5. return the production_day id.
-- Downstream steps (weekday, batch codes) use the stored
-- production_days.production_date, never a recalculated "today".
--
-- No production requests are generated here (that is phase Y).
--
-- Security (SECURITY.md RPC checklist):
--   - SECURITY DEFINER owned by postgres is deliberate: the body performs the
--     insert that no app role may do directly. Every authorization check lives
--     in the function body above.
--   - explicit safe search_path; every object fully qualified.
--   - EXECUTE revoked from PUBLIC, anon, authenticated and service_role
--     (Supabase default privileges would grant it, see U4); granted to
--     authenticated only, the role the app's users run as through PostgREST.

create or replace function public.ensure_production_day()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_date date;
  v_day_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if not exists (select 1 from public.profiles where id = v_user_id and active) then
    raise exception 'no_active_profile';
  end if;

  v_date := public.get_business_date();

  insert into public.production_days (production_date, status, opened_at, opened_by)
  values (v_date, 'open', now(), v_user_id)
  on conflict (production_date) do nothing;

  select id into v_day_id
  from public.production_days
  where production_date = v_date;

  return v_day_id;
end;
$$;

comment on function public.ensure_production_day() is
  'Idempotently ensures the current business production day (America/Argentina/Cordoba) exists with status open; returns the production_day id. Date comes from get_business_date(), never from the client.';

revoke execute on function public.ensure_production_day() from public;
revoke execute on function public.ensure_production_day() from anon, authenticated, service_role;
grant execute on function public.ensure_production_day() to authenticated;

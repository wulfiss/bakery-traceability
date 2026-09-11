-- X0: get_business_date()
--
-- Returns the current date in the fixed business timezone
-- America/Argentina/Cordoba. Read-only, no writes, no privilege escalation
-- (SECURITY INVOKER).
--
-- Why UTC / toISOString() must not determine production_date:
-- production_date drives the batch-code date, the weekday in the weekly plan,
-- and traceability history. The bakery operates on local dates: near midnight,
-- UTC can already be on the next day while Cordoba is still on the current
-- business day (and vice versa), which would put batches on the wrong date.
-- Browser and Node timezones are wrong too: they vary per device and machine,
-- while the business date must be one deterministic value for everyone.

create or replace function public.get_business_date()
returns date
language sql
as $$
	select (now() at time zone 'America/Argentina/Cordoba')::date
$$;

revoke execute on function public.get_business_date() from public;
revoke execute on function public.get_business_date() from anon;
revoke execute on function public.get_business_date() from authenticated;
revoke execute on function public.get_business_date() from service_role;
grant execute on function public.get_business_date() to authenticated;

comment on function public.get_business_date() is
	'Current date in America/Argentina/Cordoba; the single source for production_date. Never derive it from UTC, toISOString(), browser or Node timezones.';

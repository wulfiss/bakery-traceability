-- Phase AK2: create an external-order HEADER (no items yet; item management
-- arrives in a later phase).
--
-- Steps (all-or-nothing, single implicit transaction; any raised exception
-- rolls everything back):
--   1. validate authenticated user + active profile (established RPC model);
--   2. validate the profile role is supervisor or admin (the role model
--      assigns external-order management to supervisor/admin; operators are
--      rejected);
--   3. validate inputs: non-empty (trimmed) order number and customer name,
--      non-null requested date, delivery time blank (null) or a valid time;
--   4. insert the header with status = 'pending', created_by = acting user,
--      blank notes normalized to null;
--   5. map a duplicate order_number (unique constraint) to a clean token.
--
-- Security (established RPC security model, see SECURITY.md):
--   SECURITY DEFINER (performs external_orders writes no app role may do
--   directly), requires auth.uid(), validates the active profile AND the
--   supervisor/admin role (authorization lives in the database, not in the
--   UI), explicit safe search_path, EXECUTE revoked from PUBLIC/anon/
--   service_role, granted to authenticated only. Error tokens are English,
--   developer-facing; the UI maps them to Spanish messages.

create or replace function public.create_external_order(
  p_order_number text,
  p_customer_name text,
  p_requested_date date,
  p_delivery_time text,
  p_notes text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_order_number text;
  v_customer_name text;
  v_delivery_time time;
  v_notes text;
  v_new_order_id uuid;
begin
  -- 1. Auth + active profile (established model).
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if not exists (select 1 from public.profiles where id = v_user_id and active) then
    raise exception 'no_active_profile';
  end if;

  -- 2. Role check: external-order management is a supervisor/admin task.
  if not exists (
    select 1
    from public.profiles
    where id = v_user_id and role in ('supervisor', 'admin')
  ) then
    raise exception 'insufficient_role';
  end if;

  -- 3. Input validation.
  v_order_number := trim(coalesce(p_order_number, ''));
  v_customer_name := trim(coalesce(p_customer_name, ''));
  v_notes := trim(coalesce(p_notes, ''));

  if v_order_number = '' then
    raise exception 'invalid_order_number';
  end if;

  if v_customer_name = '' then
    raise exception 'invalid_customer_name';
  end if;

  if p_requested_date is null then
    raise exception 'invalid_requested_date';
  end if;

  -- Delivery time is optional: blank -> null, otherwise must parse as a time.
  if trim(coalesce(p_delivery_time, '')) = '' then
    v_delivery_time := null;
  else
    begin
      v_delivery_time := trim(p_delivery_time)::time;
    exception
      when invalid_text_representation or datetime_field_overflow then
        raise exception 'invalid_delivery_time';
    end;
  end if;

  -- 4. Create the header (items are managed in a later phase).
  begin
    insert into public.external_orders (
      order_number, customer_name, requested_date, delivery_time, status, notes, created_by
    )
    values (
      v_order_number,
      v_customer_name,
      p_requested_date,
      v_delivery_time,
      'pending',
      nullif(v_notes, ''),
      v_user_id
    )
    returning id into v_new_order_id;
  exception
    when unique_violation then
      raise exception 'order_number_exists';
  end;

  return v_new_order_id;
end;
$$;

revoke execute on function public.create_external_order(text, text, date, text, text)
  from public, anon, service_role, authenticated;

grant execute on function public.create_external_order(text, text, date, text, text)
  to authenticated;

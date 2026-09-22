--
-- PostgreSQL database dump
--

\restrict XF0xtSDsbqYv33Zkge5nqQec5cZQnXhEX2A2ER0qoG09ieYuGLaC0Y0V8A39ltI

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: _realtime; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA _realtime;


--
-- Name: auth; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA auth;


--
-- Name: extensions; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA extensions;


--
-- Name: graphql; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA graphql;


--
-- Name: graphql_public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA graphql_public;


--
-- Name: pgbouncer; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA pgbouncer;


--
-- Name: realtime; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA realtime;


--
-- Name: storage; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA storage;


--
-- Name: supabase_functions; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA supabase_functions;


--
-- Name: supabase_migrations; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA supabase_migrations;


--
-- Name: vault; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA vault;


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA extensions;


--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_stat_statements IS 'track planning and execution statistics of all SQL statements executed';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: supabase_vault; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS supabase_vault WITH SCHEMA vault;


--
-- Name: EXTENSION supabase_vault; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION supabase_vault IS 'Supabase Vault Extension';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: aal_level; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.aal_level AS ENUM (
    'aal1',
    'aal2',
    'aal3'
);


--
-- Name: code_challenge_method; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.code_challenge_method AS ENUM (
    's256',
    'plain'
);


--
-- Name: factor_status; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.factor_status AS ENUM (
    'unverified',
    'verified'
);


--
-- Name: factor_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.factor_type AS ENUM (
    'totp',
    'webauthn',
    'phone'
);


--
-- Name: oauth_authorization_status; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_authorization_status AS ENUM (
    'pending',
    'approved',
    'denied',
    'expired'
);


--
-- Name: oauth_client_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_client_type AS ENUM (
    'public',
    'confidential'
);


--
-- Name: oauth_registration_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_registration_type AS ENUM (
    'dynamic',
    'manual'
);


--
-- Name: oauth_response_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_response_type AS ENUM (
    'code'
);


--
-- Name: one_time_token_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.one_time_token_type AS ENUM (
    'confirmation_token',
    'reauthentication_token',
    'recovery_token',
    'email_change_token_new',
    'email_change_token_current',
    'phone_change_token'
);


--
-- Name: start_production_batch_result; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.start_production_batch_result AS (
	batch_id uuid,
	batch_code text
);


--
-- Name: action; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.action AS ENUM (
    'INSERT',
    'UPDATE',
    'DELETE',
    'TRUNCATE',
    'ERROR'
);


--
-- Name: equality_op; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.equality_op AS ENUM (
    'eq',
    'neq',
    'lt',
    'lte',
    'gt',
    'gte',
    'in',
    'like',
    'ilike',
    'is',
    'match',
    'imatch',
    'isdistinct'
);


--
-- Name: user_defined_filter; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.user_defined_filter AS (
	column_name text,
	op realtime.equality_op,
	value text,
	negate boolean
);


--
-- Name: wal_column; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.wal_column AS (
	name text,
	type_name text,
	type_oid oid,
	value jsonb,
	is_pkey boolean,
	is_selectable boolean
);


--
-- Name: wal_rls; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.wal_rls AS (
	wal jsonb,
	is_rls_enabled boolean,
	subscription_ids uuid[],
	errors text[]
);


--
-- Name: buckettype; Type: TYPE; Schema: storage; Owner: -
--

CREATE TYPE storage.buckettype AS ENUM (
    'STANDARD',
    'ANALYTICS',
    'VECTOR'
);


--
-- Name: email(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.email() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email')
  )::text
$$;


--
-- Name: FUNCTION email(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.email() IS 'Deprecated. Use auth.jwt() -> ''email'' instead.';


--
-- Name: jwt(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.jwt() RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$
  select 
    coalesce(
        nullif(current_setting('request.jwt.claim', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
$$;


--
-- Name: role(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.role() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$$;


--
-- Name: FUNCTION role(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.role() IS 'Deprecated. Use auth.jwt() -> ''role'' instead.';


--
-- Name: uid(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.uid() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;


--
-- Name: FUNCTION uid(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.uid() IS 'Deprecated. Use auth.jwt() -> ''sub'' instead.';


--
-- Name: grant_pg_cron_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_cron_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    SELECT
    FROM pg_event_trigger_ddl_commands() AS ev
    JOIN pg_extension AS ext
    ON ev.objid = ext.oid
    WHERE ext.extname = 'pg_cron'
  )
  THEN
    grant usage on schema cron to postgres with grant option;

    alter default privileges in schema cron grant all on tables to postgres with grant option;
    alter default privileges in schema cron grant all on functions to postgres with grant option;
    alter default privileges in schema cron grant all on sequences to postgres with grant option;

    alter default privileges for user supabase_admin in schema cron grant all
        on sequences to postgres with grant option;
    alter default privileges for user supabase_admin in schema cron grant all
        on tables to postgres with grant option;
    alter default privileges for user supabase_admin in schema cron grant all
        on functions to postgres with grant option;

    grant all privileges on all tables in schema cron to postgres with grant option;
    revoke all on table cron.job from postgres;
    grant select on table cron.job to postgres with grant option;
    revoke trigger on cron.job_run_details from postgres cascade;
  END IF;
END;
$$;


--
-- Name: FUNCTION grant_pg_cron_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_cron_access() IS 'Grants access to pg_cron';


--
-- Name: grant_pg_graphql_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_graphql_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $_$
begin
    if not exists (
        select 1
        from pg_event_trigger_ddl_commands() ev
        join pg_catalog.pg_extension e on ev.objid = e.oid
        where e.extname = 'pg_graphql'
    ) then
        return;
    end if;

    drop function if exists graphql_public.graphql;
    create or replace function graphql_public.graphql(
        "operationName" text default null,
        query text default null,
        variables jsonb default null,
        extensions jsonb default null
    )
        returns jsonb
        language sql
    as $$
        select graphql.resolve(
            query := query,
            variables := coalesce(variables, '{}'),
            "operationName" := "operationName",
            extensions := extensions
        );
    $$;

    -- Attach the wrapper to the extension so DROP EXTENSION cascades to it,
    -- which in turn triggers set_graphql_placeholder to reinstall the "not enabled" stub.
    alter extension pg_graphql add function graphql_public.graphql(text, text, jsonb, jsonb);

    grant usage on schema graphql to postgres, anon, authenticated, service_role;
    grant execute on function graphql.resolve to postgres, anon, authenticated, service_role;
    grant usage on schema graphql to postgres with grant option;
    grant usage on schema graphql_public to postgres with grant option;
end;
$_$;


--
-- Name: FUNCTION grant_pg_graphql_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_graphql_access() IS 'Grants access to pg_graphql';


--
-- Name: grant_pg_net_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_net_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_event_trigger_ddl_commands() AS ev
    JOIN pg_extension AS ext
    ON ev.objid = ext.oid
    WHERE ext.extname = 'pg_net'
  )
  THEN
    GRANT USAGE ON SCHEMA net TO supabase_functions_admin, postgres, anon, authenticated, service_role;

    ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;
    ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;

    ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;
    ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;

    REVOKE ALL ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;
    REVOKE ALL ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;

    GRANT EXECUTE ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
    GRANT EXECUTE ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
  END IF;
END;
$$;


--
-- Name: FUNCTION grant_pg_net_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_net_access() IS 'Grants access to pg_net';


--
-- Name: pgrst_ddl_watch(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.pgrst_ddl_watch() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN SELECT * FROM pg_event_trigger_ddl_commands()
  LOOP
    IF cmd.command_tag IN (
      'CREATE SCHEMA', 'ALTER SCHEMA'
    , 'CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO', 'ALTER TABLE'
    , 'CREATE FOREIGN TABLE', 'ALTER FOREIGN TABLE'
    , 'CREATE VIEW', 'ALTER VIEW'
    , 'CREATE MATERIALIZED VIEW', 'ALTER MATERIALIZED VIEW'
    , 'CREATE FUNCTION', 'ALTER FUNCTION'
    , 'CREATE TRIGGER'
    , 'CREATE TYPE', 'ALTER TYPE'
    , 'CREATE RULE'
    , 'COMMENT'
    )
    -- don't notify in case of CREATE TEMP table or other objects created on pg_temp
    AND cmd.schema_name is distinct from 'pg_temp'
    THEN
      NOTIFY pgrst, 'reload schema';
    END IF;
  END LOOP;
END; $$;


--
-- Name: pgrst_drop_watch(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.pgrst_drop_watch() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  obj record;
BEGIN
  FOR obj IN SELECT * FROM pg_event_trigger_dropped_objects()
  LOOP
    IF obj.object_type IN (
      'schema'
    , 'table'
    , 'foreign table'
    , 'view'
    , 'materialized view'
    , 'function'
    , 'trigger'
    , 'type'
    , 'rule'
    )
    AND obj.is_temporary IS false -- no pg_temp objects
    THEN
      NOTIFY pgrst, 'reload schema';
    END IF;
  END LOOP;
END; $$;


--
-- Name: set_graphql_placeholder(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.set_graphql_placeholder() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $_$
    DECLARE
    graphql_is_dropped bool;
    BEGIN
    graphql_is_dropped = (
        SELECT ev.schema_name = 'graphql_public'
        FROM pg_event_trigger_dropped_objects() AS ev
        WHERE ev.schema_name = 'graphql_public'
    );

    IF graphql_is_dropped
    THEN
        create or replace function graphql_public.graphql(
            "operationName" text default null,
            query text default null,
            variables jsonb default null,
            extensions jsonb default null
        )
            returns jsonb
            language plpgsql
        as $$
            DECLARE
                server_version float;
            BEGIN
                server_version = (SELECT (SPLIT_PART((select version()), ' ', 2))::float);

                IF server_version >= 14 THEN
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql extension is not enabled.'
                            )
                        )
                    );
                ELSE
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql is only available on projects running Postgres 14 onwards.'
                            )
                        )
                    );
                END IF;
            END;
        $$;
    END IF;

    END;
$_$;


--
-- Name: FUNCTION set_graphql_placeholder(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.set_graphql_placeholder() IS 'Reintroduces placeholder function for graphql_public.graphql';


--
-- Name: graphql(text, text, jsonb, jsonb); Type: FUNCTION; Schema: graphql_public; Owner: -
--

CREATE FUNCTION graphql_public.graphql("operationName" text DEFAULT NULL::text, query text DEFAULT NULL::text, variables jsonb DEFAULT NULL::jsonb, extensions jsonb DEFAULT NULL::jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
            DECLARE
                server_version float;
            BEGIN
                server_version = (SELECT (SPLIT_PART((select version()), ' ', 2))::float);

                IF server_version >= 14 THEN
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql extension is not enabled.'
                            )
                        )
                    );
                ELSE
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql is only available on projects running Postgres 14 onwards.'
                            )
                        )
                    );
                END IF;
            END;
        $$;


--
-- Name: get_auth(text); Type: FUNCTION; Schema: pgbouncer; Owner: -
--

CREATE FUNCTION pgbouncer.get_auth(p_usename text) RETURNS TABLE(username text, password text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
begin
    raise debug 'PgBouncer auth request: %', p_usename;

    return query
    select 
        rolname::text, 
        case when rolvaliduntil < now() 
            then null 
            else rolpassword::text 
        end 
    from pg_authid 
    where rolname=$1 and rolcanlogin;
end;
$_$;


--
-- Name: add_external_order_item(uuid, uuid, numeric, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.add_external_order_item(p_external_order_id uuid, p_product_id uuid, p_quantity numeric, p_unit text, p_shift_code text, p_notes text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_role text;
  v_unit text;
  v_notes text;
  v_new_item_id uuid;
begin
  -- 1. Authentication and active profile.
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  select role into v_role
  from public.profiles
  where id = v_user_id and active;

  if v_role is null then
    raise exception 'no_active_profile';
  end if;

  -- 2. Role gate: only supervisor/admin manage order items.
  if v_role not in ('supervisor', 'admin') then
    raise exception 'insufficient_role';
  end if;

  -- 3. Validation.
  if not exists (select 1 from public.external_orders where id = p_external_order_id) then
    raise exception 'order_not_found';
  end if;

  if not exists (select 1 from public.products where id = p_product_id and active) then
    raise exception 'product_not_available';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'invalid_quantity';
  end if;

  v_unit := trim(coalesce(p_unit, ''));
  if v_unit = '' then
    raise exception 'invalid_unit';
  end if;

  if p_shift_code is null or p_shift_code not in ('morning', 'afternoon', 'night') then
    raise exception 'invalid_shift';
  end if;

  v_notes := trim(coalesce(p_notes, ''));

  -- 4. Insert (the final shift is stored verbatim, never recalculated later).
  insert into public.external_order_items (
    external_order_id, product_id, quantity, unit, shift_code, notes
  )
  values (
    p_external_order_id,
    p_product_id,
    p_quantity,
    v_unit,
    p_shift_code,
    nullif(v_notes, '')
  )
  returning id into v_new_item_id;

  return v_new_item_id;
end;
$$;


--
-- Name: change_current_material_lot(uuid, uuid, text, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.change_current_material_lot(p_raw_material_id uuid, p_brand_id uuid, p_supplier_lot text, p_expiry_date date DEFAULT NULL::date) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_new_lot_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if not exists (select 1 from public.profiles where id = v_user_id and active) then
    raise exception 'no_active_profile';
  end if;

  if not exists (select 1 from public.raw_materials where id = p_raw_material_id and active) then
    raise exception 'raw_material_not_found';
  end if;

  if not exists (select 1 from public.brands where id = p_brand_id and active) then
    raise exception 'brand_not_found';
  end if;

  if not exists (
    select 1
    from public.raw_material_brands
    where raw_material_id = p_raw_material_id
      and brand_id = p_brand_id
      and active
  ) then
    raise exception 'brand_not_permitted_for_material';
  end if;

  if p_supplier_lot is null or btrim(p_supplier_lot) = '' then
    raise exception 'supplier_lot_required';
  end if;

  -- Close the prior current lot for this material, if any.
  update public.material_lots
     set is_current = false,
         status = case
                    when status in ('available', 'in_use') then 'closed'
                    else status
                  end,
         closed_at = now()
   where raw_material_id = p_raw_material_id
     and is_current = true;

  insert into public.material_lots (
    raw_material_id, brand_id, supplier_lot, expiry_date,
    opened_at, is_current, status, created_by
  ) values (
    p_raw_material_id, p_brand_id, btrim(p_supplier_lot), p_expiry_date,
    now(), true, 'in_use', v_user_id
  )
  returning id into v_new_lot_id;

  return v_new_lot_id;
end;
$$;


--
-- Name: FUNCTION change_current_material_lot(p_raw_material_id uuid, p_brand_id uuid, p_supplier_lot text, p_expiry_date date); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.change_current_material_lot(p_raw_material_id uuid, p_brand_id uuid, p_supplier_lot text, p_expiry_date date) IS 'Atomically switches the current lot of a raw material: closes the prior current lot (if any) and creates the new one (in_use, is_current). Controlled write for authenticated users with an active profile.';


--
-- Name: complete_multi_output_batch(uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.complete_multi_output_batch(p_batch_id uuid, p_outputs jsonb) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_batch_status text;
  v_recipe_id uuid;
  v_total int;
  v_distinct_products int;
  v_elem jsonb;
  v_product_raw text;
  v_quantity_raw text;
  v_unit text;
  v_product_id uuid;
  v_quantity numeric;
begin
  -- 1. Auth (established model).
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if not exists (select 1 from public.profiles where id = v_user_id and active) then
    raise exception 'no_active_profile';
  end if;

  -- 2. Batch exists. FOR UPDATE serializes concurrent completions of the same
  --    batch (the second caller re-reads status = completed and fails). The
  --    recipe_version row is locked as well, so the recipe cannot be swapped
  --    mid-transaction.
  select b.status, rv.recipe_id
    into v_batch_status, v_recipe_id
  from public.production_batches b
  join public.recipe_versions rv on rv.id = b.recipe_version_id
  where b.id = p_batch_id
  for update;

  if v_batch_status is null then
    raise exception 'batch_not_found';
  end if;

  if v_batch_status <> 'in_progress' then
    raise exception 'batch_not_in_progress';
  end if;

  -- 3. p_outputs must be a non-empty JSON array.
  if p_outputs is null
    or jsonb_typeof(p_outputs) <> 'array'
    or jsonb_array_length(p_outputs) = 0 then
    raise exception 'invalid_outputs';
  end if;

  -- 4. A product may appear at most once in the output list.
  select count(*), count(distinct (value->>'product_id'))
    into v_total, v_distinct_products
  from jsonb_array_elements(p_outputs) e(value);

  if v_total <> v_distinct_products then
    raise exception 'duplicate_output';
  end if;

  -- 5. Validate every element and record one output row per element.
  for v_elem in
    select e.value from jsonb_array_elements(p_outputs) e(value)
  loop
    v_product_raw := v_elem->>'product_id';
    v_quantity_raw := v_elem->>'quantity';
    v_unit := coalesce(v_elem->>'unit', '');

    if v_product_raw is null then
      raise exception 'invalid_output';
    end if;

    begin
      v_product_id := v_product_raw::uuid;
    exception
      when others then
        raise exception 'invalid_output';
    end;

    if not exists (select 1 from public.products where id = v_product_id) then
      raise exception 'invalid_output';
    end if;

    begin
      v_quantity := v_quantity_raw::numeric;
    exception
      when others then
        raise exception 'invalid_output';
    end;

    if v_quantity <= 0 or btrim(v_unit) = '' then
      raise exception 'invalid_output';
    end if;

    -- The output must be one of the products of the batch's recipe; never
    -- record a product the recipe cannot yield.
    if not exists (
      select 1
      from public.recipe_products rp
      where rp.recipe_id = v_recipe_id
        and rp.product_id = v_product_id
    ) then
      raise exception 'output_not_in_recipe';
    end if;

    insert into public.batch_outputs (batch_id, product_id, quantity, unit)
    values (p_batch_id, v_product_id, v_quantity, btrim(v_unit));
  end loop;

  -- 6. Complete the batch.
  update public.production_batches
  set status = 'completed',
      finished_at = now(),
      finished_by = v_user_id
  where id = p_batch_id;

  -- 7. Complete every linked request (a batch created by
  --    start_production_batch has exactly one) and backfill the allocation
  --    only where it was not saved at batch start.
  update public.production_requests r
  set status = 'completed'
  from public.batch_requests br
  where br.batch_id = p_batch_id
    and br.production_request_id = r.id;

  update public.batch_requests br
  set allocated_quantity = r.requested_quantity
  from public.production_requests r
  where br.production_request_id = r.id
    and br.batch_id = p_batch_id
    and br.allocated_quantity is null;
end;
$$;


--
-- Name: FUNCTION complete_multi_output_batch(p_batch_id uuid, p_outputs jsonb); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.complete_multi_output_batch(p_batch_id uuid, p_outputs jsonb) IS 'Completes an in-progress multi-output batch: validates auth/profile, locks the batch and its recipe_version, validates that p_outputs is a non-empty JSON array of {product_id, quantity, unit} without duplicates and that every product belongs to the batch recipe (output_not_in_recipe), inserts one batch_outputs row per element, completes the batch, completes every linked production request, and backfills batch_requests.allocated_quantity only when null; never modifies batch_materials; atomic, all-or-nothing.';


--
-- Name: complete_production_batch(uuid, numeric, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.complete_production_batch(p_batch_id uuid, p_actual_quantity numeric, p_unit text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_batch_status text;
  v_request_id uuid;
  v_product_id uuid;
  v_requested_quantity numeric;
begin
  -- 1. Auth (established model).
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if not exists (select 1 from public.profiles where id = v_user_id and active) then
    raise exception 'no_active_profile';
  end if;

  -- 2. Batch exists. FOR UPDATE serializes concurrent completions of the same
  --    batch (the second caller re-reads status = completed and fails).
  select b.status
    into v_batch_status
  from public.production_batches b
  where b.id = p_batch_id
  for update;

  if v_batch_status is null then
    raise exception 'batch_not_found';
  end if;

  -- 3. Only an in-progress batch can be completed.
  if v_batch_status <> 'in_progress' then
    raise exception 'batch_not_in_progress';
  end if;

  -- 4. Validate the actual production result.
  if p_actual_quantity is null
    or p_actual_quantity <= 0
    or p_unit is null
    or btrim(p_unit) = '' then
    raise exception 'invalid_quantity';
  end if;

  -- 5. Determine the linked request (product + requested quantity).
  select br.production_request_id, r.product_id, r.requested_quantity
    into v_request_id, v_product_id, v_requested_quantity
  from public.batch_requests br
  join public.production_requests r on r.id = br.production_request_id
  where br.batch_id = p_batch_id
  order by br.created_at
  limit 1;

  if v_request_id is null then
    raise exception 'batch_request_not_found';
  end if;

  -- 6. Record the actual output (single product for this step).
  insert into public.batch_outputs (batch_id, product_id, quantity, unit)
  values (p_batch_id, v_product_id, p_actual_quantity, btrim(p_unit));

  -- 7. Complete the batch.
  update public.production_batches
  set status = 'completed',
      finished_at = now(),
      finished_by = v_user_id
  where id = p_batch_id;

  -- 8. Complete the linked request.
  update public.production_requests
  set status = 'completed'
  where id = v_request_id;

  -- 9. Save the allocation only where it was not saved at batch start.
  update public.batch_requests
  set allocated_quantity = v_requested_quantity
  where batch_id = p_batch_id
    and production_request_id = v_request_id
    and allocated_quantity is null;
end;
$$;


--
-- Name: FUNCTION complete_production_batch(p_batch_id uuid, p_actual_quantity numeric, p_unit text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.complete_production_batch(p_batch_id uuid, p_actual_quantity numeric, p_unit text) IS 'Completes an in-progress single-product batch: validates auth/profile, locks the batch row, validates the actual quantity/unit, records the batch_outputs row, sets the batch completed with finished_at/finished_by, completes the linked production request, and backfills batch_requests.allocated_quantity only when null; never modifies batch_materials; atomic, all-or-nothing.';


--
-- Name: create_additional_production_request(uuid, uuid, numeric, text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_additional_production_request(p_production_day_id uuid, p_product_id uuid, p_requested_quantity numeric, p_unit text, p_shift_code text, p_reason_code text, p_reason_note text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_request_id uuid;
  v_note text;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if not exists (select 1 from public.profiles where id = v_user_id and active) then
    raise exception 'no_active_profile';
  end if;

  if not exists (select 1 from public.production_days where id = p_production_day_id) then
    raise exception 'production_day_not_found';
  end if;

  if not exists (select 1 from public.products where id = p_product_id and active) then
    raise exception 'product_not_found';
  end if;

  if p_requested_quantity is null or p_requested_quantity <= 0 then
    raise exception 'invalid_quantity';
  end if;

  if p_unit is null or btrim(p_unit) = '' then
    raise exception 'invalid_unit';
  end if;

  if p_shift_code is null or p_shift_code not in ('morning', 'afternoon', 'night') then
    raise exception 'invalid_shift';
  end if;

  if p_reason_code is null or p_reason_code not in ('replenishment', 'increased_demand', 'remake', 'other') then
    raise exception 'invalid_reason';
  end if;

  if p_reason_code = 'other' and (p_reason_note is null or btrim(p_reason_note) = '') then
    raise exception 'reason_note_required';
  end if;

  v_note := nullif(btrim(coalesce(p_reason_note, '')), '');

  insert into public.production_requests (
    production_day_id, source_type, shift_code, product_id,
    requested_quantity, unit, reason_code, reason_note, status, created_by
  ) values (
    p_production_day_id, 'additional', p_shift_code, p_product_id,
    p_requested_quantity, btrim(p_unit), p_reason_code, v_note, 'pending', v_user_id
  )
  returning id into v_request_id;

  return v_request_id;
end;
$$;


--
-- Name: FUNCTION create_additional_production_request(p_production_day_id uuid, p_product_id uuid, p_requested_quantity numeric, p_unit text, p_shift_code text, p_reason_code text, p_reason_note text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.create_additional_production_request(p_production_day_id uuid, p_product_id uuid, p_requested_quantity numeric, p_unit text, p_shift_code text, p_reason_code text, p_reason_note text) IS 'Creates one additional production request (source_type=additional, status=pending) with a required reason_code (a non-empty reason_note when other); returns the new request id.';


--
-- Name: create_brand(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_brand(p_name text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_role text;
  v_name text;
  v_new_id uuid;
begin
  -- 1. Authentication and active profile.
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  select role into v_role
  from public.profiles
  where id = v_user_id and active;

  if v_role is null then
    raise exception 'no_active_profile';
  end if;

  -- 2. Role gate: only admin manages master data.
  if v_role <> 'admin' then
    raise exception 'insufficient_role';
  end if;

  -- 3. Validation.
  v_name := trim(coalesce(p_name, ''));
  if v_name = '' then
    raise exception 'invalid_name';
  end if;

  -- 4. Insert and return the new id.
  insert into public.brands (name)
  values (v_name)
  returning id into v_new_id;

  return v_new_id;
end;
$$;


--
-- Name: create_external_order(text, text, date, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_external_order(p_order_number text, p_customer_name text, p_requested_date date, p_delivery_time text, p_notes text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: create_product(text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_product(p_name text, p_default_unit text, p_default_shift_code text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_role text;
  v_name text;
  v_unit text;
  v_shift text;
  v_new_id uuid;
begin
  -- 1. Authentication and active profile.
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  select role into v_role
  from public.profiles
  where id = v_user_id and active;

  if v_role is null then
    raise exception 'no_active_profile';
  end if;

  -- 2. Role gate: only admin manages master data.
  if v_role <> 'admin' then
    raise exception 'insufficient_role';
  end if;

  -- 3. Validation.
  v_name := trim(coalesce(p_name, ''));
  if v_name = '' then
    raise exception 'invalid_name';
  end if;

  v_unit := trim(coalesce(p_default_unit, ''));
  if v_unit = '' then
    raise exception 'invalid_unit';
  end if;

  v_shift := trim(coalesce(p_default_shift_code, ''));
  if v_shift not in ('morning', 'afternoon', 'night') then
    raise exception 'invalid_shift';
  end if;

  -- 4. Insert and return the new id.
  insert into public.products (name, default_unit, default_shift_code)
  values (v_name, v_unit, v_shift)
  returning id into v_new_id;

  return v_new_id;
end;
$$;


--
-- Name: create_production_plan_item(smallint, text, uuid, numeric, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_production_plan_item(p_weekday smallint, p_shift_code text, p_product_id uuid, p_planned_quantity numeric, p_unit text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_role text;
  v_shift text;
  v_unit text;
  v_new_id uuid;
begin
  -- 1. Authentication and active profile.
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  select role into v_role
  from public.profiles
  where id = v_user_id and active;

  if v_role is null then
    raise exception 'no_active_profile';
  end if;

  -- 2. Role gate: only admin manages master data.
  if v_role <> 'admin' then
    raise exception 'insufficient_role';
  end if;

  -- 3. Validation.
  if p_weekday is null or p_weekday < 1 or p_weekday > 7 then
    raise exception 'invalid_weekday';
  end if;

  v_shift := trim(coalesce(p_shift_code, ''));
  if v_shift not in ('morning', 'afternoon', 'night') then
    raise exception 'invalid_shift';
  end if;

  if not exists (select 1 from public.products where id = p_product_id) then
    raise exception 'product_not_found';
  end if;

  if p_planned_quantity is null or p_planned_quantity <= 0 then
    raise exception 'invalid_quantity';
  end if;

  v_unit := trim(coalesce(p_unit, ''));
  if v_unit = '' then
    raise exception 'invalid_unit';
  end if;

  -- At most one ACTIVE row per (weekday, shift, product, unit).
  if exists (
    select 1
    from public.production_plan_items
    where weekday = p_weekday
      and shift_code = v_shift
      and product_id = p_product_id
      and unit = v_unit
      and active
  ) then
    raise exception 'already_planned';
  end if;

  -- 4. Insert with the next sort_order within the weekday + shift group.
  insert into public.production_plan_items
    (weekday, shift_code, product_id, planned_quantity, unit, sort_order)
  values
    (
      p_weekday,
      v_shift,
      p_product_id,
      p_planned_quantity,
      v_unit,
      (
        select coalesce(max(sort_order), 0) + 1
        from public.production_plan_items
        where weekday = p_weekday and shift_code = v_shift
      )
    )
  returning id into v_new_id;

  return v_new_id;
end;
$$;


--
-- Name: create_raw_material(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_raw_material(p_name text, p_default_unit text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_role text;
  v_name text;
  v_unit text;
  v_new_id uuid;
begin
  -- 1. Authentication and active profile.
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  select role into v_role
  from public.profiles
  where id = v_user_id and active;

  if v_role is null then
    raise exception 'no_active_profile';
  end if;

  -- 2. Role gate: only admin manages master data.
  if v_role <> 'admin' then
    raise exception 'insufficient_role';
  end if;

  -- 3. Validation.
  v_name := trim(coalesce(p_name, ''));
  if v_name = '' then
    raise exception 'invalid_name';
  end if;

  v_unit := trim(coalesce(p_default_unit, ''));
  if v_unit = '' then
    raise exception 'invalid_unit';
  end if;

  if exists (select 1 from public.raw_materials where lower(name) = lower(v_name)) then
    raise exception 'raw_material_name_exists';
  end if;

  -- 4. Insert and return the new id.
  insert into public.raw_materials (name, default_unit)
  values (v_name, v_unit)
  returning id into v_new_id;

  return v_new_id;
end;
$$;


--
-- Name: create_recipe(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_recipe(p_name text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_role text;
  v_name text;
  v_new_id uuid;
begin
  -- 1. Authentication and active profile.
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  select role into v_role
  from public.profiles
  where id = v_user_id and active;

  if v_role is null then
    raise exception 'no_active_profile';
  end if;

  -- 2. Role gate: only admin manages master data.
  if v_role <> 'admin' then
    raise exception 'insufficient_role';
  end if;

  -- 3. Validation.
  v_name := trim(coalesce(p_name, ''));
  if v_name = '' then
    raise exception 'invalid_name';
  end if;

  -- 4. Insert and return the new id.
  insert into public.recipes (name)
  values (v_name)
  returning id into v_new_id;

  return v_new_id;
end;
$$;


--
-- Name: ensure_base_production_requests(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ensure_base_production_requests(p_production_day_id uuid) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_production_date date;
  v_weekday smallint;
  v_created integer := 0;
  rec record;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if not exists (select 1 from public.profiles where id = v_user_id and active) then
    raise exception 'no_active_profile';
  end if;

  select production_date into v_production_date
  from public.production_days
  where id = p_production_day_id;

  if not found then
    raise exception 'production_day_not_found';
  end if;

  -- Serialize concurrent generation for the same day.
  perform 1
  from public.production_days
  where id = p_production_day_id
  for update;

  -- ISO weekday of the STORED production date: 1 = Monday ... 7 = Sunday.
  v_weekday := extract(isodow from v_production_date)::smallint;

  for rec in
    select product_id, shift_code, planned_quantity, unit
    from public.production_plan_items
    where weekday = v_weekday
      and active
    order by sort_order, id
  loop
    if not exists (
      select 1
      from public.production_requests r
      where r.production_day_id = p_production_day_id
        and r.source_type = 'base'
        and r.product_id = rec.product_id
        and r.shift_code = rec.shift_code
    ) then
      insert into public.production_requests (
        production_day_id, source_type, shift_code, product_id,
        requested_quantity, unit, status, created_by
      ) values (
        p_production_day_id, 'base', rec.shift_code, rec.product_id,
        rec.planned_quantity, rec.unit, 'pending', v_user_id
      );
      v_created := v_created + 1;
    end if;
  end loop;

  return v_created;
end;
$$;


--
-- Name: FUNCTION ensure_base_production_requests(p_production_day_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.ensure_base_production_requests(p_production_day_id uuid) IS 'Idempotently creates base production requests (source_type=base, status=pending) for one production day from the active weekly plan items of the stored production date''s ISO weekday; returns the number created.';


--
-- Name: ensure_external_order_requests(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ensure_external_order_requests(p_production_day_id uuid) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_production_date date;
  v_created integer := 0;
  rec record;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if not exists (select 1 from public.profiles where id = v_user_id and active) then
    raise exception 'no_active_profile';
  end if;

  select production_date into v_production_date
  from public.production_days
  where id = p_production_day_id;

  if not found then
    raise exception 'production_day_not_found';
  end if;

  -- Serialize concurrent generation for the same day.
  perform 1
  from public.production_days
  where id = p_production_day_id
  for update;

  for rec in
    select i.id as item_id, i.product_id, i.quantity, i.unit, i.shift_code
    from public.external_order_items i
    join public.external_orders o on o.id = i.external_order_id
    where o.requested_date = v_production_date
      and o.status <> 'cancelled'
    order by i.id
  loop
    if not exists (
      select 1
      from public.production_requests r
      where r.production_day_id = p_production_day_id
        and r.source_type = 'external_order'
        and r.external_order_item_id = rec.item_id
    ) then
      insert into public.production_requests (
        production_day_id, source_type, shift_code, product_id,
        requested_quantity, unit, external_order_item_id, status, created_by
      ) values (
        p_production_day_id, 'external_order', rec.shift_code, rec.product_id,
        rec.quantity, rec.unit, rec.item_id, 'pending', v_user_id
      );
      v_created := v_created + 1;
    end if;
  end loop;

  return v_created;
end;
$$;


--
-- Name: FUNCTION ensure_external_order_requests(p_production_day_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.ensure_external_order_requests(p_production_day_id uuid) IS 'Idempotently creates external-order production requests (source_type=external_order, status=pending) for one production day from the non-cancelled external orders of the stored production date; returns the number created.';


--
-- Name: ensure_production_day(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ensure_production_day() RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: FUNCTION ensure_production_day(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.ensure_production_day() IS 'Idempotently ensures the current business production day (America/Argentina/Cordoba) exists with status open; returns the production_day id. Date comes from get_business_date(), never from the client.';


--
-- Name: get_business_date(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_business_date() RETURNS date
    LANGUAGE sql
    AS $$
	select (now() at time zone 'America/Argentina/Cordoba')::date
$$;


--
-- Name: FUNCTION get_business_date(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_business_date() IS 'Current date in America/Argentina/Cordoba; the single source for production_date. Never derive it from UTC, toISOString(), browser or Node timezones.';


--
-- Name: next_batch_code(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.next_batch_code(p_production_day_id uuid, p_shift_code text) RETURNS text
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $_$
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
$_$;


--
-- Name: FUNCTION next_batch_code(p_production_day_id uuid, p_shift_code text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.next_batch_code(p_production_day_id uuid, p_shift_code text) IS 'Generates the next PAN-DDMMYY-X-NNN batch code for a production day and shift; sequence resets by stored production_date + shift_code; transaction-scoped advisory lock makes generation concurrency-safe when the batch insert happens in the same transaction.';


--
-- Name: reject_parent_batch_self_reference(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_parent_batch_self_reference() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: set_brand_active(uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_brand_active(p_id uuid, p_active boolean) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_role text;
begin
  -- 1. Authentication and active profile.
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  select role into v_role
  from public.profiles
  where id = v_user_id and active;

  if v_role is null then
    raise exception 'no_active_profile';
  end if;

  -- 2. Role gate: only admin manages master data.
  if v_role <> 'admin' then
    raise exception 'insufficient_role';
  end if;

  -- 3. Validation.
  if not exists (select 1 from public.brands where id = p_id) then
    raise exception 'brand_not_found';
  end if;

  -- 4. Deactivation is soft (active = false); no physical delete.
  update public.brands
  set active = p_active,
      updated_at = now()
  where id = p_id;

  return p_id;
end;
$$;


--
-- Name: set_product_active(uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_product_active(p_id uuid, p_active boolean) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_role text;
begin
  -- 1. Authentication and active profile.
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  select role into v_role
  from public.profiles
  where id = v_user_id and active;

  if v_role is null then
    raise exception 'no_active_profile';
  end if;

  -- 2. Role gate: only admin manages master data.
  if v_role <> 'admin' then
    raise exception 'insufficient_role';
  end if;

  -- 3. Validation.
  if not exists (select 1 from public.products where id = p_id) then
    raise exception 'product_not_found';
  end if;

  -- 4. Deactivation is soft (active = false); no physical delete.
  update public.products
  set active = p_active,
      updated_at = now()
  where id = p_id;

  return p_id;
end;
$$;


--
-- Name: set_production_plan_item_active(uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_production_plan_item_active(p_id uuid, p_active boolean) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_role text;
  v_item production_plan_items;
begin
  -- 1. Authentication and active profile.
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  select role into v_role
  from public.profiles
  where id = v_user_id and active;

  if v_role is null then
    raise exception 'no_active_profile';
  end if;

  -- 2. Role gate: only admin manages master data.
  if v_role <> 'admin' then
    raise exception 'insufficient_role';
  end if;

  -- 3. Validation.
  select * into v_item
  from public.production_plan_items
  where id = p_id;

  if not found then
    raise exception 'production_plan_item_not_found';
  end if;

  -- Enabling would break the one-active-per-key rule if another active row
  -- already occupies the same (weekday, shift, product, unit).
  if p_active and exists (
    select 1
    from public.production_plan_items
    where weekday = v_item.weekday
      and shift_code = v_item.shift_code
      and product_id = v_item.product_id
      and unit = v_item.unit
      and active
      and id <> p_id
  ) then
    raise exception 'already_planned';
  end if;

  -- 4. Deactivation is soft (active = false); no physical delete.
  update public.production_plan_items
  set active = p_active,
      updated_at = now()
  where id = p_id;

  return p_id;
end;
$$;


--
-- Name: set_raw_material_active(uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_raw_material_active(p_id uuid, p_active boolean) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_role text;
begin
  -- 1. Authentication and active profile.
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  select role into v_role
  from public.profiles
  where id = v_user_id and active;

  if v_role is null then
    raise exception 'no_active_profile';
  end if;

  -- 2. Role gate: only admin manages master data.
  if v_role <> 'admin' then
    raise exception 'insufficient_role';
  end if;

  -- 3. Validation.
  if not exists (select 1 from public.raw_materials where id = p_id) then
    raise exception 'raw_material_not_found';
  end if;

  -- 4. Deactivation is soft (active = false); no physical delete.
  update public.raw_materials
  set active = p_active,
      updated_at = now()
  where id = p_id;

  return p_id;
end;
$$;


--
-- Name: set_recipe_active(uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_recipe_active(p_id uuid, p_active boolean) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_role text;
begin
  -- 1. Authentication and active profile.
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  select role into v_role
  from public.profiles
  where id = v_user_id and active;

  if v_role is null then
    raise exception 'no_active_profile';
  end if;

  -- 2. Role gate: only admin manages master data.
  if v_role <> 'admin' then
    raise exception 'insufficient_role';
  end if;

  -- 3. Validation.
  if not exists (select 1 from public.recipes where id = p_id) then
    raise exception 'recipe_not_found';
  end if;

  -- 4. Deactivation is soft (active = false); no physical delete.
  update public.recipes
  set active = p_active,
      updated_at = now()
  where id = p_id;

  return p_id;
end;
$$;


--
-- Name: start_production_batch(uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.start_production_batch(p_production_request_id uuid, p_product_inputs jsonb DEFAULT NULL::jsonb) RETURNS public.start_production_batch_result
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_request_status text;
  v_product_id uuid;
  v_day_id uuid;
  v_shift_code text;
  v_requested_quantity numeric;
  v_recipe_count int;
  v_version_id uuid;
  v_missing_materials text;
  v_batch_id uuid;
  v_batch_code text;
  v_required_input_count int;
  v_input_total int;
  v_input_distinct int;
  v_source_raw text;
  v_parent_raw text;
  v_source_id uuid;
  v_parent_id uuid;
  v_output_product uuid;
  v_output_status text;
begin
  -- 1. Auth (established model).
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if not exists (select 1 from public.profiles where id = v_user_id and active) then
    raise exception 'no_active_profile';
  end if;

  -- 2. Request exists and is pending. FOR UPDATE serializes concurrent starts
  --    of the same request (see header).
  select r.status, r.product_id, r.production_day_id, r.shift_code, r.requested_quantity
    into v_request_status, v_product_id, v_day_id, v_shift_code, v_requested_quantity
  from public.production_requests r
  where r.id = p_production_request_id
  for update;

  if v_request_status is null then
    raise exception 'production_request_not_found';
  end if;

  if v_request_status <> 'pending' then
    raise exception 'request_not_pending';
  end if;

  -- 3. Resolve the active recipe_version for the product (AC1 logic).
  select count(distinct rp.recipe_id)
    into v_recipe_count
  from public.recipe_products rp
  join public.recipe_versions rv on rv.recipe_id = rp.recipe_id and rv.status = 'active'
  where rp.product_id = v_product_id;

  if v_recipe_count = 0 then
    if not exists (select 1 from public.recipe_products rp where rp.product_id = v_product_id) then
      raise exception 'no_recipe';
    end if;
    raise exception 'no_active_version';
  end if;

  if v_recipe_count > 1 then
    raise exception 'ambiguous_recipes';
  end if;

  select rv.id
    into v_version_id
  from public.recipe_products rp
  join public.recipe_versions rv on rv.recipe_id = rp.recipe_id and rv.status = 'active'
  where rp.product_id = v_product_id;

  -- 4. Validate required current material lots (AE1 logic). Missing optional
  --    ingredients are allowed (they simply are not snapshotted).
  select coalesce(string_agg(rm.name, ', ' order by ri.sort_order), '')
    into v_missing_materials
  from public.recipe_ingredients ri
  join public.raw_materials rm on rm.id = ri.raw_material_id
  where ri.recipe_version_id = v_version_id
    and not ri.optional
    and not exists (
      select 1
      from public.material_lots ml
      where ml.raw_material_id = ri.raw_material_id
        and ml.is_current
    );

  if v_missing_materials <> '' then
    raise exception 'missing_material_lot: %', v_missing_materials;
  end if;

  -- 4b. Produced-product inputs (AP1, guide phase AP). The operator selects
  --     the physical source lot for every required input; the RPC only
  --     validates and records the choice - it never picks one itself.
  select count(*)
    into v_required_input_count
  from public.recipe_product_inputs
  where recipe_version_id = v_version_id
    and required;

  if v_required_input_count > 0 then
    if p_product_inputs is null or jsonb_typeof(p_product_inputs) <> 'array'
      or jsonb_array_length(p_product_inputs) = 0 then
      raise exception 'missing_product_input';
    end if;

    select count(*), count(distinct value->>'source_product_id')
      into v_input_total, v_input_distinct
    from jsonb_array_elements(p_product_inputs) e(value);

    if v_input_total <> v_input_distinct then
      raise exception 'duplicate_product_input';
    end if;

    if v_input_total < v_required_input_count then
      raise exception 'missing_product_input';
    end if;

    for v_source_raw, v_parent_raw in
      select e.value->>'source_product_id', e.value->>'parent_batch_output_id'
      from jsonb_array_elements(p_product_inputs) e(value)
    loop
      if v_source_raw is null or v_parent_raw is null then
        raise exception 'invalid_product_input';
      end if;

      begin
        v_source_id := v_source_raw::uuid;
      exception
        when others then
          raise exception 'invalid_product_input';
      end;

      begin
        v_parent_id := v_parent_raw::uuid;
      exception
        when others then
          raise exception 'invalid_product_input';
      end;

      -- The selected product must be one of the recipe's required inputs;
      -- extra selections (total > count) fail here.
      if not exists (
        select 1
        from public.recipe_product_inputs rpi
        where rpi.recipe_version_id = v_version_id
          and rpi.required
          and rpi.source_product_id = v_source_id
      ) then
        raise exception 'input_not_in_recipe';
      end if;

      -- The parent output must exist, belong to a COMPLETED batch (only
      -- finished productions can be physical inputs), and be an output of
      -- exactly the declared source product.
      select bo.product_id, b.status
        into v_output_product, v_output_status
      from public.batch_outputs bo
      join public.production_batches b on b.id = bo.batch_id
      where bo.id = v_parent_id;

      if v_output_product is null
        or v_output_product <> v_source_id
        or v_output_status <> 'completed' then
        raise exception 'invalid_product_input';
      end if;
    end loop;
  elsif p_product_inputs is not null
    and jsonb_typeof(p_product_inputs) = 'array'
    and jsonb_array_length(p_product_inputs) > 0 then
    -- Selections were sent although the recipe requires no product inputs.
    raise exception 'input_not_in_recipe';
  end if;

  -- 5. Safe batch code (AD1); the advisory xact lock is held until this
  --    transaction commits, covering the insert below.
  v_batch_code := public.next_batch_code(v_day_id, v_shift_code);

  -- 6. Create the batch; the request's shift is copied (historical).
  insert into public.production_batches
    (production_day_id, recipe_version_id, shift_code, batch_code, status, started_at, started_by)
  values (v_day_id, v_version_id, v_shift_code, v_batch_code, 'in_progress', now(), v_user_id)
  returning id into v_batch_id;

  -- 7. Snapshot the EXACT current lots (required + present optional).
  insert into public.batch_materials (batch_id, raw_material_id, material_lot_id, recipe_quantity, recipe_unit)
  select v_batch_id, ri.raw_material_id, ml.id, ri.quantity, ri.unit
  from public.recipe_ingredients ri
  join public.material_lots ml on ml.raw_material_id = ri.raw_material_id and ml.is_current
  where ri.recipe_version_id = v_version_id;

  -- 7b. Store the EXACT parent output relations (AP1). Quantity and unit are
  --     copied from the parent output (exact physical source, same
  --     snapshot principle as step 7); every element was validated in 4b.
  if v_required_input_count > 0 then
    insert into public.parent_batch_inputs (child_batch_id, parent_batch_output_id, quantity, unit)
    select v_batch_id, bo.id, bo.quantity, bo.unit
    from jsonb_array_elements(p_product_inputs) e(value)
    cross join public.batch_outputs bo
    where bo.id = (e.value->>'parent_batch_output_id')::uuid;
  end if;

  -- 8. Link the batch to the request.
  insert into public.batch_requests (batch_id, production_request_id, allocated_quantity)
  values (v_batch_id, p_production_request_id, v_requested_quantity);

  -- 9. Advance the request.
  update public.production_requests
  set status = 'in_progress'
  where id = p_production_request_id;

  -- 10. Result.
  return (v_batch_id, v_batch_code);
end;
$$;


--
-- Name: FUNCTION start_production_batch(p_production_request_id uuid, p_product_inputs jsonb); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.start_production_batch(p_production_request_id uuid, p_product_inputs jsonb) IS 'Starts a production batch for one pending request: validates auth/profile, resolves the active recipe_version, validates required current material lots (fails with missing_material_lot: <names>), validates produced-product input selections (one operator-chosen completed parent batch_output per required recipe_product_inputs; missing_product_input / duplicate_product_input / input_not_in_recipe / invalid_product_input), generates the safe PAN-DDMMYY-X-NNN code in-transaction, snapshots exact material lots into batch_materials and exact parent outputs into parent_batch_inputs, links the request and sets it in_progress; atomic, all-or-nothing.';


--
-- Name: update_brand(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_brand(p_id uuid, p_name text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_role text;
  v_name text;
begin
  -- 1. Authentication and active profile.
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  select role into v_role
  from public.profiles
  where id = v_user_id and active;

  if v_role is null then
    raise exception 'no_active_profile';
  end if;

  -- 2. Role gate: only admin manages master data.
  if v_role <> 'admin' then
    raise exception 'insufficient_role';
  end if;

  -- 3. Validation.
  if not exists (select 1 from public.brands where id = p_id) then
    raise exception 'brand_not_found';
  end if;

  v_name := trim(coalesce(p_name, ''));
  if v_name = '' then
    raise exception 'invalid_name';
  end if;

  -- 4. Update and return the id.
  update public.brands
  set name = v_name,
      updated_at = now()
  where id = p_id;

  return p_id;
end;
$$;


--
-- Name: update_product(uuid, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_product(p_id uuid, p_name text, p_default_unit text, p_default_shift_code text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_role text;
  v_name text;
  v_unit text;
  v_shift text;
begin
  -- 1. Authentication and active profile.
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  select role into v_role
  from public.profiles
  where id = v_user_id and active;

  if v_role is null then
    raise exception 'no_active_profile';
  end if;

  -- 2. Role gate: only admin manages master data.
  if v_role <> 'admin' then
    raise exception 'insufficient_role';
  end if;

  -- 3. Validation.
  if not exists (select 1 from public.products where id = p_id) then
    raise exception 'product_not_found';
  end if;

  v_name := trim(coalesce(p_name, ''));
  if v_name = '' then
    raise exception 'invalid_name';
  end if;

  v_unit := trim(coalesce(p_default_unit, ''));
  if v_unit = '' then
    raise exception 'invalid_unit';
  end if;

  v_shift := trim(coalesce(p_default_shift_code, ''));
  if v_shift not in ('morning', 'afternoon', 'night') then
    raise exception 'invalid_shift';
  end if;

  -- 4. Update and return the id. Historical shifts already copied into
  -- production_requests/production_batches are never touched.
  update public.products
  set name = v_name,
      default_unit = v_unit,
      default_shift_code = v_shift,
      updated_at = now()
  where id = p_id;

  return p_id;
end;
$$;


--
-- Name: update_production_plan_item(uuid, smallint, text, uuid, numeric, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_production_plan_item(p_id uuid, p_weekday smallint, p_shift_code text, p_product_id uuid, p_planned_quantity numeric, p_unit text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_role text;
  v_shift text;
  v_unit text;
begin
  -- 1. Authentication and active profile.
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  select role into v_role
  from public.profiles
  where id = v_user_id and active;

  if v_role is null then
    raise exception 'no_active_profile';
  end if;

  -- 2. Role gate: only admin manages master data.
  if v_role <> 'admin' then
    raise exception 'insufficient_role';
  end if;

  -- 3. Validation.
  if not exists (select 1 from public.production_plan_items where id = p_id) then
    raise exception 'production_plan_item_not_found';
  end if;

  if p_weekday is null or p_weekday < 1 or p_weekday > 7 then
    raise exception 'invalid_weekday';
  end if;

  v_shift := trim(coalesce(p_shift_code, ''));
  if v_shift not in ('morning', 'afternoon', 'night') then
    raise exception 'invalid_shift';
  end if;

  if not exists (select 1 from public.products where id = p_product_id) then
    raise exception 'product_not_found';
  end if;

  if p_planned_quantity is null or p_planned_quantity <= 0 then
    raise exception 'invalid_quantity';
  end if;

  v_unit := trim(coalesce(p_unit, ''));
  if v_unit = '' then
    raise exception 'invalid_unit';
  end if;

  -- At most one ACTIVE row per (weekday, shift, product, unit), excluding
  -- this row itself.
  if exists (
    select 1
    from public.production_plan_items
    where weekday = p_weekday
      and shift_code = v_shift
      and product_id = p_product_id
      and unit = v_unit
      and active
      and id <> p_id
  ) then
    raise exception 'already_planned';
  end if;

  -- 4. Update. sort_order is preserved (position in the plan is stable).
  update public.production_plan_items
  set weekday = p_weekday,
      shift_code = v_shift,
      product_id = p_product_id,
      planned_quantity = p_planned_quantity,
      unit = v_unit,
      updated_at = now()
  where id = p_id;

  return p_id;
end;
$$;


--
-- Name: update_raw_material(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_raw_material(p_id uuid, p_name text, p_default_unit text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_role text;
  v_name text;
  v_unit text;
begin
  -- 1. Authentication and active profile.
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  select role into v_role
  from public.profiles
  where id = v_user_id and active;

  if v_role is null then
    raise exception 'no_active_profile';
  end if;

  -- 2. Role gate: only admin manages master data.
  if v_role <> 'admin' then
    raise exception 'insufficient_role';
  end if;

  -- 3. Validation.
  if not exists (select 1 from public.raw_materials where id = p_id) then
    raise exception 'raw_material_not_found';
  end if;

  v_name := trim(coalesce(p_name, ''));
  if v_name = '' then
    raise exception 'invalid_name';
  end if;

  v_unit := trim(coalesce(p_default_unit, ''));
  if v_unit = '' then
    raise exception 'invalid_unit';
  end if;

  if exists (
    select 1 from public.raw_materials
    where lower(name) = lower(v_name) and id <> p_id
  ) then
    raise exception 'raw_material_name_exists';
  end if;

  -- 4. Update and return the id.
  update public.raw_materials
  set name = v_name,
      default_unit = v_unit,
      updated_at = now()
  where id = p_id;

  return p_id;
end;
$$;


--
-- Name: update_recipe(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_recipe(p_id uuid, p_name text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_user_id uuid;
  v_role text;
  v_name text;
begin
  -- 1. Authentication and active profile.
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  select role into v_role
  from public.profiles
  where id = v_user_id and active;

  if v_role is null then
    raise exception 'no_active_profile';
  end if;

  -- 2. Role gate: only admin manages master data.
  if v_role <> 'admin' then
    raise exception 'insufficient_role';
  end if;

  -- 3. Validation.
  if not exists (select 1 from public.recipes where id = p_id) then
    raise exception 'recipe_not_found';
  end if;

  v_name := trim(coalesce(p_name, ''));
  if v_name = '' then
    raise exception 'invalid_name';
  end if;

  -- 4. Update and return the id.
  update public.recipes
  set name = v_name,
      updated_at = now()
  where id = p_id;

  return p_id;
end;
$$;


--
-- Name: apply_rls(jsonb, integer); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.apply_rls(wal jsonb, max_record_bytes integer DEFAULT (1024 * 1024)) RETURNS SETOF realtime.wal_rls
    LANGUAGE plpgsql
    AS $$
declare
    -- Regclass of the table e.g. public.notes
    entity_ regclass = (quote_ident(wal ->> 'schema') || '.' || quote_ident(wal ->> 'table'))::regclass;

    -- I, U, D, T: insert, update ...
    action realtime.action = (
        case wal ->> 'action'
            when 'I' then 'INSERT'
            when 'U' then 'UPDATE'
            when 'D' then 'DELETE'
            else 'ERROR'
        end
    );

    -- Is row level security enabled for the table
    is_rls_enabled bool = relrowsecurity from pg_class where oid = entity_;

    subscriptions realtime.subscription[] = array_agg(subs)
        from
            realtime.subscription subs
        where
            subs.entity = entity_
            -- Filter by action early - only get subscriptions interested in this action
            -- action_filter column can be: '*' (all), 'INSERT', 'UPDATE', or 'DELETE'
            and (subs.action_filter = '*' or subs.action_filter = action::text);

    -- Subscription vars
    working_role regrole;
    working_selected_columns text[];
    claimed_role regrole;
    claims jsonb;

    subscription_id uuid;
    subscription_has_access bool;
    visible_to_subscription_ids uuid[] = '{}';

    -- structured info for wal's columns
    columns realtime.wal_column[];
    -- previous identity values for update/delete
    old_columns realtime.wal_column[];

    error_record_exceeds_max_size boolean = octet_length(wal::text) > max_record_bytes;

    -- Primary jsonb output for record
    output jsonb;

    -- Loop record for iterating unique roles (outer loop)
    role_record record;
    -- Loop record for iterating unique selected_columns within a role (inner loop)
    cols_record record;
    -- Subscription ids visible at the role level (before fanning out by selected_columns)
    visible_role_sub_ids uuid[] = '{}';

begin
    perform set_config('role', null, true);

    columns =
        array_agg(
            (
                x->>'name',
                x->>'type',
                x->>'typeoid',
                realtime.cast(
                    (x->'value') #>> '{}',
                    coalesce(
                        (x->>'typeoid')::regtype, -- null when wal2json version <= 2.4
                        (x->>'type')::regtype
                    )
                ),
                (pks ->> 'name') is not null,
                true
            )::realtime.wal_column
        )
        from
            jsonb_array_elements(wal -> 'columns') x
            left join jsonb_array_elements(wal -> 'pk') pks
                on (x ->> 'name') = (pks ->> 'name');

    old_columns =
        array_agg(
            (
                x->>'name',
                x->>'type',
                x->>'typeoid',
                realtime.cast(
                    (x->'value') #>> '{}',
                    coalesce(
                        (x->>'typeoid')::regtype, -- null when wal2json version <= 2.4
                        (x->>'type')::regtype
                    )
                ),
                (pks ->> 'name') is not null,
                true
            )::realtime.wal_column
        )
        from
            jsonb_array_elements(wal -> 'identity') x
            left join jsonb_array_elements(wal -> 'pk') pks
                on (x ->> 'name') = (pks ->> 'name');

    for role_record in
        select claims_role
        from (select distinct claims_role from unnest(subscriptions)) t
        order by claims_role::text
    loop
        working_role := role_record.claims_role;

        -- Update `is_selectable` for columns and old_columns (once per role)
        columns =
            array_agg(
                (
                    c.name,
                    c.type_name,
                    c.type_oid,
                    c.value,
                    c.is_pkey,
                    pg_catalog.has_column_privilege(working_role, entity_, c.name, 'SELECT')
                )::realtime.wal_column
            )
            from
                unnest(columns) c;

        old_columns =
                array_agg(
                    (
                        c.name,
                        c.type_name,
                        c.type_oid,
                        c.value,
                        c.is_pkey,
                        pg_catalog.has_column_privilege(working_role, entity_, c.name, 'SELECT')
                    )::realtime.wal_column
                )
                from
                    unnest(old_columns) c;

        if action <> 'DELETE' and count(1) = 0 from unnest(columns) c where c.is_pkey then
            -- Fan out 400 error per distinct selected_columns for this role
            for cols_record in
                select selected_columns
                from (select distinct selected_columns from unnest(subscriptions) s where s.claims_role = working_role) t
                order by coalesce(array_to_string(selected_columns, ','), '')
            loop
                working_selected_columns := cols_record.selected_columns;
                return next (
                    jsonb_build_object(
                        'schema', wal ->> 'schema',
                        'table', wal ->> 'table',
                        'type', action
                    ),
                    is_rls_enabled,
                    (select array_agg(s.subscription_id) from unnest(subscriptions) as s where s.claims_role = working_role and (s.selected_columns is not distinct from working_selected_columns)),
                    array['Error 400: Bad Request, no primary key']
                )::realtime.wal_rls;
            end loop;

        -- The claims role does not have SELECT permission to the primary key of entity
        elsif action <> 'DELETE' and sum(c.is_selectable::int) <> count(1) from unnest(columns) c where c.is_pkey then
            -- Fan out 401 error per distinct selected_columns for this role
            for cols_record in
                select selected_columns
                from (select distinct selected_columns from unnest(subscriptions) s where s.claims_role = working_role) t
                order by coalesce(array_to_string(selected_columns, ','), '')
            loop
                working_selected_columns := cols_record.selected_columns;
                return next (
                    jsonb_build_object(
                        'schema', wal ->> 'schema',
                        'table', wal ->> 'table',
                        'type', action
                    ),
                    is_rls_enabled,
                    (select array_agg(s.subscription_id) from unnest(subscriptions) as s where s.claims_role = working_role and (s.selected_columns is not distinct from working_selected_columns)),
                    array['Error 401: Unauthorized']
                )::realtime.wal_rls;
            end loop;

        else
            -- Create the prepared statement (once per role)
            if is_rls_enabled and action <> 'DELETE' then
                if (select 1 from pg_prepared_statements where name = 'walrus_rls_stmt' limit 1) > 0 then
                    deallocate walrus_rls_stmt;
                end if;
                execute realtime.build_prepared_statement_sql('walrus_rls_stmt', entity_, columns);
            end if;

            -- Collect all visible subscription IDs for this role (filter check + RLS check)
            visible_role_sub_ids = '{}';

            for subscription_id, claims in (
                    select
                        subs.subscription_id,
                        subs.claims
                    from
                        unnest(subscriptions) subs
                    where
                        subs.entity = entity_
                        and subs.claims_role = working_role
                        and (
                            realtime.is_visible_through_filters(columns, subs.filters)
                            or (
                              action = 'DELETE'
                              and realtime.is_visible_through_filters(old_columns, subs.filters)
                            )
                        )
            ) loop

                if not is_rls_enabled or action = 'DELETE' then
                    visible_role_sub_ids = visible_role_sub_ids || subscription_id;
                else
                    -- Check if RLS allows the role to see the record
                    perform
                        -- Trim leading and trailing quotes from working_role because set_config
                        -- doesn't recognize the role as valid if they are included
                        set_config('role', trim(both '"' from working_role::text), true),
                        set_config('request.jwt.claims', claims::text, true);

                    execute 'execute walrus_rls_stmt' into subscription_has_access;

                    -- Reset the role on every FOR..LOOP batch execution.
                    -- The first batch of 10 rows is pre-fetched using the current connection role (PG internal behaviour)
                    -- then we have to reset it again otherwise it would use the role defined in the `set_config` above
                    -- to fetch the remaining rows when rows>10, which could be a user-defined role that lacks execution grants.
                    -- The flow is:
                    --   1. run batch with conn role
                    --   2. set_config working_role
                    --   3. execute walrus
                    --   4. reset role (revert)
                    --   5. repeat
                    perform set_config('role', null, true);

                    if subscription_has_access then
                        visible_role_sub_ids = visible_role_sub_ids || subscription_id;
                    end if;
                end if;
            end loop;

            perform set_config('role', null, true);

            -- Inner loop: per distinct selected_columns for this role
            for cols_record in
                select selected_columns
                from (select distinct selected_columns from unnest(subscriptions) s where s.claims_role = working_role) t
                order by coalesce(array_to_string(selected_columns, ','), '')
            loop
                working_selected_columns := cols_record.selected_columns;

                output = jsonb_build_object(
                    'schema', wal ->> 'schema',
                    'table', wal ->> 'table',
                    'type', action,
                    'commit_timestamp', to_char(
                        ((wal ->> 'timestamp')::timestamptz at time zone 'utc'),
                        'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
                    ),
                    'columns', (
                        select
                            jsonb_agg(
                                jsonb_build_object(
                                    'name', pa.attname,
                                    'type', pt.typname
                                )
                                order by pa.attnum asc
                            )
                        from
                            pg_attribute pa
                            join pg_type pt
                                on pa.atttypid = pt.oid
                            left join (
                                select unnest(conkey) as pkey_attnum
                                from pg_constraint
                                where conrelid = entity_ and contype = 'p'
                            ) pk on pk.pkey_attnum = pa.attnum
                        where
                            attrelid = entity_
                            and attnum > 0
                            and pg_catalog.has_column_privilege(working_role, entity_, pa.attname, 'SELECT')
                            and (working_selected_columns is null or pa.attname = any(working_selected_columns) or pk.pkey_attnum is not null)
                    )
                )
                -- Add "record" key for insert and update
                || case
                    when action in ('INSERT', 'UPDATE') then
                        jsonb_build_object(
                            'record',
                            (
                                select
                                    jsonb_object_agg(
                                        -- if unchanged toast, get column name and value from old record
                                        coalesce((c).name, (oc).name),
                                        case
                                            when (c).name is null then (oc).value
                                            else (c).value
                                        end
                                    )
                                from
                                    unnest(columns) c
                                    full outer join unnest(old_columns) oc
                                        on (c).name = (oc).name
                                where
                                    coalesce((c).is_selectable, (oc).is_selectable)
                                    and (working_selected_columns is null or coalesce((c).name, (oc).name) = any(working_selected_columns) or coalesce((c).is_pkey, (oc).is_pkey))
                                    and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                            )
                        )
                    else '{}'::jsonb
                end
                -- Add "old_record" key for update and delete
                || case
                    when action = 'UPDATE' then
                        jsonb_build_object(
                                'old_record',
                                (
                                    select jsonb_object_agg((c).name, (c).value)
                                    from unnest(old_columns) c
                                    where
                                        (c).is_selectable
                                        and (working_selected_columns is null or (c).name = any(working_selected_columns) or (c).is_pkey)
                                        and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                                )
                            )
                    when action = 'DELETE' then
                        jsonb_build_object(
                            'old_record',
                            (
                                select jsonb_object_agg((c).name, (c).value)
                                from unnest(old_columns) c
                                where
                                    (c).is_selectable
                                    and (working_selected_columns is null or (c).name = any(working_selected_columns) or (c).is_pkey)
                                    and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                                    and ( not is_rls_enabled or (c).is_pkey ) -- if RLS enabled, we can't secure deletes so filter to pkey
                            )
                        )
                    else '{}'::jsonb
                end;

                -- Filter visible_role_sub_ids to those matching the current selected_columns group
                visible_to_subscription_ids = coalesce(
                    (
                        select array_agg(s.subscription_id)
                        from unnest(subscriptions) s
                        where s.claims_role = working_role
                          and (s.selected_columns is not distinct from working_selected_columns)
                          and s.subscription_id = any(visible_role_sub_ids)
                    ),
                    '{}'::uuid[]
                );

                return next (
                    output,
                    is_rls_enabled,
                    visible_to_subscription_ids,
                    case
                        when error_record_exceeds_max_size then array['Error 413: Payload Too Large']
                        else '{}'
                    end
                )::realtime.wal_rls;
            end loop;

        end if;
    end loop;

    perform set_config('role', null, true);
end;
$$;


--
-- Name: broadcast_changes(text, text, text, text, text, record, record, text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.broadcast_changes(topic_name text, event_name text, operation text, table_name text, table_schema text, new record, old record, level text DEFAULT 'ROW'::text) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- Declare a variable to hold the JSONB representation of the row
    row_data jsonb := '{}'::jsonb;
BEGIN
    IF level = 'STATEMENT' THEN
        RAISE EXCEPTION 'function can only be triggered for each row, not for each statement';
    END IF;
    -- Check the operation type and handle accordingly
    IF operation = 'INSERT' OR operation = 'UPDATE' OR operation = 'DELETE' THEN
        row_data := jsonb_build_object('old_record', OLD, 'record', NEW, 'operation', operation, 'table', table_name, 'schema', table_schema);
        PERFORM realtime.send (row_data, event_name, topic_name);
    ELSE
        RAISE EXCEPTION 'Unexpected operation type: %', operation;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to process the row: %', SQLERRM;
END;

$$;


--
-- Name: build_prepared_statement_sql(text, regclass, realtime.wal_column[]); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.build_prepared_statement_sql(prepared_statement_name text, entity regclass, columns realtime.wal_column[]) RETURNS text
    LANGUAGE sql
    AS $$
      /*
      Builds a sql string that, if executed, creates a prepared statement to
      tests retrive a row from *entity* by its primary key columns.
      Example
          select realtime.build_prepared_statement_sql('public.notes', '{"id"}'::text[], '{"bigint"}'::text[])
      */
          select
      'prepare ' || prepared_statement_name || ' as
          select
              exists(
                  select
                      1
                  from
                      ' || entity || '
                  where
                      ' || string_agg(quote_ident(pkc.name) || '=' || quote_nullable(pkc.value #>> '{}') , ' and ') || '
              )'
          from
              unnest(columns) pkc
          where
              pkc.is_pkey
          group by
              entity
      $$;


--
-- Name: cast(text, regtype); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime."cast"(val text, type_ regtype) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE
    AS $$
declare
  res jsonb;
begin
  if type_::text = 'bytea' then
    return to_jsonb(val);
  end if;
  execute format('select to_jsonb(%L::'|| type_::text || ')', val) into res;
  return res;
end
$$;


--
-- Name: check_equality_op(realtime.equality_op, regtype, text, text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$
/*
Casts *val_1* and *val_2* as type *type_* and check the *op* condition for truthiness
*/
declare
    op_symbol text = (
        case
            when op = 'eq' then '='
            when op = 'neq' then '!='
            when op = 'lt' then '<'
            when op = 'lte' then '<='
            when op = 'gt' then '>'
            when op = 'gte' then '>='
            when op = 'in' then '= any'
            else 'UNKNOWN OP'
        end
    );
    res boolean;
begin
    execute format(
        'select %L::'|| type_::text || ' ' || op_symbol
        || ' ( %L::'
        || (
            case
                when op = 'in' then type_::text || '[]'
                else type_::text end
        )
        || ')', val_1, val_2) into res;
    return res;
end;
$$;


--
-- Name: check_equality_op(realtime.equality_op, regtype, text, text, boolean); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text, negate boolean) RETURNS boolean
    LANGUAGE plpgsql STABLE
    AS $$
declare
    op_symbol text;
    res boolean;
begin
    -- IS DISTINCT FROM / IS NOT DISTINCT FROM: infix, both sides typed literals
    if op = 'isdistinct' then
        execute format(
            'select %L::%s %s %L::%s',
            val_1,
            type_::text,
            case when negate then 'IS NOT DISTINCT FROM' else 'IS DISTINCT FROM' end,
            val_2,
            type_::text
        ) into res;
        return res;
    end if;

    -- IS requires a keyword RHS (NULL, TRUE, FALSE, UNKNOWN), not a typed literal
    if op = 'is' then
        if val_2 not in ('null', 'true', 'false', 'unknown') then
            raise exception 'invalid value for is filter: must be null, true, false, or unknown';
        end if;
        execute format(
            'select %L::%s %s %s',
            val_1,
            type_::text,
            case when negate then 'IS NOT' else 'IS' end,
            upper(val_2)
        ) into res;
        return res;
    end if;

    op_symbol = case
        when op = 'eq'    then '='
        when op = 'neq'   then '!='
        when op = 'lt'    then '<'
        when op = 'lte'   then '<='
        when op = 'gt'    then '>'
        when op = 'gte'   then '>='
        when op = 'in'    then '= any'
        when op = 'like'   then 'LIKE'
        when op = 'ilike'  then 'ILIKE'
        when op = 'match'  then '~'
        when op = 'imatch' then '~*'
        else null
    end;

    if op_symbol is null then
        raise exception 'unsupported equality operator: %', op::text;
    end if;

    execute format(
        'select %L::%s %s (%L::%s)',
        val_1,
        type_::text,
        op_symbol,
        val_2,
        case when op = 'in' then type_::text || '[]' else type_::text end
    ) into res;

    return case when negate then not res else res end;
end;
$$;


--
-- Name: is_visible_through_filters(realtime.wal_column[], realtime.user_defined_filter[]); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.is_visible_through_filters(columns realtime.wal_column[], filters realtime.user_defined_filter[]) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
    select
        filters is null
        or array_length(filters, 1) is null
        or coalesce(
            count(col.name) = count(1)
            and sum(
                realtime.check_equality_op(
                    op:=f.op,
                    type_:=coalesce(col.type_oid::regtype, col.type_name::regtype),
                    val_1:=col.value #>> '{}',
                    val_2:=f.value,
                    negate:=coalesce(f.negate, false)
                )::int
            ) filter (where col.name is not null) = count(col.name),
            false
        )
    from
        unnest(filters) f
        left join unnest(columns) col
            on f.column_name = col.name;
$$;


--
-- Name: list_changes(name, name, integer, integer); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.list_changes(publication name, slot_name name, max_changes integer, max_record_bytes integer) RETURNS TABLE(wal jsonb, is_rls_enabled boolean, subscription_ids uuid[], errors text[], slot_changes_count bigint)
    LANGUAGE sql
    SET log_min_messages TO 'fatal'
    AS $$
  WITH pub AS (
    SELECT
      concat_ws(
        ',',
        CASE WHEN bool_or(pubinsert) THEN 'insert' ELSE NULL END,
        CASE WHEN bool_or(pubupdate) THEN 'update' ELSE NULL END,
        CASE WHEN bool_or(pubdelete) THEN 'delete' ELSE NULL END
      ) AS w2j_actions,
      coalesce(
        string_agg(
          realtime.quote_wal2json(format('%I.%I', schemaname, tablename)::regclass),
          ','
        ) filter (WHERE ppt.tablename IS NOT NULL),
        ''
      ) AS w2j_add_tables
    FROM pg_publication pp
    LEFT JOIN pg_publication_tables ppt ON pp.pubname = ppt.pubname
    WHERE pp.pubname = publication
    GROUP BY pp.pubname
    LIMIT 1
  ),
  -- MATERIALIZED ensures pg_logical_slot_get_changes is called exactly once
  w2j AS MATERIALIZED (
    SELECT x.*, pub.w2j_add_tables
    FROM pub,
         pg_logical_slot_get_changes(
           slot_name, null, max_changes,
           'include-pk', 'true',
           'include-transaction', 'false',
           'include-timestamp', 'true',
           'include-type-oids', 'true',
           'format-version', '2',
           'actions', pub.w2j_actions,
           'add-tables', pub.w2j_add_tables
         ) x
  ),
  slot_count AS (
    SELECT count(*)::bigint AS cnt
    FROM w2j
    WHERE w2j.w2j_add_tables <> ''
  ),
  rls_filtered AS (
    SELECT xyz.wal, xyz.is_rls_enabled, xyz.subscription_ids, xyz.errors
    FROM w2j,
         realtime.apply_rls(
           wal := w2j.data::jsonb,
           max_record_bytes := max_record_bytes
         ) xyz(wal, is_rls_enabled, subscription_ids, errors)
    WHERE w2j.w2j_add_tables <> ''
      AND xyz.subscription_ids[1] IS NOT NULL
  )
  SELECT rf.wal, rf.is_rls_enabled, rf.subscription_ids, rf.errors, sc.cnt
  FROM rls_filtered rf, slot_count sc

  UNION ALL

  SELECT null, null, null, null, sc.cnt
  FROM slot_count sc
  WHERE NOT EXISTS (SELECT 1 FROM rls_filtered)
$$;


--
-- Name: quote_wal2json(regclass); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.quote_wal2json(entity regclass) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
  SELECT
    realtime.wal2json_escape_identifier(nsp.nspname::text)
    || '.'
    || realtime.wal2json_escape_identifier(pc.relname::text)
  FROM pg_class pc
  JOIN pg_namespace nsp ON pc.relnamespace = nsp.oid
  WHERE pc.oid = entity
$$;


--
-- Name: send(jsonb, text, text, boolean); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.send(payload jsonb, event text, topic text, private boolean DEFAULT true) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  generated_id uuid;
  final_payload jsonb;
BEGIN
  BEGIN
    generated_id := gen_random_uuid();

    -- Check if payload has an 'id' key, if not, add the generated UUID
    IF payload ? 'id' THEN
      final_payload := payload;
    ELSE
      final_payload := jsonb_set(payload, '{id}', to_jsonb(generated_id));
    END IF;

    -- Set the topic configuration
    EXECUTE format('SET LOCAL realtime.topic TO %L', topic);

    INSERT INTO realtime.messages (id, payload, event, topic, private, extension)
    VALUES (generated_id, final_payload, event, topic, private, 'broadcast');
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'WarnSendingBroadcastMessage: %', SQLERRM;
  END;
END;
$$;


--
-- Name: send_binary(bytea, text, text, boolean); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.send_binary(payload bytea, event text, topic text, private boolean DEFAULT true) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  generated_id uuid;
BEGIN
  BEGIN
    generated_id := gen_random_uuid();

    EXECUTE format('SET LOCAL realtime.topic TO %L', topic);

    INSERT INTO realtime.messages (id, binary_payload, event, topic, private, extension)
    VALUES (generated_id, payload, event, topic, private, 'broadcast');
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'WarnSendingBroadcastMessage: %', SQLERRM;
  END;
END;
$$;


--
-- Name: subscription_check_filters(); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.subscription_check_filters() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
    col_names text[] = coalesce(
            array_agg(a.attname order by a.attnum),
            '{}'::text[]
        )
        from
            pg_catalog.pg_attribute a
        where
            a.attrelid = new.entity
            and a.attnum > 0
            and not a.attisdropped
            and pg_catalog.has_column_privilege(
                (new.claims ->> 'role'),
                a.attrelid,
                a.attnum,
                'SELECT'
            );
    filter realtime.user_defined_filter;
    col_type regtype;
    in_val jsonb;
    selected_col text;
begin
    for filter in select * from unnest(new.filters) loop
        if not filter.column_name = any(col_names) then
            raise exception 'invalid column for filter %', filter.column_name;
        end if;

        col_type = (
            select atttypid::regtype
            from pg_catalog.pg_attribute
            where attrelid = new.entity
                  and attname = filter.column_name
        );
        if col_type is null then
            raise exception 'failed to lookup type for column %', filter.column_name;
        end if;

        if filter.op = 'in'::realtime.equality_op then
            in_val = realtime.cast(filter.value, (col_type::text || '[]')::regtype);
            if coalesce(jsonb_array_length(in_val), 0) > 100 then
                raise exception 'too many values for `in` filter. Maximum 100';
            end if;
        elsif filter.op = 'is'::realtime.equality_op then
            -- `is` requires a keyword RHS rather than a typed literal
            if filter.value not in ('null', 'true', 'false', 'unknown') then
                raise exception 'invalid value for is filter: must be null, true, false, or unknown';
            end if;
            -- IS NULL works for any type, but IS TRUE/FALSE/UNKNOWN require a boolean
            -- operand. Reject the non-null keywords on non-boolean columns here so they
            -- don't abort apply_rls at WAL time.
            if filter.value <> 'null' and col_type <> 'boolean'::regtype then
                raise exception 'is % filter requires a boolean column, got %', filter.value, col_type::text;
            end if;
        elsif filter.op in ('like'::realtime.equality_op, 'ilike'::realtime.equality_op) then
            -- like/ilike apply the text pattern operator (~~); reject column types that
            -- have no such operator instead of failing at WAL time
            if not exists (
                select 1 from pg_catalog.pg_operator
                where oprname = '~~' and oprleft = col_type
            ) then
                raise exception 'operator % requires a text-compatible column type, got %', filter.op::text, col_type::text;
            end if;
        elsif filter.op in ('match'::realtime.equality_op, 'imatch'::realtime.equality_op) then
            -- match/imatch apply the regex operators ~ / ~*; reject column types that have
            -- no such operator (e.g. integer) instead of failing at WAL time, mirroring the
            -- like/ilike guard above.
            if not exists (
                select 1 from pg_catalog.pg_operator
                where oprname = case when filter.op = 'imatch'::realtime.equality_op then '~*' else '~' end
                  and oprleft = col_type
                  and oprright = col_type
                  and oprresult = 'boolean'::regtype
            ) then
                raise exception 'operator % requires a text-compatible column type, got %', filter.op::text, col_type::text;
            end if;
            -- validate the regex eagerly so a bad pattern is rejected here, not inside
            -- apply_rls where it would abort the WAL stream for the entity
            begin
                perform '' ~ filter.value;
            exception when others then
                raise exception 'invalid regular expression for % filter: %', filter.op::text, sqlerrm;
            end;
        else
            -- eq/neq/lt/lte/gt/gte: value must be coercable to the type
            perform realtime.cast(filter.value, col_type);
        end if;
    end loop;

    if new.selected_columns is not null then
        for selected_col in select * from unnest(new.selected_columns) loop
            if not selected_col = any(col_names) then
                raise exception 'invalid column for select %', selected_col;
            end if;
        end loop;
    end if;

    -- Apply consistent order to filters so the unique constraint can't be tricked by a
    -- different filter order. negate is part of the sort key.
    new.filters = coalesce(
        array_agg(f order by f.column_name, f.op, f.value, f.negate),
        '{}'
    ) from unnest(new.filters) f;

    new.selected_columns = (
        select array_agg(c order by c)
        from unnest(new.selected_columns) c
    );

    return new;
end;
$$;


--
-- Name: to_regrole(text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.to_regrole(role_name text) RETURNS regrole
    LANGUAGE sql IMMUTABLE
    AS $$ select role_name::regrole $$;


--
-- Name: topic(); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.topic() RETURNS text
    LANGUAGE sql STABLE
    AS $$
select nullif(current_setting('realtime.topic', true), '')::text;
$$;


--
-- Name: wal2json_escape_identifier(text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.wal2json_escape_identifier(name text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
  -- Prefix `\`, `,`, `.`, and any whitespace with `\`
  SELECT regexp_replace(name, '([\\,.[:space:]])', '\\\1', 'g')
$$;


--
-- Name: allow_any_operation(text[]); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.allow_any_operation(expected_operations text[]) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  WITH current_operation AS (
    SELECT storage.operation() AS raw_operation
  ),
  normalized AS (
    SELECT CASE
      WHEN raw_operation LIKE 'storage.%' THEN substr(raw_operation, 9)
      ELSE raw_operation
    END AS current_operation
    FROM current_operation
  )
  SELECT EXISTS (
    SELECT 1
    FROM normalized n
    CROSS JOIN LATERAL unnest(expected_operations) AS expected_operation
    WHERE expected_operation IS NOT NULL
      AND expected_operation <> ''
      AND n.current_operation = CASE
        WHEN expected_operation LIKE 'storage.%' THEN substr(expected_operation, 9)
        ELSE expected_operation
      END
  );
$$;


--
-- Name: allow_only_operation(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.allow_only_operation(expected_operation text) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  WITH current_operation AS (
    SELECT storage.operation() AS raw_operation
  ),
  normalized AS (
    SELECT
      CASE
        WHEN raw_operation LIKE 'storage.%' THEN substr(raw_operation, 9)
        ELSE raw_operation
      END AS current_operation,
      CASE
        WHEN expected_operation LIKE 'storage.%' THEN substr(expected_operation, 9)
        ELSE expected_operation
      END AS requested_operation
    FROM current_operation
  )
  SELECT CASE
    WHEN requested_operation IS NULL OR requested_operation = '' THEN FALSE
    ELSE COALESCE(current_operation = requested_operation, FALSE)
  END
  FROM normalized;
$$;


--
-- Name: can_insert_object(text, text, uuid, jsonb); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.can_insert_object(bucketid text, name text, owner uuid, metadata jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO "storage"."objects" ("bucket_id", "name", "owner", "metadata") VALUES (bucketid, name, owner, metadata);
  -- hack to rollback the successful insert
  RAISE sqlstate 'PT200' using
  message = 'ROLLBACK',
  detail = 'rollback successful insert';
END
$$;


--
-- Name: enforce_bucket_name_length(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.enforce_bucket_name_length() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    if length(new.name) > 100 then
        raise exception 'bucket name "%" is too long (% characters). Max is 100.', new.name, length(new.name);
    end if;
    return new;
end;
$$;


--
-- Name: extension(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.extension(name text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    _parts text[];
    _filename text;
BEGIN
    -- Split on "/" to get path segments
    SELECT string_to_array(name, '/') INTO _parts;
    -- Get the last path segment (the actual filename)
    SELECT _parts[array_length(_parts, 1)] INTO _filename;
    -- Extract extension: reverse, split on '.', then reverse again
    RETURN reverse(split_part(reverse(_filename), '.', 1));
END
$$;


--
-- Name: filename(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.filename(name text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    _parts text[];
BEGIN
    SELECT string_to_array(name, '/') INTO _parts;
    RETURN _parts[array_length(_parts, 1)];
END
$$;


--
-- Name: foldername(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.foldername(name text) RETURNS text[]
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    _parts text[];
BEGIN
    -- Split on "/" to get path segments
    SELECT string_to_array(name, '/') INTO _parts;
    -- Return everything except the last segment
    RETURN _parts[1 : array_length(_parts,1) - 1];
END
$$;


--
-- Name: get_common_prefix(text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_common_prefix(p_key text, p_prefix text, p_delimiter text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
SELECT CASE
    WHEN position(p_delimiter IN substring(p_key FROM length(p_prefix) + 1)) > 0
    THEN left(p_key, length(p_prefix) + position(p_delimiter IN substring(p_key FROM length(p_prefix) + 1)))
    ELSE NULL
END;
$$;


--
-- Name: get_size_by_bucket(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_size_by_bucket() RETURNS TABLE(size bigint, bucket_id text)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    return query
        select sum((metadata->>'size')::bigint)::bigint as size, obj.bucket_id
        from "storage".objects as obj
        group by obj.bucket_id;
END
$$;


--
-- Name: list_multipart_uploads_with_delimiter(text, text, text, integer, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.list_multipart_uploads_with_delimiter(bucket_id text, prefix_param text, delimiter_param text, max_keys integer DEFAULT 100, next_key_token text DEFAULT ''::text, next_upload_token text DEFAULT ''::text) RETURNS TABLE(key text, id text, created_at timestamp with time zone)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT DISTINCT ON(key COLLATE "C") * from (
            SELECT
                CASE
                    WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                        substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1)))
                    ELSE
                        key
                END AS key, id, created_at
            FROM
                storage.s3_multipart_uploads
            WHERE
                bucket_id = $5 AND
                key ILIKE $1 || ''%'' AND
                CASE
                    WHEN $4 != '''' AND $6 = '''' THEN
                        CASE
                            WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                                substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1))) COLLATE "C" > $4
                            ELSE
                                key COLLATE "C" > $4
                            END
                    ELSE
                        true
                END AND
                CASE
                    WHEN $6 != '''' THEN
                        id COLLATE "C" > $6
                    ELSE
                        true
                    END
            ORDER BY
                key COLLATE "C" ASC, created_at ASC) as e order by key COLLATE "C" LIMIT $3'
        USING prefix_param, delimiter_param, max_keys, next_key_token, bucket_id, next_upload_token;
END;
$_$;


--
-- Name: list_objects_with_delimiter(text, text, text, integer, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.list_objects_with_delimiter(_bucket_id text, prefix_param text, delimiter_param text, max_keys integer DEFAULT 100, start_after text DEFAULT ''::text, next_token text DEFAULT ''::text, sort_order text DEFAULT 'asc'::text) RETURNS TABLE(name text, id uuid, metadata jsonb, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone)
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    v_peek_name TEXT;
    v_current RECORD;
    v_common_prefix TEXT;

    -- Configuration
    v_is_asc BOOLEAN;
    v_prefix TEXT;
    v_start TEXT;
    v_upper_bound TEXT;
    v_file_batch_size INT;

    -- Seek state
    v_next_seek TEXT;
    v_count INT := 0;

    -- Dynamic SQL for batch query only
    v_batch_query TEXT;

BEGIN
    -- ========================================================================
    -- INITIALIZATION
    -- ========================================================================
    v_is_asc := lower(coalesce(sort_order, 'asc')) = 'asc';
    v_prefix := coalesce(prefix_param, '');
    v_start := CASE WHEN coalesce(next_token, '') <> '' THEN next_token ELSE coalesce(start_after, '') END;
    v_file_batch_size := LEAST(GREATEST(max_keys * 2, 100), 1000);

    -- Calculate upper bound for prefix filtering (bytewise, using COLLATE "C")
    IF v_prefix = '' THEN
        v_upper_bound := NULL;
    ELSIF right(v_prefix, 1) = delimiter_param THEN
        v_upper_bound := left(v_prefix, -1) || chr(ascii(delimiter_param) + 1);
    ELSE
        v_upper_bound := left(v_prefix, -1) || chr(ascii(right(v_prefix, 1)) + 1);
    END IF;

    -- Build batch query (dynamic SQL - called infrequently, amortized over many rows)
    IF v_is_asc THEN
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" >= $2 ' ||
                'AND o.name COLLATE "C" < $3 ORDER BY o.name COLLATE "C" ASC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" >= $2 ' ||
                'ORDER BY o.name COLLATE "C" ASC LIMIT $4';
        END IF;
    ELSE
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" < $2 ' ||
                'AND o.name COLLATE "C" >= $3 ORDER BY o.name COLLATE "C" DESC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" < $2 ' ||
                'ORDER BY o.name COLLATE "C" DESC LIMIT $4';
        END IF;
    END IF;

    -- ========================================================================
    -- SEEK INITIALIZATION: Determine starting position
    -- ========================================================================
    IF v_start = '' THEN
        IF v_is_asc THEN
            v_next_seek := v_prefix;
        ELSE
            -- DESC without cursor: find the last item in range
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_prefix AND o.name COLLATE "C" < v_upper_bound
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix <> '' THEN
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            END IF;

            IF v_next_seek IS NOT NULL THEN
                v_next_seek := v_next_seek || delimiter_param;
            ELSE
                RETURN;
            END IF;
        END IF;
    ELSE
        -- Cursor provided: determine if it refers to a folder or leaf
        IF EXISTS (
            SELECT 1 FROM storage.objects o
            WHERE o.bucket_id = _bucket_id
              AND o.name COLLATE "C" LIKE v_start || delimiter_param || '%'
            LIMIT 1
        ) THEN
            -- Cursor refers to a folder
            IF v_is_asc THEN
                v_next_seek := v_start || chr(ascii(delimiter_param) + 1);
            ELSE
                v_next_seek := v_start || delimiter_param;
            END IF;
        ELSE
            -- Cursor refers to a leaf object
            IF v_is_asc THEN
                v_next_seek := v_start || delimiter_param;
            ELSE
                v_next_seek := v_start;
            END IF;
        END IF;
    END IF;

    -- ========================================================================
    -- MAIN LOOP: Hybrid peek-then-batch algorithm
    -- Uses STATIC SQL for peek (hot path) and DYNAMIC SQL for batch
    -- ========================================================================
    LOOP
        EXIT WHEN v_count >= max_keys;

        -- STEP 1: PEEK using STATIC SQL (plan cached, very fast)
        IF v_is_asc THEN
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_next_seek AND o.name COLLATE "C" < v_upper_bound
                ORDER BY o.name COLLATE "C" ASC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_next_seek
                ORDER BY o.name COLLATE "C" ASC LIMIT 1;
            END IF;
        ELSE
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix <> '' THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            END IF;
        END IF;

        EXIT WHEN v_peek_name IS NULL;

        -- STEP 2: Check if this is a FOLDER or FILE
        v_common_prefix := storage.get_common_prefix(v_peek_name, v_prefix, delimiter_param);

        IF v_common_prefix IS NOT NULL THEN
            -- FOLDER: Emit and skip to next folder (no heap access needed)
            name := rtrim(v_common_prefix, delimiter_param);
            id := NULL;
            updated_at := NULL;
            created_at := NULL;
            last_accessed_at := NULL;
            metadata := NULL;
            RETURN NEXT;
            v_count := v_count + 1;

            -- Advance seek past the folder range
            IF v_is_asc THEN
                v_next_seek := left(v_common_prefix, -1) || chr(ascii(delimiter_param) + 1);
            ELSE
                v_next_seek := v_common_prefix;
            END IF;
        ELSE
            -- FILE: Batch fetch using DYNAMIC SQL (overhead amortized over many rows)
            -- For ASC: upper_bound is the exclusive upper limit (< condition)
            -- For DESC: prefix is the inclusive lower limit (>= condition)
            FOR v_current IN EXECUTE v_batch_query USING _bucket_id, v_next_seek,
                CASE WHEN v_is_asc THEN COALESCE(v_upper_bound, v_prefix) ELSE v_prefix END, v_file_batch_size
            LOOP
                v_common_prefix := storage.get_common_prefix(v_current.name, v_prefix, delimiter_param);

                IF v_common_prefix IS NOT NULL THEN
                    -- Hit a folder: exit batch, let peek handle it
                    v_next_seek := v_current.name;
                    EXIT;
                END IF;

                -- Emit file
                name := v_current.name;
                id := v_current.id;
                updated_at := v_current.updated_at;
                created_at := v_current.created_at;
                last_accessed_at := v_current.last_accessed_at;
                metadata := v_current.metadata;
                RETURN NEXT;
                v_count := v_count + 1;

                -- Advance seek past this file
                IF v_is_asc THEN
                    v_next_seek := v_current.name || delimiter_param;
                ELSE
                    v_next_seek := v_current.name;
                END IF;

                EXIT WHEN v_count >= max_keys;
            END LOOP;
        END IF;
    END LOOP;
END;
$_$;


--
-- Name: operation(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.operation() RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN current_setting('storage.operation', true);
END;
$$;


--
-- Name: protect_delete(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.protect_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check if storage.allow_delete_query is set to 'true'
    IF COALESCE(current_setting('storage.allow_delete_query', true), 'false') != 'true' THEN
        RAISE EXCEPTION 'Direct deletion from storage tables is not allowed. Use the Storage API instead.'
            USING HINT = 'This prevents accidental data loss from orphaned objects.',
                  ERRCODE = '42501';
    END IF;
    RETURN NULL;
END;
$$;


--
-- Name: search(text, text, integer, integer, integer, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search(prefix text, bucketname text, limits integer DEFAULT 100, levels integer DEFAULT 1, offsets integer DEFAULT 0, search text DEFAULT ''::text, sortcolumn text DEFAULT 'name'::text, sortorder text DEFAULT 'asc'::text) RETURNS TABLE(name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    v_peek_name TEXT;
    v_current RECORD;
    v_common_prefix TEXT;
    v_delimiter CONSTANT TEXT := '/';

    -- Configuration
    v_limit INT;
    v_prefix TEXT;
    v_prefix_lower TEXT;
    v_prefix_len INT;
    v_prefix_start INT;
    v_combined_levels INT;
    v_is_asc BOOLEAN;
    v_order_by TEXT;
    v_sort_order TEXT;
    v_upper_bound TEXT;
    v_file_batch_size INT;

    -- Dynamic SQL for batch query only
    v_batch_query TEXT;

    -- Seek state
    v_next_seek TEXT;
    v_count INT := 0;
    v_skipped INT := 0;
BEGIN
    -- ========================================================================
    -- INITIALIZATION
    -- ========================================================================
    v_limit := LEAST(coalesce(limits, 100), 1500);
    v_prefix := coalesce(prefix, '') || coalesce(search, '');
    v_prefix_lower := lower(v_prefix);
    v_prefix_len := length(coalesce(prefix, ''));
    v_prefix_start := coalesce(array_length(string_to_array(coalesce(prefix, ''), v_delimiter), 1), 1);
    v_combined_levels := coalesce(array_length(string_to_array(v_prefix, v_delimiter), 1), 1);
    v_is_asc := lower(coalesce(sortorder, 'asc')) = 'asc';
    v_file_batch_size := LEAST(GREATEST(v_limit * 2, 100), 1000);

    -- Validate sort column
    CASE lower(coalesce(sortcolumn, 'name'))
        WHEN 'name' THEN v_order_by := 'name';
        WHEN 'updated_at' THEN v_order_by := 'updated_at';
        WHEN 'created_at' THEN v_order_by := 'created_at';
        WHEN 'last_accessed_at' THEN v_order_by := 'last_accessed_at';
        ELSE v_order_by := 'name';
    END CASE;

    v_sort_order := CASE WHEN v_is_asc THEN 'asc' ELSE 'desc' END;

    -- ========================================================================
    -- NON-NAME SORTING: Use path_tokens approach
    -- ========================================================================
    IF v_order_by != 'name' THEN
        RETURN QUERY EXECUTE format(
            $sql$
            WITH folders AS (
                SELECT array_to_string(path_tokens[$1:$2], '/') AS folder
                FROM storage.objects
                WHERE objects.name ILIKE $3 || '%%'
                  AND bucket_id = $4
                  AND array_length(objects.path_tokens, 1) <> $2
                GROUP BY folder
                ORDER BY folder %s
            )
            (SELECT folder AS "name",
                   NULL::uuid AS id,
                   NULL::timestamptz AS updated_at,
                   NULL::timestamptz AS created_at,
                   NULL::timestamptz AS last_accessed_at,
                   NULL::jsonb AS metadata FROM folders)
            UNION ALL
            (SELECT array_to_string(path_tokens[$1:$2], '/') AS "name",
                   id, updated_at, created_at, last_accessed_at, metadata
             FROM storage.objects
             WHERE objects.name ILIKE $3 || '%%'
               AND bucket_id = $4
               AND array_length(objects.path_tokens, 1) = $2
             ORDER BY %I %s)
            LIMIT $5 OFFSET $6
            $sql$, v_sort_order, v_order_by, v_sort_order
        ) USING v_prefix_start, v_combined_levels, v_prefix, bucketname, v_limit, offsets;
        RETURN;
    END IF;

    -- ========================================================================
    -- NAME SORTING: Hybrid skip-scan with batch optimization
    -- ========================================================================

    -- Calculate upper bound for prefix filtering
    IF v_prefix_lower = '' THEN
        v_upper_bound := NULL;
    ELSIF right(v_prefix_lower, 1) = v_delimiter THEN
        v_upper_bound := left(v_prefix_lower, -1) || chr(ascii(v_delimiter) + 1);
    ELSE
        v_upper_bound := left(v_prefix_lower, -1) || chr(ascii(right(v_prefix_lower, 1)) + 1);
    END IF;

    -- Build batch query (dynamic SQL - called infrequently, amortized over many rows)
    IF v_is_asc THEN
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" >= $2 ' ||
                'AND lower(o.name) COLLATE "C" < $3 ORDER BY lower(o.name) COLLATE "C" ASC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" >= $2 ' ||
                'ORDER BY lower(o.name) COLLATE "C" ASC LIMIT $4';
        END IF;
    ELSE
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" < $2 ' ||
                'AND lower(o.name) COLLATE "C" >= $3 ORDER BY lower(o.name) COLLATE "C" DESC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" < $2 ' ||
                'ORDER BY lower(o.name) COLLATE "C" DESC LIMIT $4';
        END IF;
    END IF;

    -- Initialize seek position
    IF v_is_asc THEN
        v_next_seek := v_prefix_lower;
    ELSE
        -- DESC: find the last item in range first (static SQL)
        IF v_upper_bound IS NOT NULL THEN
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_prefix_lower AND lower(o.name) COLLATE "C" < v_upper_bound
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        ELSIF v_prefix_lower <> '' THEN
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_prefix_lower
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        ELSE
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        END IF;

        IF v_peek_name IS NOT NULL THEN
            v_next_seek := lower(v_peek_name) || v_delimiter;
        ELSE
            RETURN;
        END IF;
    END IF;

    -- ========================================================================
    -- MAIN LOOP: Hybrid peek-then-batch algorithm
    -- Uses STATIC SQL for peek (hot path) and DYNAMIC SQL for batch
    -- ========================================================================
    LOOP
        EXIT WHEN v_count >= v_limit;

        -- STEP 1: PEEK using STATIC SQL (plan cached, very fast)
        IF v_is_asc THEN
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_next_seek AND lower(o.name) COLLATE "C" < v_upper_bound
                ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_next_seek
                ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
            END IF;
        ELSE
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek AND lower(o.name) COLLATE "C" >= v_prefix_lower
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix_lower <> '' THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek AND lower(o.name) COLLATE "C" >= v_prefix_lower
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            END IF;
        END IF;

        EXIT WHEN v_peek_name IS NULL;

        -- STEP 2: Check if this is a FOLDER or FILE
        v_common_prefix := storage.get_common_prefix(lower(v_peek_name), v_prefix_lower, v_delimiter);

        IF v_common_prefix IS NOT NULL THEN
            -- FOLDER: Handle offset, emit if needed, skip to next folder
            IF v_skipped < offsets THEN
                v_skipped := v_skipped + 1;
            ELSE
                name := substring(rtrim(storage.get_common_prefix(v_peek_name, v_prefix, v_delimiter), v_delimiter) from v_prefix_len + 1);
                id := NULL;
                updated_at := NULL;
                created_at := NULL;
                last_accessed_at := NULL;
                metadata := NULL;
                RETURN NEXT;
                v_count := v_count + 1;
            END IF;

            -- Advance seek past the folder range
            IF v_is_asc THEN
                v_next_seek := lower(left(v_common_prefix, -1)) || chr(ascii(v_delimiter) + 1);
            ELSE
                v_next_seek := lower(v_common_prefix);
            END IF;
        ELSE
            -- FILE: Batch fetch using DYNAMIC SQL (overhead amortized over many rows)
            -- For ASC: upper_bound is the exclusive upper limit (< condition)
            -- For DESC: prefix_lower is the inclusive lower limit (>= condition)
            FOR v_current IN EXECUTE v_batch_query
                USING bucketname, v_next_seek,
                    CASE WHEN v_is_asc THEN COALESCE(v_upper_bound, v_prefix_lower) ELSE v_prefix_lower END, v_file_batch_size
            LOOP
                v_common_prefix := storage.get_common_prefix(lower(v_current.name), v_prefix_lower, v_delimiter);

                IF v_common_prefix IS NOT NULL THEN
                    -- Hit a folder: exit batch, let peek handle it
                    v_next_seek := lower(v_current.name);
                    EXIT;
                END IF;

                -- Handle offset skipping
                IF v_skipped < offsets THEN
                    v_skipped := v_skipped + 1;
                ELSE
                    -- Emit file
                    name := substring(v_current.name from v_prefix_len + 1);
                    id := v_current.id;
                    updated_at := v_current.updated_at;
                    created_at := v_current.created_at;
                    last_accessed_at := v_current.last_accessed_at;
                    metadata := v_current.metadata;
                    RETURN NEXT;
                    v_count := v_count + 1;
                END IF;

                -- Advance seek past this file
                IF v_is_asc THEN
                    v_next_seek := lower(v_current.name) || v_delimiter;
                ELSE
                    v_next_seek := lower(v_current.name);
                END IF;

                EXIT WHEN v_count >= v_limit;
            END LOOP;
        END IF;
    END LOOP;
END;
$_$;


--
-- Name: search_by_timestamp(text, text, integer, integer, text, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search_by_timestamp(p_prefix text, p_bucket_id text, p_limit integer, p_level integer, p_start_after text, p_sort_order text, p_sort_column text, p_sort_column_after text) RETURNS TABLE(key text, name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    v_cursor_op text;
    v_query text;
    v_prefix text;
    v_sort_order text;
    v_sort_column text;
BEGIN
    v_prefix := coalesce(p_prefix, '');

    -- Defense-in-depth: this function is independently reachable and must
    -- not trust p_sort_order/p_sort_column to already be validated by a
    -- caller. Normalize to the same strict allow-list storage.search_v2
    -- uses before interpolating anything into dynamic SQL below.
    v_sort_order := lower(coalesce(p_sort_order, 'asc'));
    IF v_sort_order NOT IN ('asc', 'desc') THEN
        v_sort_order := 'asc';
    END IF;

    v_sort_column := lower(coalesce(p_sort_column, 'updated_at'));
    IF v_sort_column NOT IN ('updated_at', 'created_at') THEN
        v_sort_column := 'updated_at';
    END IF;

    IF v_sort_order = 'asc' THEN
        v_cursor_op := '>';
    ELSE
        v_cursor_op := '<';
    END IF;

    v_query := format($sql$
        WITH raw_objects AS (
            SELECT
                o.name AS obj_name,
                o.id AS obj_id,
                o.updated_at AS obj_updated_at,
                o.created_at AS obj_created_at,
                o.last_accessed_at AS obj_last_accessed_at,
                o.metadata AS obj_metadata,
                storage.get_common_prefix(o.name, $1, '/') AS common_prefix
            FROM storage.objects o
            WHERE o.bucket_id = $2
              AND o.name COLLATE "C" LIKE $1 || '%%'
        ),
        -- Aggregate common prefixes (folders)
        -- Both created_at and updated_at use MIN(obj_created_at) to match the old prefixes table behavior
        aggregated_prefixes AS (
            SELECT
                rtrim(common_prefix, '/') AS name,
                NULL::uuid AS id,
                MIN(obj_created_at) AS updated_at,
                MIN(obj_created_at) AS created_at,
                NULL::timestamptz AS last_accessed_at,
                NULL::jsonb AS metadata,
                TRUE AS is_prefix
            FROM raw_objects
            WHERE common_prefix IS NOT NULL
            GROUP BY common_prefix
        ),
        leaf_objects AS (
            SELECT
                obj_name AS name,
                obj_id AS id,
                obj_updated_at AS updated_at,
                obj_created_at AS created_at,
                obj_last_accessed_at AS last_accessed_at,
                obj_metadata AS metadata,
                FALSE AS is_prefix
            FROM raw_objects
            WHERE common_prefix IS NULL
        ),
        combined AS (
            SELECT * FROM aggregated_prefixes
            UNION ALL
            SELECT * FROM leaf_objects
        ),
        filtered AS (
            SELECT *
            FROM combined
            WHERE (
                $5 = ''
                OR ROW(
                    date_trunc('milliseconds', %I),
                    name COLLATE "C"
                ) %s ROW(
                    COALESCE(NULLIF($6, '')::timestamptz, 'epoch'::timestamptz),
                    $5
                )
            )
        )
        SELECT
            split_part(name, '/', $3) AS key,
            name,
            id,
            updated_at,
            created_at,
            last_accessed_at,
            metadata
        FROM filtered
        ORDER BY
            COALESCE(date_trunc('milliseconds', %I), 'epoch'::timestamptz) %s,
            name COLLATE "C" %s
        LIMIT $4
    $sql$,
        v_sort_column,
        v_cursor_op,
        v_sort_column,
        v_sort_order,
        v_sort_order
    );

    RETURN QUERY EXECUTE v_query
    USING v_prefix, p_bucket_id, p_level, p_limit, p_start_after, p_sort_column_after;
END;
$_$;


--
-- Name: search_v2(text, text, integer, integer, text, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search_v2(prefix text, bucket_name text, limits integer DEFAULT 100, levels integer DEFAULT 1, start_after text DEFAULT ''::text, sort_order text DEFAULT 'asc'::text, sort_column text DEFAULT 'name'::text, sort_column_after text DEFAULT ''::text) RETURNS TABLE(key text, name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_sort_col text;
    v_sort_ord text;
    v_limit int;
BEGIN
    -- Cap limit to maximum of 1500 records
    v_limit := LEAST(coalesce(limits, 100), 1500);

    -- Validate and normalize sort_order
    v_sort_ord := lower(coalesce(sort_order, 'asc'));
    IF v_sort_ord NOT IN ('asc', 'desc') THEN
        v_sort_ord := 'asc';
    END IF;

    -- Validate and normalize sort_column
    v_sort_col := lower(coalesce(sort_column, 'name'));
    IF v_sort_col NOT IN ('name', 'updated_at', 'created_at') THEN
        v_sort_col := 'name';
    END IF;

    -- Route to appropriate implementation
    IF v_sort_col = 'name' THEN
        -- Use list_objects_with_delimiter for name sorting (most efficient: O(k * log n))
        RETURN QUERY
        SELECT
            split_part(l.name, '/', levels) AS key,
            l.name AS name,
            l.id,
            l.updated_at,
            l.created_at,
            l.last_accessed_at,
            l.metadata
        FROM storage.list_objects_with_delimiter(
            bucket_name,
            coalesce(prefix, ''),
            '/',
            v_limit,
            start_after,
            '',
            v_sort_ord
        ) l;
    ELSE
        -- Use aggregation approach for timestamp sorting
        -- Not efficient for large datasets but supports correct pagination
        RETURN QUERY SELECT * FROM storage.search_by_timestamp(
            prefix, bucket_name, v_limit, levels, start_after,
            v_sort_ord, v_sort_col, sort_column_after
        );
    END IF;
END;
$$;


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW; 
END;
$$;


--
-- Name: http_request(); Type: FUNCTION; Schema: supabase_functions; Owner: -
--

CREATE FUNCTION supabase_functions.http_request() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'supabase_functions'
    AS $$
  DECLARE
    request_id bigint;
    payload jsonb;
    url text := TG_ARGV[0]::text;
    method text := TG_ARGV[1]::text;
    headers jsonb DEFAULT '{}'::jsonb;
    params jsonb DEFAULT '{}'::jsonb;
    timeout_ms integer DEFAULT 1000;
  BEGIN
    IF url IS NULL OR url = 'null' THEN
      RAISE EXCEPTION 'url argument is missing';
    END IF;

    IF method IS NULL OR method = 'null' THEN
      RAISE EXCEPTION 'method argument is missing';
    END IF;

    IF TG_ARGV[2] IS NULL OR TG_ARGV[2] = 'null' THEN
      headers = '{"Content-Type": "application/json"}'::jsonb;
    ELSE
      headers = TG_ARGV[2]::jsonb;
    END IF;

    IF TG_ARGV[3] IS NULL OR TG_ARGV[3] = 'null' THEN
      params = '{}'::jsonb;
    ELSE
      params = TG_ARGV[3]::jsonb;
    END IF;

    IF TG_ARGV[4] IS NULL OR TG_ARGV[4] = 'null' THEN
      timeout_ms = 1000;
    ELSE
      timeout_ms = TG_ARGV[4]::integer;
    END IF;

    CASE
      WHEN method = 'GET' THEN
        SELECT http_get INTO request_id FROM net.http_get(
          url,
          params,
          headers,
          timeout_ms
        );
      WHEN method = 'POST' THEN
        payload = jsonb_build_object(
          'old_record', OLD,
          'record', NEW,
          'type', TG_OP,
          'table', TG_TABLE_NAME,
          'schema', TG_TABLE_SCHEMA
        );

        SELECT http_post INTO request_id FROM net.http_post(
          url,
          payload,
          params,
          headers,
          timeout_ms
        );
      ELSE
        RAISE EXCEPTION 'method argument % is invalid', method;
    END CASE;

    INSERT INTO supabase_functions.hooks
      (hook_table_id, hook_name, request_id)
    VALUES
      (TG_RELID, TG_NAME, request_id);

    RETURN NEW;
  END
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: extensions; Type: TABLE; Schema: _realtime; Owner: -
--

CREATE TABLE _realtime.extensions (
    id uuid NOT NULL,
    type text,
    settings jsonb,
    tenant_external_id text,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: feature_flags; Type: TABLE; Schema: _realtime; Owner: -
--

CREATE TABLE _realtime.feature_flags (
    id uuid NOT NULL,
    name character varying(255) NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    rollout_percentage integer DEFAULT 100 NOT NULL,
    bucket_key character varying(255),
    CONSTRAINT rollout_percentage_must_be_between_0_and_100 CHECK (((rollout_percentage >= 0) AND (rollout_percentage <= 100)))
);


--
-- Name: schema_migrations; Type: TABLE; Schema: _realtime; Owner: -
--

CREATE TABLE _realtime.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: tenants; Type: TABLE; Schema: _realtime; Owner: -
--

CREATE TABLE _realtime.tenants (
    id uuid NOT NULL,
    name text,
    external_id text,
    jwt_secret text,
    max_concurrent_users integer DEFAULT 200 NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    max_events_per_second integer DEFAULT 100 NOT NULL,
    postgres_cdc_default text DEFAULT 'postgres_cdc_rls'::text,
    max_bytes_per_second integer DEFAULT 100000 NOT NULL,
    max_channels_per_client integer DEFAULT 100 NOT NULL,
    max_joins_per_second integer DEFAULT 500 NOT NULL,
    suspend boolean DEFAULT false,
    jwt_jwks jsonb,
    notify_private_alpha boolean DEFAULT false,
    private_only boolean DEFAULT false NOT NULL,
    migrations_ran integer DEFAULT 0,
    broadcast_adapter character varying(255) DEFAULT 'gen_rpc'::character varying,
    max_presence_events_per_second integer DEFAULT 1000,
    max_payload_size_in_kb integer DEFAULT 3000,
    max_client_presence_events_per_window integer,
    client_presence_window_ms integer,
    presence_enabled boolean DEFAULT false NOT NULL,
    feature_flags jsonb DEFAULT '{}'::jsonb NOT NULL,
    gcm_migrated_at timestamp(0) without time zone,
    CONSTRAINT jwt_secret_or_jwt_jwks_required CHECK (((jwt_secret IS NOT NULL) OR (jwt_jwks IS NOT NULL)))
);


--
-- Name: audit_log_entries; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.audit_log_entries (
    instance_id uuid,
    id uuid NOT NULL,
    payload json,
    created_at timestamp with time zone,
    ip_address character varying(64) DEFAULT ''::character varying NOT NULL
);


--
-- Name: TABLE audit_log_entries; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.audit_log_entries IS 'Auth: Audit trail for user actions.';


--
-- Name: custom_oauth_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.custom_oauth_providers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    provider_type text NOT NULL,
    identifier text NOT NULL,
    name text NOT NULL,
    client_id text NOT NULL,
    client_secret text NOT NULL,
    acceptable_client_ids text[] DEFAULT '{}'::text[] NOT NULL,
    scopes text[] DEFAULT '{}'::text[] NOT NULL,
    pkce_enabled boolean DEFAULT true NOT NULL,
    attribute_mapping jsonb DEFAULT '{}'::jsonb NOT NULL,
    authorization_params jsonb DEFAULT '{}'::jsonb NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    email_optional boolean DEFAULT false NOT NULL,
    issuer text,
    discovery_url text,
    skip_nonce_check boolean DEFAULT false NOT NULL,
    cached_discovery jsonb,
    discovery_cached_at timestamp with time zone,
    authorization_url text,
    token_url text,
    userinfo_url text,
    jwks_uri text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    custom_claims_allowlist text[] DEFAULT '{}'::text[] NOT NULL,
    CONSTRAINT custom_oauth_providers_authorization_url_https CHECK (((authorization_url IS NULL) OR (authorization_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_authorization_url_length CHECK (((authorization_url IS NULL) OR (char_length(authorization_url) <= 2048))),
    CONSTRAINT custom_oauth_providers_client_id_length CHECK (((char_length(client_id) >= 1) AND (char_length(client_id) <= 512))),
    CONSTRAINT custom_oauth_providers_discovery_url_length CHECK (((discovery_url IS NULL) OR (char_length(discovery_url) <= 2048))),
    CONSTRAINT custom_oauth_providers_identifier_format CHECK ((identifier ~ '^[a-z0-9][a-z0-9:-]{0,48}[a-z0-9]$'::text)),
    CONSTRAINT custom_oauth_providers_issuer_length CHECK (((issuer IS NULL) OR ((char_length(issuer) >= 1) AND (char_length(issuer) <= 2048)))),
    CONSTRAINT custom_oauth_providers_jwks_uri_https CHECK (((jwks_uri IS NULL) OR (jwks_uri ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_jwks_uri_length CHECK (((jwks_uri IS NULL) OR (char_length(jwks_uri) <= 2048))),
    CONSTRAINT custom_oauth_providers_name_length CHECK (((char_length(name) >= 1) AND (char_length(name) <= 100))),
    CONSTRAINT custom_oauth_providers_oauth2_requires_endpoints CHECK (((provider_type <> 'oauth2'::text) OR ((authorization_url IS NOT NULL) AND (token_url IS NOT NULL) AND (userinfo_url IS NOT NULL)))),
    CONSTRAINT custom_oauth_providers_oidc_discovery_url_https CHECK (((provider_type <> 'oidc'::text) OR (discovery_url IS NULL) OR (discovery_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_oidc_issuer_https CHECK (((provider_type <> 'oidc'::text) OR (issuer IS NULL) OR (issuer ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_oidc_requires_issuer CHECK (((provider_type <> 'oidc'::text) OR (issuer IS NOT NULL))),
    CONSTRAINT custom_oauth_providers_provider_type_check CHECK ((provider_type = ANY (ARRAY['oauth2'::text, 'oidc'::text]))),
    CONSTRAINT custom_oauth_providers_token_url_https CHECK (((token_url IS NULL) OR (token_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_token_url_length CHECK (((token_url IS NULL) OR (char_length(token_url) <= 2048))),
    CONSTRAINT custom_oauth_providers_userinfo_url_https CHECK (((userinfo_url IS NULL) OR (userinfo_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_userinfo_url_length CHECK (((userinfo_url IS NULL) OR (char_length(userinfo_url) <= 2048)))
);


--
-- Name: flow_state; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.flow_state (
    id uuid NOT NULL,
    user_id uuid,
    auth_code text,
    code_challenge_method auth.code_challenge_method,
    code_challenge text,
    provider_type text NOT NULL,
    provider_access_token text,
    provider_refresh_token text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    authentication_method text NOT NULL,
    auth_code_issued_at timestamp with time zone,
    invite_token text,
    referrer text,
    oauth_client_state_id uuid,
    linking_target_id uuid,
    email_optional boolean DEFAULT false NOT NULL
);


--
-- Name: TABLE flow_state; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.flow_state IS 'Stores metadata for all OAuth/SSO login flows';


--
-- Name: identities; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.identities (
    provider_id text NOT NULL,
    user_id uuid NOT NULL,
    identity_data jsonb NOT NULL,
    provider text NOT NULL,
    last_sign_in_at timestamp with time zone,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    email text GENERATED ALWAYS AS (lower((identity_data ->> 'email'::text))) STORED,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);


--
-- Name: TABLE identities; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.identities IS 'Auth: Stores identities associated to a user.';


--
-- Name: COLUMN identities.email; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.identities.email IS 'Auth: Email is a generated column that references the optional email property in the identity_data';


--
-- Name: instances; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.instances (
    id uuid NOT NULL,
    uuid uuid,
    raw_base_config text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);


--
-- Name: TABLE instances; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.instances IS 'Auth: Manages users across multiple sites.';


--
-- Name: mfa_amr_claims; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_amr_claims (
    session_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    authentication_method text NOT NULL,
    id uuid NOT NULL
);


--
-- Name: TABLE mfa_amr_claims; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_amr_claims IS 'auth: stores authenticator method reference claims for multi factor authentication';


--
-- Name: mfa_challenges; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_challenges (
    id uuid NOT NULL,
    factor_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    verified_at timestamp with time zone,
    ip_address inet NOT NULL,
    otp_code text,
    web_authn_session_data jsonb
);


--
-- Name: TABLE mfa_challenges; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_challenges IS 'auth: stores metadata about challenge requests made';


--
-- Name: mfa_factors; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_factors (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    friendly_name text,
    factor_type auth.factor_type NOT NULL,
    status auth.factor_status NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    secret text,
    phone text,
    last_challenged_at timestamp with time zone,
    web_authn_credential jsonb,
    web_authn_aaguid uuid,
    last_webauthn_challenge_data jsonb
);


--
-- Name: TABLE mfa_factors; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_factors IS 'auth: stores metadata about factors';


--
-- Name: COLUMN mfa_factors.last_webauthn_challenge_data; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.mfa_factors.last_webauthn_challenge_data IS 'Stores the latest WebAuthn challenge data including attestation/assertion for customer verification';


--
-- Name: oauth_authorizations; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_authorizations (
    id uuid NOT NULL,
    authorization_id text NOT NULL,
    client_id uuid NOT NULL,
    user_id uuid,
    redirect_uri text NOT NULL,
    scope text NOT NULL,
    state text,
    resource text,
    code_challenge text,
    code_challenge_method auth.code_challenge_method,
    response_type auth.oauth_response_type DEFAULT 'code'::auth.oauth_response_type NOT NULL,
    status auth.oauth_authorization_status DEFAULT 'pending'::auth.oauth_authorization_status NOT NULL,
    authorization_code text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '00:03:00'::interval) NOT NULL,
    approved_at timestamp with time zone,
    nonce text,
    CONSTRAINT oauth_authorizations_authorization_code_length CHECK ((char_length(authorization_code) <= 255)),
    CONSTRAINT oauth_authorizations_code_challenge_length CHECK ((char_length(code_challenge) <= 128)),
    CONSTRAINT oauth_authorizations_expires_at_future CHECK ((expires_at > created_at)),
    CONSTRAINT oauth_authorizations_nonce_length CHECK ((char_length(nonce) <= 255)),
    CONSTRAINT oauth_authorizations_redirect_uri_length CHECK ((char_length(redirect_uri) <= 2048)),
    CONSTRAINT oauth_authorizations_resource_length CHECK ((char_length(resource) <= 2048)),
    CONSTRAINT oauth_authorizations_scope_length CHECK ((char_length(scope) <= 4096)),
    CONSTRAINT oauth_authorizations_state_length CHECK ((char_length(state) <= 4096))
);


--
-- Name: oauth_client_states; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_client_states (
    id uuid NOT NULL,
    provider_type text NOT NULL,
    code_verifier text,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: TABLE oauth_client_states; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.oauth_client_states IS 'Stores OAuth states for third-party provider authentication flows where Supabase acts as the OAuth client.';


--
-- Name: oauth_clients; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_clients (
    id uuid NOT NULL,
    client_secret_hash text,
    registration_type auth.oauth_registration_type NOT NULL,
    redirect_uris text NOT NULL,
    grant_types text NOT NULL,
    client_name text,
    client_uri text,
    logo_uri text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    client_type auth.oauth_client_type DEFAULT 'confidential'::auth.oauth_client_type NOT NULL,
    token_endpoint_auth_method text NOT NULL,
    CONSTRAINT oauth_clients_client_name_length CHECK ((char_length(client_name) <= 1024)),
    CONSTRAINT oauth_clients_client_uri_length CHECK ((char_length(client_uri) <= 2048)),
    CONSTRAINT oauth_clients_logo_uri_length CHECK ((char_length(logo_uri) <= 2048)),
    CONSTRAINT oauth_clients_token_endpoint_auth_method_check CHECK ((token_endpoint_auth_method = ANY (ARRAY['client_secret_basic'::text, 'client_secret_post'::text, 'none'::text])))
);


--
-- Name: oauth_consents; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_consents (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    client_id uuid NOT NULL,
    scopes text NOT NULL,
    granted_at timestamp with time zone DEFAULT now() NOT NULL,
    revoked_at timestamp with time zone,
    CONSTRAINT oauth_consents_revoked_after_granted CHECK (((revoked_at IS NULL) OR (revoked_at >= granted_at))),
    CONSTRAINT oauth_consents_scopes_length CHECK ((char_length(scopes) <= 2048)),
    CONSTRAINT oauth_consents_scopes_not_empty CHECK ((char_length(TRIM(BOTH FROM scopes)) > 0))
);


--
-- Name: one_time_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.one_time_tokens (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    token_type auth.one_time_token_type NOT NULL,
    token_hash text NOT NULL,
    relates_to text NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT one_time_tokens_token_hash_check CHECK ((char_length(token_hash) > 0))
);


--
-- Name: refresh_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.refresh_tokens (
    instance_id uuid,
    id bigint NOT NULL,
    token character varying(255),
    user_id character varying(255),
    revoked boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    parent character varying(255),
    session_id uuid
);


--
-- Name: TABLE refresh_tokens; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.refresh_tokens IS 'Auth: Store of tokens used to refresh JWT tokens once they expire.';


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.refresh_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.refresh_tokens_id_seq OWNED BY auth.refresh_tokens.id;


--
-- Name: saml_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.saml_providers (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    entity_id text NOT NULL,
    metadata_xml text NOT NULL,
    metadata_url text,
    attribute_mapping jsonb,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    name_id_format text,
    CONSTRAINT "entity_id not empty" CHECK ((char_length(entity_id) > 0)),
    CONSTRAINT "metadata_url not empty" CHECK (((metadata_url = NULL::text) OR (char_length(metadata_url) > 0))),
    CONSTRAINT "metadata_xml not empty" CHECK ((char_length(metadata_xml) > 0))
);


--
-- Name: TABLE saml_providers; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.saml_providers IS 'Auth: Manages SAML Identity Provider connections.';


--
-- Name: saml_relay_states; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.saml_relay_states (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    request_id text NOT NULL,
    for_email text,
    redirect_to text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    flow_state_id uuid,
    CONSTRAINT "request_id not empty" CHECK ((char_length(request_id) > 0))
);


--
-- Name: TABLE saml_relay_states; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.saml_relay_states IS 'Auth: Contains SAML Relay State information for each Service Provider initiated login.';


--
-- Name: schema_migrations; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: TABLE schema_migrations; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.schema_migrations IS 'Auth: Manages updates to the auth system.';


--
-- Name: sessions; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sessions (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    factor_id uuid,
    aal auth.aal_level,
    not_after timestamp with time zone,
    refreshed_at timestamp without time zone,
    user_agent text,
    ip inet,
    tag text,
    oauth_client_id uuid,
    refresh_token_hmac_key text,
    refresh_token_counter bigint,
    scopes text,
    CONSTRAINT sessions_scopes_length CHECK ((char_length(scopes) <= 4096))
);


--
-- Name: TABLE sessions; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sessions IS 'Auth: Stores session data associated to a user.';


--
-- Name: COLUMN sessions.not_after; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.not_after IS 'Auth: Not after is a nullable column that contains a timestamp after which the session should be regarded as expired.';


--
-- Name: COLUMN sessions.refresh_token_hmac_key; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.refresh_token_hmac_key IS 'Holds a HMAC-SHA256 key used to sign refresh tokens for this session.';


--
-- Name: COLUMN sessions.refresh_token_counter; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.refresh_token_counter IS 'Holds the ID (counter) of the last issued refresh token.';


--
-- Name: sso_domains; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sso_domains (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    domain text NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    CONSTRAINT "domain not empty" CHECK ((char_length(domain) > 0))
);


--
-- Name: TABLE sso_domains; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sso_domains IS 'Auth: Manages SSO email address domain mapping to an SSO Identity Provider.';


--
-- Name: sso_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sso_providers (
    id uuid NOT NULL,
    resource_id text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    disabled boolean,
    CONSTRAINT "resource_id not empty" CHECK (((resource_id = NULL::text) OR (char_length(resource_id) > 0)))
);


--
-- Name: TABLE sso_providers; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sso_providers IS 'Auth: Manages SSO identity provider information; see saml_providers for SAML.';


--
-- Name: COLUMN sso_providers.resource_id; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sso_providers.resource_id IS 'Auth: Uniquely identifies a SSO provider according to a user-chosen resource ID (case insensitive), useful in infrastructure as code.';


--
-- Name: users; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.users (
    instance_id uuid,
    id uuid NOT NULL,
    aud character varying(255),
    role character varying(255),
    email character varying(255),
    encrypted_password character varying(255),
    email_confirmed_at timestamp with time zone,
    invited_at timestamp with time zone,
    confirmation_token character varying(255),
    confirmation_sent_at timestamp with time zone,
    recovery_token character varying(255),
    recovery_sent_at timestamp with time zone,
    email_change_token_new character varying(255),
    email_change character varying(255),
    email_change_sent_at timestamp with time zone,
    last_sign_in_at timestamp with time zone,
    raw_app_meta_data jsonb,
    raw_user_meta_data jsonb,
    is_super_admin boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    phone text DEFAULT NULL::character varying,
    phone_confirmed_at timestamp with time zone,
    phone_change text DEFAULT ''::character varying,
    phone_change_token character varying(255) DEFAULT ''::character varying,
    phone_change_sent_at timestamp with time zone,
    confirmed_at timestamp with time zone GENERATED ALWAYS AS (LEAST(email_confirmed_at, phone_confirmed_at)) STORED,
    email_change_token_current character varying(255) DEFAULT ''::character varying,
    email_change_confirm_status smallint DEFAULT 0,
    banned_until timestamp with time zone,
    reauthentication_token character varying(255) DEFAULT ''::character varying,
    reauthentication_sent_at timestamp with time zone,
    is_sso_user boolean DEFAULT false NOT NULL,
    deleted_at timestamp with time zone,
    is_anonymous boolean DEFAULT false NOT NULL,
    CONSTRAINT users_email_change_confirm_status_check CHECK (((email_change_confirm_status >= 0) AND (email_change_confirm_status <= 2)))
);


--
-- Name: TABLE users; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.users IS 'Auth: Stores user login data within a secure schema.';


--
-- Name: COLUMN users.is_sso_user; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.users.is_sso_user IS 'Auth: Set this column to true when the account comes from SSO. These accounts can have duplicate emails.';


--
-- Name: webauthn_challenges; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.webauthn_challenges (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    challenge_type text NOT NULL,
    session_data jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    CONSTRAINT webauthn_challenges_challenge_type_check CHECK ((challenge_type = ANY (ARRAY['signup'::text, 'registration'::text, 'authentication'::text])))
);


--
-- Name: webauthn_credentials; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.webauthn_credentials (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    credential_id bytea NOT NULL,
    public_key bytea NOT NULL,
    attestation_type text DEFAULT ''::text NOT NULL,
    aaguid uuid,
    sign_count bigint DEFAULT 0 NOT NULL,
    transports jsonb DEFAULT '[]'::jsonb NOT NULL,
    backup_eligible boolean DEFAULT false NOT NULL,
    backed_up boolean DEFAULT false NOT NULL,
    friendly_name text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    last_used_at timestamp with time zone
);


--
-- Name: batch_materials; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.batch_materials (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    batch_id uuid NOT NULL,
    raw_material_id uuid NOT NULL,
    material_lot_id uuid NOT NULL,
    recipe_quantity numeric,
    recipe_unit text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT batch_materials_recipe_quantity_check CHECK ((recipe_quantity > (0)::numeric))
);


--
-- Name: TABLE batch_materials; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.batch_materials IS 'Snapshot of the exact current material lots at batch start. Append-mostly: historical traceability must never be reconstructed from material_lots.is_current.';


--
-- Name: batch_outputs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.batch_outputs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    batch_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity numeric NOT NULL,
    unit text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT batch_outputs_quantity_check CHECK ((quantity > (0)::numeric))
);


--
-- Name: TABLE batch_outputs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.batch_outputs IS 'Products produced by a batch (one row per product, supports multi-output recipes).';


--
-- Name: batch_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.batch_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    batch_id uuid NOT NULL,
    production_request_id uuid NOT NULL,
    allocated_quantity numeric,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT batch_requests_allocated_quantity_check CHECK ((allocated_quantity > (0)::numeric))
);


--
-- Name: TABLE batch_requests; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.batch_requests IS 'Links one or more production requests to a batch. Restrictive FKs: history is never cascade-deleted.';


--
-- Name: brands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.brands (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT brands_name_check CHECK ((btrim(name) <> ''::text))
);


--
-- Name: TABLE brands; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.brands IS 'Raw material brands (Lealtad, Dos Anclas, Calsa, ...).';


--
-- Name: external_order_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.external_order_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    external_order_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity numeric NOT NULL,
    unit text NOT NULL,
    shift_code text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT external_order_items_quantity_check CHECK ((quantity > (0)::numeric)),
    CONSTRAINT external_order_items_shift_code_check CHECK ((shift_code = ANY (ARRAY['morning'::text, 'afternoon'::text, 'night'::text])))
);


--
-- Name: TABLE external_order_items; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.external_order_items IS 'Order items. shift_code is the actual planned production shift for this item (defaulted from the product, overridable by supervisor/admin).';


--
-- Name: external_orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.external_orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    order_number text NOT NULL,
    customer_name text NOT NULL,
    requested_date date NOT NULL,
    delivery_time time without time zone,
    status text NOT NULL,
    notes text,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT external_orders_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'in_production'::text, 'completed'::text, 'cancelled'::text])))
);


--
-- Name: TABLE external_orders; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.external_orders IS 'External customer orders.';


--
-- Name: material_lots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.material_lots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    raw_material_id uuid NOT NULL,
    brand_id uuid NOT NULL,
    supplier_lot text NOT NULL,
    expiry_date date,
    received_at timestamp with time zone,
    opened_at timestamp with time zone,
    closed_at timestamp with time zone,
    is_current boolean DEFAULT false NOT NULL,
    status text NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT material_lots_status_check CHECK ((status = ANY (ARRAY['available'::text, 'in_use'::text, 'closed'::text, 'discarded'::text])))
);


--
-- Name: TABLE material_lots; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.material_lots IS 'Lots of a raw material used in production. At most one lot is current per raw material.';


--
-- Name: parent_batch_inputs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.parent_batch_inputs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    child_batch_id uuid NOT NULL,
    parent_batch_output_id uuid NOT NULL,
    quantity numeric,
    unit text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT parent_batch_inputs_quantity_check CHECK ((quantity > (0)::numeric))
);


--
-- Name: TABLE parent_batch_inputs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.parent_batch_inputs IS 'Links a child batch to the batch output it consumed as input (e.g. Pan Leche Redondo produced from Masa Pan Galleta).';


--
-- Name: production_batches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.production_batches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    production_day_id uuid NOT NULL,
    recipe_version_id uuid NOT NULL,
    shift_code text NOT NULL,
    batch_code text NOT NULL,
    status text NOT NULL,
    started_at timestamp with time zone NOT NULL,
    started_by uuid NOT NULL,
    finished_at timestamp with time zone,
    finished_by uuid,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT production_batches_shift_code_check CHECK ((shift_code = ANY (ARRAY['morning'::text, 'afternoon'::text, 'night'::text]))),
    CONSTRAINT production_batches_status_check CHECK ((status = ANY (ARRAY['in_progress'::text, 'completed'::text, 'cancelled'::text])))
);


--
-- Name: TABLE production_batches; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.production_batches IS 'Production batches. shift_code is copied from the production request (historical). Batch code format: PAN-DDMMYY-X-NNN (X = M/T/N), generated in later phases.';


--
-- Name: production_days; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.production_days (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    production_date date NOT NULL,
    status text NOT NULL,
    opened_at timestamp with time zone,
    opened_by uuid,
    closed_at timestamp with time zone,
    closed_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT production_days_status_check CHECK ((status = ANY (ARRAY['open'::text, 'closed'::text])))
);


--
-- Name: TABLE production_days; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.production_days IS 'One row per business date (America/Argentina/Cordoba). Created by ensure_production_day in later phases.';


--
-- Name: production_plan_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.production_plan_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    weekday smallint NOT NULL,
    shift_code text NOT NULL,
    product_id uuid NOT NULL,
    planned_quantity numeric NOT NULL,
    unit text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT production_plan_items_planned_quantity_check CHECK ((planned_quantity > (0)::numeric)),
    CONSTRAINT production_plan_items_shift_code_check CHECK ((shift_code = ANY (ARRAY['morning'::text, 'afternoon'::text, 'night'::text]))),
    CONSTRAINT production_plan_items_weekday_check CHECK (((weekday >= 1) AND (weekday <= 7)))
);


--
-- Name: TABLE production_plan_items; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.production_plan_items IS 'Base production plan by weekday and shift. Weekday: 1 = Monday ... 7 = Sunday.';


--
-- Name: production_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.production_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    production_day_id uuid NOT NULL,
    source_type text NOT NULL,
    shift_code text NOT NULL,
    product_id uuid NOT NULL,
    requested_quantity numeric NOT NULL,
    unit text NOT NULL,
    external_order_item_id uuid,
    reason_code text,
    reason_note text,
    status text NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT production_requests_additional_integrity CHECK (((source_type <> 'additional'::text) OR ((external_order_item_id IS NULL) AND (reason_code IS NOT NULL) AND ((reason_code <> 'other'::text) OR ((reason_note IS NOT NULL) AND (btrim(reason_note) <> ''::text)))))),
    CONSTRAINT production_requests_base_integrity CHECK (((source_type <> 'base'::text) OR ((external_order_item_id IS NULL) AND (reason_code IS NULL) AND (reason_note IS NULL)))),
    CONSTRAINT production_requests_external_order_integrity CHECK (((source_type <> 'external_order'::text) OR ((external_order_item_id IS NOT NULL) AND (reason_code IS NULL) AND (reason_note IS NULL)))),
    CONSTRAINT production_requests_reason_code_check CHECK ((reason_code = ANY (ARRAY['replenishment'::text, 'increased_demand'::text, 'remake'::text, 'other'::text]))),
    CONSTRAINT production_requests_requested_quantity_check CHECK ((requested_quantity > (0)::numeric)),
    CONSTRAINT production_requests_shift_code_check CHECK ((shift_code = ANY (ARRAY['morning'::text, 'afternoon'::text, 'night'::text]))),
    CONSTRAINT production_requests_source_type_check CHECK ((source_type = ANY (ARRAY['base'::text, 'external_order'::text, 'additional'::text]))),
    CONSTRAINT production_requests_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'in_progress'::text, 'completed'::text, 'cancelled'::text])))
);


--
-- Name: TABLE production_requests; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.production_requests IS 'Unified production requests. shift_code is historical: it is never re-inferred from products.default_shift_code.';


--
-- Name: products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    default_unit text NOT NULL,
    default_shift_code text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT products_default_shift_code_check CHECK ((default_shift_code = ANY (ARRAY['morning'::text, 'afternoon'::text, 'night'::text])))
);


--
-- Name: TABLE products; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.products IS 'Finished products. default_shift_code is the normal/default shift only: historical shift is copied into production requests and batches, it is never re-inferred from here.';


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    full_name text NOT NULL,
    role text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT profiles_role_check CHECK ((role = ANY (ARRAY['operator'::text, 'supervisor'::text, 'admin'::text])))
);


--
-- Name: TABLE profiles; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.profiles IS 'Application profile per authenticated user, including the role used by the app.';


--
-- Name: raw_material_brands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.raw_material_brands (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    raw_material_id uuid NOT NULL,
    brand_id uuid NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE raw_material_brands; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.raw_material_brands IS 'Which brands are valid for each raw material. Restrictive FKs: master data is not deleted while linked.';


--
-- Name: raw_materials; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.raw_materials (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    default_unit text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT raw_materials_name_check CHECK ((btrim(name) <> ''::text))
);


--
-- Name: TABLE raw_materials; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.raw_materials IS 'Raw materials (flour, salt, yeast, ...). Case-insensitive unique name.';


--
-- Name: recipe_ingredients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recipe_ingredients (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    recipe_version_id uuid NOT NULL,
    raw_material_id uuid NOT NULL,
    quantity numeric NOT NULL,
    unit text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    optional boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT recipe_ingredients_quantity_check CHECK ((quantity > (0)::numeric))
);


--
-- Name: TABLE recipe_ingredients; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.recipe_ingredients IS 'Raw materials required by one recipe version (one row per material).';


--
-- Name: recipe_product_inputs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recipe_product_inputs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    recipe_version_id uuid NOT NULL,
    source_product_id uuid NOT NULL,
    quantity numeric,
    unit text,
    required boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT recipe_product_inputs_quantity_check CHECK ((quantity > (0)::numeric))
);


--
-- Name: TABLE recipe_product_inputs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.recipe_product_inputs IS 'Declares that a recipe can require a previously produced product as input (e.g. Masa Pan Galleta -> Pan Galleta). Historical batches are linked later via parent_batch_inputs.';


--
-- Name: recipe_products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recipe_products (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    recipe_id uuid NOT NULL,
    product_id uuid NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE recipe_products; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.recipe_products IS 'Links a recipe/preparation to one or multiple products it produces.';


--
-- Name: recipe_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recipe_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    recipe_id uuid NOT NULL,
    version_number integer NOT NULL,
    status text NOT NULL,
    effective_from date,
    effective_to date,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT recipe_versions_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'active'::text, 'retired'::text]))),
    CONSTRAINT recipe_versions_version_number_check CHECK ((version_number > 0))
);


--
-- Name: TABLE recipe_versions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.recipe_versions IS 'Versions of a recipe. Historical batches keep pointing at the version used at batch start.';


--
-- Name: recipes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recipes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE recipes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.recipes IS 'A recipe is a production formula/preparation, not necessarily one finished product.';


--
-- Name: messages; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.messages (
    topic text NOT NULL,
    extension text NOT NULL,
    payload jsonb,
    event text,
    private boolean DEFAULT false,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    binary_payload bytea
)
PARTITION BY RANGE (inserted_at);


--
-- Name: messages_2026_09_10; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.messages_2026_09_10 (
    topic text NOT NULL,
    extension text NOT NULL,
    payload jsonb,
    event text,
    private boolean DEFAULT false,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    binary_payload bytea,
    CONSTRAINT messages_payload_exclusive CHECK (((payload IS NULL) OR (binary_payload IS NULL)))
);


--
-- Name: messages_2026_09_11; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.messages_2026_09_11 (
    topic text NOT NULL,
    extension text NOT NULL,
    payload jsonb,
    event text,
    private boolean DEFAULT false,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    binary_payload bytea,
    CONSTRAINT messages_payload_exclusive CHECK (((payload IS NULL) OR (binary_payload IS NULL)))
);


--
-- Name: messages_2026_09_12; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.messages_2026_09_12 (
    topic text NOT NULL,
    extension text NOT NULL,
    payload jsonb,
    event text,
    private boolean DEFAULT false,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    binary_payload bytea,
    CONSTRAINT messages_payload_exclusive CHECK (((payload IS NULL) OR (binary_payload IS NULL)))
);


--
-- Name: messages_2026_09_13; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.messages_2026_09_13 (
    topic text NOT NULL,
    extension text NOT NULL,
    payload jsonb,
    event text,
    private boolean DEFAULT false,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    binary_payload bytea,
    CONSTRAINT messages_payload_exclusive CHECK (((payload IS NULL) OR (binary_payload IS NULL)))
);


--
-- Name: messages_2026_09_14; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.messages_2026_09_14 (
    topic text NOT NULL,
    extension text NOT NULL,
    payload jsonb,
    event text,
    private boolean DEFAULT false,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    binary_payload bytea,
    CONSTRAINT messages_payload_exclusive CHECK (((payload IS NULL) OR (binary_payload IS NULL)))
);


--
-- Name: messages_2026_09_15; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.messages_2026_09_15 (
    topic text NOT NULL,
    extension text NOT NULL,
    payload jsonb,
    event text,
    private boolean DEFAULT false,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    binary_payload bytea,
    CONSTRAINT messages_payload_exclusive CHECK (((payload IS NULL) OR (binary_payload IS NULL)))
);


--
-- Name: messages_2026_09_16; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.messages_2026_09_16 (
    topic text NOT NULL,
    extension text NOT NULL,
    payload jsonb,
    event text,
    private boolean DEFAULT false,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    binary_payload bytea,
    CONSTRAINT messages_payload_exclusive CHECK (((payload IS NULL) OR (binary_payload IS NULL)))
);


--
-- Name: schema_migrations; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone DEFAULT now()
);


--
-- Name: subscription; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.subscription (
    id bigint NOT NULL,
    subscription_id uuid NOT NULL,
    entity regclass NOT NULL,
    filters realtime.user_defined_filter[] DEFAULT '{}'::realtime.user_defined_filter[] NOT NULL,
    claims jsonb NOT NULL,
    claims_role regrole GENERATED ALWAYS AS (realtime.to_regrole((claims ->> 'role'::text))) STORED NOT NULL,
    created_at timestamp without time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    action_filter text DEFAULT '*'::text,
    selected_columns text[],
    CONSTRAINT subscription_action_filter_check CHECK ((action_filter = ANY (ARRAY['*'::text, 'INSERT'::text, 'UPDATE'::text, 'DELETE'::text])))
);


--
-- Name: subscription_id_seq; Type: SEQUENCE; Schema: realtime; Owner: -
--

ALTER TABLE realtime.subscription ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME realtime.subscription_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: buckets; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets (
    id text NOT NULL,
    name text NOT NULL,
    owner uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    public boolean DEFAULT false,
    avif_autodetection boolean DEFAULT false,
    file_size_limit bigint,
    allowed_mime_types text[],
    owner_id text,
    type storage.buckettype DEFAULT 'STANDARD'::storage.buckettype NOT NULL,
    versioning_status text DEFAULT 'DISABLED'::text NOT NULL,
    CONSTRAINT buckets_versioning_dark_check CHECK ((versioning_status = 'DISABLED'::text)),
    CONSTRAINT buckets_versioning_standard_only_check CHECK (((type = 'STANDARD'::storage.buckettype) OR (versioning_status = 'DISABLED'::text))),
    CONSTRAINT buckets_versioning_status_check CHECK ((versioning_status = ANY (ARRAY['DISABLED'::text, 'ENABLED'::text, 'SUSPENDED'::text])))
);


--
-- Name: COLUMN buckets.owner; Type: COMMENT; Schema: storage; Owner: -
--

COMMENT ON COLUMN storage.buckets.owner IS 'Field is deprecated, use owner_id instead';


--
-- Name: buckets_analytics; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets_analytics (
    name text NOT NULL,
    type storage.buckettype DEFAULT 'ANALYTICS'::storage.buckettype NOT NULL,
    format text DEFAULT 'ICEBERG'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: buckets_vectors; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets_vectors (
    id text NOT NULL,
    type storage.buckettype DEFAULT 'VECTOR'::storage.buckettype NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: iceberg_namespaces; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.iceberg_namespaces (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bucket_name text NOT NULL,
    name text NOT NULL COLLATE pg_catalog."C",
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    catalog_id uuid NOT NULL
);


--
-- Name: iceberg_tables; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.iceberg_tables (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    namespace_id uuid NOT NULL,
    bucket_name text NOT NULL,
    name text NOT NULL COLLATE pg_catalog."C",
    location text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    remote_table_id text,
    shard_key text,
    shard_id text,
    catalog_id uuid NOT NULL
);


--
-- Name: migrations; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.migrations (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    hash character varying(40) NOT NULL,
    executed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: objects; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.objects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bucket_id text,
    name text,
    owner uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    last_accessed_at timestamp with time zone DEFAULT now(),
    metadata jsonb,
    path_tokens text[] GENERATED ALWAYS AS (string_to_array(name, '/'::text)) STORED,
    version text,
    owner_id text,
    user_metadata jsonb,
    archived_at timestamp with time zone,
    is_delete_marker boolean DEFAULT false NOT NULL,
    is_versioned boolean DEFAULT false NOT NULL
);


--
-- Name: COLUMN objects.owner; Type: COMMENT; Schema: storage; Owner: -
--

COMMENT ON COLUMN storage.objects.owner IS 'Field is deprecated, use owner_id instead';


--
-- Name: s3_multipart_uploads; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.s3_multipart_uploads (
    id text NOT NULL,
    in_progress_size bigint DEFAULT 0 NOT NULL,
    upload_signature text NOT NULL,
    bucket_id text NOT NULL,
    key text NOT NULL COLLATE pg_catalog."C",
    version text NOT NULL,
    owner_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    user_metadata jsonb,
    metadata jsonb
);


--
-- Name: s3_multipart_uploads_parts; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.s3_multipart_uploads_parts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    upload_id text NOT NULL,
    size bigint DEFAULT 0 NOT NULL,
    part_number integer NOT NULL,
    bucket_id text NOT NULL,
    key text NOT NULL COLLATE pg_catalog."C",
    etag text NOT NULL,
    owner_id text,
    version text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: vector_indexes; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.vector_indexes (
    id text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL COLLATE pg_catalog."C",
    bucket_id text NOT NULL,
    data_type text NOT NULL,
    dimension integer NOT NULL,
    distance_metric text NOT NULL,
    metadata_configuration jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: hooks; Type: TABLE; Schema: supabase_functions; Owner: -
--

CREATE TABLE supabase_functions.hooks (
    id bigint NOT NULL,
    hook_table_id integer NOT NULL,
    hook_name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    request_id bigint
);


--
-- Name: TABLE hooks; Type: COMMENT; Schema: supabase_functions; Owner: -
--

COMMENT ON TABLE supabase_functions.hooks IS 'Supabase Functions Hooks: Audit trail for triggered hooks.';


--
-- Name: hooks_id_seq; Type: SEQUENCE; Schema: supabase_functions; Owner: -
--

CREATE SEQUENCE supabase_functions.hooks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: hooks_id_seq; Type: SEQUENCE OWNED BY; Schema: supabase_functions; Owner: -
--

ALTER SEQUENCE supabase_functions.hooks_id_seq OWNED BY supabase_functions.hooks.id;


--
-- Name: migrations; Type: TABLE; Schema: supabase_functions; Owner: -
--

CREATE TABLE supabase_functions.migrations (
    version text NOT NULL,
    inserted_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: supabase_migrations; Owner: -
--

CREATE TABLE supabase_migrations.schema_migrations (
    version text NOT NULL,
    statements text[],
    name text
);


--
-- Name: messages_2026_09_10; Type: TABLE ATTACH; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages ATTACH PARTITION realtime.messages_2026_09_10 FOR VALUES FROM ('2026-09-10 00:00:00') TO ('2026-09-11 00:00:00');


--
-- Name: messages_2026_09_11; Type: TABLE ATTACH; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages ATTACH PARTITION realtime.messages_2026_09_11 FOR VALUES FROM ('2026-09-11 00:00:00') TO ('2026-09-12 00:00:00');


--
-- Name: messages_2026_09_12; Type: TABLE ATTACH; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages ATTACH PARTITION realtime.messages_2026_09_12 FOR VALUES FROM ('2026-09-12 00:00:00') TO ('2026-09-13 00:00:00');


--
-- Name: messages_2026_09_13; Type: TABLE ATTACH; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages ATTACH PARTITION realtime.messages_2026_09_13 FOR VALUES FROM ('2026-09-13 00:00:00') TO ('2026-09-14 00:00:00');


--
-- Name: messages_2026_09_14; Type: TABLE ATTACH; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages ATTACH PARTITION realtime.messages_2026_09_14 FOR VALUES FROM ('2026-09-14 00:00:00') TO ('2026-09-15 00:00:00');


--
-- Name: messages_2026_09_15; Type: TABLE ATTACH; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages ATTACH PARTITION realtime.messages_2026_09_15 FOR VALUES FROM ('2026-09-15 00:00:00') TO ('2026-09-16 00:00:00');


--
-- Name: messages_2026_09_16; Type: TABLE ATTACH; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages ATTACH PARTITION realtime.messages_2026_09_16 FOR VALUES FROM ('2026-09-16 00:00:00') TO ('2026-09-17 00:00:00');


--
-- Name: refresh_tokens id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens ALTER COLUMN id SET DEFAULT nextval('auth.refresh_tokens_id_seq'::regclass);


--
-- Name: hooks id; Type: DEFAULT; Schema: supabase_functions; Owner: -
--

ALTER TABLE ONLY supabase_functions.hooks ALTER COLUMN id SET DEFAULT nextval('supabase_functions.hooks_id_seq'::regclass);


--
-- Data for Name: extensions; Type: TABLE DATA; Schema: _realtime; Owner: -
--

COPY _realtime.extensions (id, type, settings, tenant_external_id, inserted_at, updated_at) FROM stdin;
0800b895-0385-4a42-bcc2-02df937984eb	postgres_cdc_rls	{"region": "us-east-1", "db_host": "bjbKOcKSktrf6NfBcDPDbXu+hS/tfQKZNtI7aZ3MGyQ=", "db_name": "sWBpZNdjggEPTQVlI52Zfw==", "db_port": "+enMDFi1J/3IrrquHHwUmA==", "db_user": "uxbEq/zz8DXVD53TOI1zmw==", "slot_name": "supabase_realtime_replication_slot", "db_password": "sWBpZNdjggEPTQVlI52Zfw==", "publication": "supabase_realtime", "ssl_enforced": false, "db_pass_realtime": "sWBpZNdjggEPTQVlI52Zfw==", "db_user_realtime": "uxbEq/zz8DXVD53TOI1zmw==", "poll_interval_ms": 100, "poll_max_changes": 100, "poll_max_record_bytes": 1048576}	realtime-dev	2026-09-13 15:06:26	2026-09-13 15:06:26
\.


--
-- Data for Name: feature_flags; Type: TABLE DATA; Schema: _realtime; Owner: -
--

COPY _realtime.feature_flags (id, name, enabled, inserted_at, updated_at, rollout_percentage, bucket_key) FROM stdin;
189981d6-703a-498f-9486-3418f2ecb1be	gcm_encryption_backfill	t	2026-09-11 01:20:52	2026-09-11 01:21:08	100	\N
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: _realtime; Owner: -
--

COPY _realtime.schema_migrations (version, inserted_at) FROM stdin;
20210706140551	2026-09-11 01:20:50
20220329161857	2026-09-11 01:20:50
20220410212326	2026-09-11 01:20:50
20220506102948	2026-09-11 01:20:50
20220527210857	2026-09-11 01:20:50
20220815211129	2026-09-11 01:20:50
20220815215024	2026-09-11 01:20:50
20220818141501	2026-09-11 01:20:50
20221018173709	2026-09-11 01:20:50
20221102172703	2026-09-11 01:20:50
20221223010058	2026-09-11 01:20:50
20230110180046	2026-09-11 01:20:50
20230810220907	2026-09-11 01:20:50
20230810220924	2026-09-11 01:20:50
20231024094642	2026-09-11 01:20:50
20240306114423	2026-09-11 01:20:50
20240418082835	2026-09-11 01:20:50
20240625211759	2026-09-11 01:20:50
20240704172020	2026-09-11 01:20:50
20240902173232	2026-09-11 01:20:50
20241106103258	2026-09-11 01:20:51
20250424203323	2026-09-11 01:20:51
20250613072131	2026-09-11 01:20:51
20250711044927	2026-09-11 01:20:51
20250811121559	2026-09-11 01:20:51
20250926223044	2026-09-11 01:20:51
20251204170944	2026-09-11 01:20:51
20251218000543	2026-09-11 01:20:51
20260209232800	2026-09-11 01:20:51
20260304000000	2026-09-11 01:20:51
20260422000000	2026-09-11 01:20:51
20260709151810	2026-09-11 01:20:51
20260805000000	2026-09-11 01:20:51
\.


--
-- Data for Name: tenants; Type: TABLE DATA; Schema: _realtime; Owner: -
--

COPY _realtime.tenants (id, name, external_id, jwt_secret, max_concurrent_users, inserted_at, updated_at, max_events_per_second, postgres_cdc_default, max_bytes_per_second, max_channels_per_client, max_joins_per_second, suspend, jwt_jwks, notify_private_alpha, private_only, migrations_ran, broadcast_adapter, max_presence_events_per_second, max_payload_size_in_kb, max_client_presence_events_per_window, client_presence_window_ms, presence_enabled, feature_flags, gcm_migrated_at) FROM stdin;
64a60a8d-ad3d-4f3c-8ee9-98ddafbf9646	realtime-dev	realtime-dev	iNjicxc4+llvc9wovDvqymwfnj9teWMlyOIbJ8Fh6j2WNU8CIJ2ZgjR6MUIKqSmeDmvpsKLsZ9jgXJmQPpwL8w==	200	2026-09-13 15:06:26	2026-09-13 15:06:26	100	postgres_cdc_rls	100000	100	100	f	{"keys": [{"x": "M5Sjqn5zwC9Kl1zVfUUGvv9boQjCGd45G8sdopBExB4", "y": "P6IXMvA2WYXSHSOMTBH2jsw_9rrzGy89FjPf6oOsIxQ", "alg": "ES256", "crv": "P-256", "ext": true, "kid": "b81269f1-21d8-4f2e-b719-c2240a840d90", "kty": "EC", "use": "sig", "key_ops": ["verify"]}, {"k": "c3VwZXItc2VjcmV0LWp3dC10b2tlbi13aXRoLWF0LWxlYXN0LTMyLWNoYXJhY3RlcnMtbG9uZw", "kty": "oct"}]}	f	f	79	gen_rpc	1000	3000	\N	\N	f	{}	\N
\.


--
-- Data for Name: audit_log_entries; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.audit_log_entries (instance_id, id, payload, created_at, ip_address) FROM stdin;
00000000-0000-0000-0000-000000000000	85bee0a8-e2ff-4a19-8bd3-fa6b6e586047	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"s1-test@panaderia.local","user_id":"2ff5d6f9-4651-47d4-8085-60ad953d3eab","user_phone":""}}	2026-09-11 02:43:24.489059+00	
00000000-0000-0000-0000-000000000000	4cbe495a-e7ff-460c-af44-9e4ebcca7e7e	{"action":"login","actor_id":"2ff5d6f9-4651-47d4-8085-60ad953d3eab","actor_username":"s1-test@panaderia.local","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 02:43:34.01449+00	
00000000-0000-0000-0000-000000000000	08efbd6c-585b-43f7-9a3e-8ddb2336c093	{"action":"login","actor_id":"2ff5d6f9-4651-47d4-8085-60ad953d3eab","actor_username":"s1-test@panaderia.local","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 02:44:23.543588+00	
00000000-0000-0000-0000-000000000000	01b237fe-a522-4e30-91d5-ce6dfb6dee40	{"action":"login","actor_id":"2ff5d6f9-4651-47d4-8085-60ad953d3eab","actor_username":"s1-test@panaderia.local","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 02:48:19.557226+00	
00000000-0000-0000-0000-000000000000	3056f58c-ad2c-4279-9b70-f9b2ea6d0c62	{"action":"login","actor_id":"2ff5d6f9-4651-47d4-8085-60ad953d3eab","actor_username":"s1-test@panaderia.local","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 02:48:46.085312+00	
00000000-0000-0000-0000-000000000000	f58e5c18-3a3c-4066-a662-1a94246f13be	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"s1-test@panaderia.local","user_id":"2ff5d6f9-4651-47d4-8085-60ad953d3eab","user_phone":""}}	2026-09-11 02:49:10.207774+00	
00000000-0000-0000-0000-000000000000	736828f0-1158-475e-a42e-63abc9694a6c	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"t1-test@panaderia.local","user_id":"6968bf56-3f62-4c75-8453-80a7cbe49650","user_phone":""}}	2026-09-11 03:05:41.49575+00	
00000000-0000-0000-0000-000000000000	a36ef3b8-cc50-4273-be20-f2e0403e6d34	{"action":"login","actor_id":"6968bf56-3f62-4c75-8453-80a7cbe49650","actor_username":"t1-test@panaderia.local","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 03:05:57.210229+00	
00000000-0000-0000-0000-000000000000	01c3a3b9-becb-4156-a2ad-dada6bce6836	{"action":"login","actor_id":"6968bf56-3f62-4c75-8453-80a7cbe49650","actor_username":"t1-test@panaderia.local","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 03:06:11.587427+00	
00000000-0000-0000-0000-000000000000	e24575e0-1571-4000-aed0-6b91aaacf3b0	{"action":"login","actor_id":"6968bf56-3f62-4c75-8453-80a7cbe49650","actor_username":"t1-test@panaderia.local","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 03:06:25.302261+00	
00000000-0000-0000-0000-000000000000	9eb694b2-8399-4034-b292-96d6d2990d90	{"action":"login","actor_id":"6968bf56-3f62-4c75-8453-80a7cbe49650","actor_username":"t1-test@panaderia.local","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 03:06:46.824364+00	
00000000-0000-0000-0000-000000000000	58054868-d57b-435a-b835-9075e6cad7ee	{"action":"login","actor_id":"6968bf56-3f62-4c75-8453-80a7cbe49650","actor_username":"t1-test@panaderia.local","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 03:06:59.506963+00	
00000000-0000-0000-0000-000000000000	5cbdab3d-1a7b-4765-a848-141091862347	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"t1-test@panaderia.local","user_id":"6968bf56-3f62-4c75-8453-80a7cbe49650","user_phone":""}}	2026-09-11 03:07:28.111492+00	
00000000-0000-0000-0000-000000000000	e6764d7b-dcba-4f7a-8ea0-2e8e3c23f4ee	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"u1-active@panaderia.local","user_id":"a6649b67-76b5-431d-8744-3fc7e73e334e","user_phone":""}}	2026-09-11 03:14:11.811254+00	
00000000-0000-0000-0000-000000000000	bc814e77-0984-41ed-b7cf-6aac41fbf869	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"u1-inactive@panaderia.local","user_id":"c232d548-1c82-4989-bdb1-8579ca7d7f47","user_phone":""}}	2026-09-11 03:14:11.925673+00	
00000000-0000-0000-0000-000000000000	a792781a-1660-4d9f-a7c4-d0dd53e960f6	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"u1-noprofile@panaderia.local","user_id":"5b63019e-bd99-462a-9525-0ab3b7b4f9ab","user_phone":""}}	2026-09-11 03:14:12.028892+00	
00000000-0000-0000-0000-000000000000	93ad17fb-3de7-4e15-965e-e8d26b2f7221	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"u1-active@panaderia.local","user_id":"a6649b67-76b5-431d-8744-3fc7e73e334e","user_phone":""}}	2026-09-11 03:16:33.708028+00	
00000000-0000-0000-0000-000000000000	079e2390-1ca0-40ab-b0e2-28c4fde45908	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"u1-inactive@panaderia.local","user_id":"c232d548-1c82-4989-bdb1-8579ca7d7f47","user_phone":""}}	2026-09-11 03:16:33.777715+00	
00000000-0000-0000-0000-000000000000	fc4377a8-6180-44b7-aa4f-791b2408527d	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"u1-noprofile@panaderia.local","user_id":"5b63019e-bd99-462a-9525-0ab3b7b4f9ab","user_phone":""}}	2026-09-11 03:16:33.839807+00	
00000000-0000-0000-0000-000000000000	ef3ca8f6-842b-4f13-aec1-c0272d3144bd	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"u2-active@panaderia.local","user_id":"7b32045f-94a5-4cb9-bf27-f94dea44faa5","user_phone":""}}	2026-09-11 03:18:52.736768+00	
00000000-0000-0000-0000-000000000000	14673b83-6533-4a76-a9ee-fc911227fc13	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"u2-inactive@panaderia.local","user_id":"b0797e08-2acc-4c4b-99d1-93b50bfaf7e4","user_phone":""}}	2026-09-11 03:18:52.84011+00	
00000000-0000-0000-0000-000000000000	0db31bb6-15f5-4997-8778-99eb223304b5	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"u2-active@panaderia.local","user_id":"7b32045f-94a5-4cb9-bf27-f94dea44faa5","user_phone":""}}	2026-09-11 03:20:02.049685+00	
00000000-0000-0000-0000-000000000000	51650b4a-f1ee-40fa-a192-847389e9ca82	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"u2-inactive@panaderia.local","user_id":"b0797e08-2acc-4c4b-99d1-93b50bfaf7e4","user_phone":""}}	2026-09-11 03:20:02.125634+00	
00000000-0000-0000-0000-000000000000	13935b83-140f-4933-bb9b-85519c44ef7c	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"v-check@panaderia.local","user_id":"8feedd8d-b3a3-4178-9e0e-7d6baf1574b2","user_phone":""}}	2026-09-11 03:43:06.66524+00	
00000000-0000-0000-0000-000000000000	bf9a4605-1606-4aee-af71-7d9037feb038	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"v-check@panaderia.local","user_id":"8feedd8d-b3a3-4178-9e0e-7d6baf1574b2","user_phone":""}}	2026-09-11 03:43:06.817584+00	
00000000-0000-0000-0000-000000000000	7d0cd892-eb35-4242-9907-4842feed88dc	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"w1-smoke@bakery.test","user_id":"fe3583dc-e00e-4ec3-a8ca-5b09da32914e","user_phone":""}}	2026-09-11 04:24:54.382756+00	
00000000-0000-0000-0000-000000000000	7a7fdceb-6f4d-4951-8f96-98360feca3b2	{"action":"login","actor_id":"fe3583dc-e00e-4ec3-a8ca-5b09da32914e","actor_username":"w1-smoke@bakery.test","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 04:26:54.22041+00	
00000000-0000-0000-0000-000000000000	9ad2892e-4f17-4e0e-97a9-2fc4d07cca7c	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"w1-smoke@bakery.test","user_id":"fe3583dc-e00e-4ec3-a8ca-5b09da32914e","user_phone":""}}	2026-09-11 04:28:45.238323+00	
00000000-0000-0000-0000-000000000000	e645b884-d78c-4437-b212-567fe30b1784	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"w2-test1@bakery.test","user_id":"b8337c4c-80da-4778-a126-ab0df8f3992e","user_phone":""}}	2026-09-11 04:47:01.136802+00	
00000000-0000-0000-0000-000000000000	7fc213a2-2bbd-4c77-80f2-d7dcc841b176	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"w2-test2@bakery.test","user_id":"2f86da9f-4a43-4a1a-a559-f51b9f11b07c","user_phone":""}}	2026-09-11 04:47:01.245222+00	
00000000-0000-0000-0000-000000000000	1f138cc9-4ada-4cfd-8bec-3153da92b8cb	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"w2-test3@bakery.test","user_id":"1b584041-7d79-4ce6-8b12-d3b5c5e6671a","user_phone":""}}	2026-09-11 04:47:01.357953+00	
00000000-0000-0000-0000-000000000000	bba3669f-b3b4-41a9-af3c-f786aca7c553	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"w2-test1@bakery.test","user_id":"b8337c4c-80da-4778-a126-ab0df8f3992e","user_phone":""}}	2026-09-11 04:50:42.686138+00	
00000000-0000-0000-0000-000000000000	85bdbba2-81cd-4fd9-b111-bd9f196e22f7	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"w2-test2@bakery.test","user_id":"2f86da9f-4a43-4a1a-a559-f51b9f11b07c","user_phone":""}}	2026-09-11 04:50:42.753346+00	
00000000-0000-0000-0000-000000000000	3b153dda-4075-4a4b-b19b-93b487a28e8f	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"w2-test3@bakery.test","user_id":"1b584041-7d79-4ce6-8b12-d3b5c5e6671a","user_phone":""}}	2026-09-11 04:50:42.815667+00	
00000000-0000-0000-0000-000000000000	4baaf5c4-04f7-4635-aaaf-d33c37f318f3	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"w3op@example.com","user_id":"edcb25d1-1fe3-4aff-b178-d7ad879fe43c","user_phone":""}}	2026-09-11 05:20:43.276211+00	
00000000-0000-0000-0000-000000000000	594588e6-66d3-43ee-8e05-67faa05a6ee1	{"action":"login","actor_id":"edcb25d1-1fe3-4aff-b178-d7ad879fe43c","actor_username":"w3op@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 05:21:04.172128+00	
00000000-0000-0000-0000-000000000000	e3614d3f-3e74-441e-b90d-e60b8fe7fe1e	{"action":"login","actor_id":"edcb25d1-1fe3-4aff-b178-d7ad879fe43c","actor_username":"w3op@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 05:21:29.576096+00	
00000000-0000-0000-0000-000000000000	c048b87a-d270-4069-90c2-e3907949c15f	{"action":"login","actor_id":"edcb25d1-1fe3-4aff-b178-d7ad879fe43c","actor_username":"w3op@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 05:21:48.890154+00	
00000000-0000-0000-0000-000000000000	aaeae3ba-0c87-4ccb-a359-1ec249dff468	{"action":"login","actor_id":"edcb25d1-1fe3-4aff-b178-d7ad879fe43c","actor_username":"w3op@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 05:22:04.477315+00	
00000000-0000-0000-0000-000000000000	0fc075ee-fa04-4484-9bfb-79679fdcce56	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"w3op@example.com","user_id":"edcb25d1-1fe3-4aff-b178-d7ad879fe43c","user_phone":""}}	2026-09-11 05:27:03.619007+00	
00000000-0000-0000-0000-000000000000	c5b31fb8-42b7-4a22-a728-885627ebea10	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"x1op@example.com","user_id":"edb690f4-c8d7-4928-bb54-7794bd779131","user_phone":""}}	2026-09-11 05:55:20.429633+00	
00000000-0000-0000-0000-000000000000	43827d22-2408-4c6d-8771-ba95714e6c7b	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"x1inactive@example.com","user_id":"39b39138-ef4f-408e-ac5d-0bb1bbf855c7","user_phone":""}}	2026-09-11 05:56:28.258112+00	
00000000-0000-0000-0000-000000000000	7b01e4f6-f883-43cc-9316-6ea6969eaf61	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"x1inactive@example.com","user_id":"39b39138-ef4f-408e-ac5d-0bb1bbf855c7","user_phone":""}}	2026-09-11 06:00:08.012225+00	
00000000-0000-0000-0000-000000000000	31b2b11b-8dc2-4080-bd0f-f76c6392fa45	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"x1op@example.com","user_id":"edb690f4-c8d7-4928-bb54-7794bd779131","user_phone":""}}	2026-09-11 06:00:27.136172+00	
00000000-0000-0000-0000-000000000000	3bee233c-b062-42a5-b546-9b0799325a63	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"y1op@example.com","user_id":"c063c83d-b444-4ecd-ae29-01fe4c2dec07","user_phone":""}}	2026-09-11 06:04:39.629377+00	
00000000-0000-0000-0000-000000000000	7e0bb548-a2cf-4ada-8dd1-a1ca7c9deb55	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"y1inactive@example.com","user_id":"51877123-23ac-4b52-8414-75303a87c6a5","user_phone":""}}	2026-09-11 06:06:54.437315+00	
00000000-0000-0000-0000-000000000000	77e76f20-0484-423c-ae33-0c0af945f438	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"y1op@example.com","user_id":"c063c83d-b444-4ecd-ae29-01fe4c2dec07","user_phone":""}}	2026-09-11 06:07:50.650551+00	
00000000-0000-0000-0000-000000000000	981b9966-3060-4257-9fd1-1df591ca651d	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"y1inactive@example.com","user_id":"51877123-23ac-4b52-8414-75303a87c6a5","user_phone":""}}	2026-09-11 06:07:50.715816+00	
00000000-0000-0000-0000-000000000000	1e873bbd-9fe4-4dfd-b308-bd3098b8fd82	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"z1op@example.com","user_id":"517f3777-f40c-47a8-a11a-e20ddbe734b3","user_phone":""}}	2026-09-11 06:12:05.216663+00	
00000000-0000-0000-0000-000000000000	cac91438-f042-4c5d-bb46-85e2dca562ae	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"z1inactive@example.com","user_id":"096aae25-5247-4ee0-b25d-2b038903e4d0","user_phone":""}}	2026-09-11 06:12:05.327232+00	
00000000-0000-0000-0000-000000000000	76b46376-afee-48c3-b075-81fc355febfa	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"z1op@example.com","user_id":"517f3777-f40c-47a8-a11a-e20ddbe734b3","user_phone":""}}	2026-09-11 06:21:11.001649+00	
00000000-0000-0000-0000-000000000000	1d70502f-9730-4e32-9fe5-69ad23222b8b	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"z1inactive@example.com","user_id":"096aae25-5247-4ee0-b25d-2b038903e4d0","user_phone":""}}	2026-09-11 06:21:11.05982+00	
00000000-0000-0000-0000-000000000000	79ea5879-f4aa-44cd-b20e-d7df49b3c89b	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"aa1op@example.com","user_id":"c45d11ed-83bd-4369-b591-949c2af3fa53","user_phone":""}}	2026-09-11 06:31:12.539886+00	
00000000-0000-0000-0000-000000000000	157a2ce9-2d75-4135-8ae6-ef1a9fb5e03f	{"action":"login","actor_id":"c45d11ed-83bd-4369-b591-949c2af3fa53","actor_username":"aa1op@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 06:31:45.135476+00	
00000000-0000-0000-0000-000000000000	867f1202-5f0d-44f0-ae26-c507e5272b1d	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"aa1op@example.com","user_id":"c45d11ed-83bd-4369-b591-949c2af3fa53","user_phone":""}}	2026-09-11 06:34:10.053444+00	
00000000-0000-0000-0000-000000000000	2585405b-ba1c-4135-8cbc-0ed8458f9060	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ab1op@example.com","user_id":"83997e63-9d99-4da3-9add-d0dd54fa6976","user_phone":""}}	2026-09-11 06:51:55.580956+00	
00000000-0000-0000-0000-000000000000	0062a500-8a17-4f21-a36f-0dbe078ed451	{"action":"login","actor_id":"83997e63-9d99-4da3-9add-d0dd54fa6976","actor_username":"ab1op@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 06:52:12.274326+00	
00000000-0000-0000-0000-000000000000	567000f8-4d2f-4772-b279-c160503854ba	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ab1op@example.com","user_id":"83997e63-9d99-4da3-9add-d0dd54fa6976","user_phone":""}}	2026-09-11 06:57:10.267657+00	
00000000-0000-0000-0000-000000000000	b6b3219d-478b-4c6a-aabb-724a1b25fc18	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ad1test@example.com","user_id":"f1839d02-c111-445c-b5af-10ed6c7ab5d4","user_phone":""}}	2026-09-11 07:07:53.809694+00	
00000000-0000-0000-0000-000000000000	13d7f90d-150b-4f67-bde9-9922a9e276e4	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ad1test@example.com","user_id":"f1839d02-c111-445c-b5af-10ed6c7ab5d4","user_phone":""}}	2026-09-11 07:19:37.537338+00	
00000000-0000-0000-0000-000000000000	6e2e0e4b-6caa-4209-85a1-d17ea68b33f7	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"af1test@example.com","user_id":"09be8c30-d2bf-44b5-970a-a7904154271a","user_phone":""}}	2026-09-11 07:32:03.921418+00	
00000000-0000-0000-0000-000000000000	67f97712-fd96-49b9-9d5d-9814d9c8d49b	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"af1noprofile@example.com","user_id":"b1838536-679e-463a-a709-d62cd36d83c1","user_phone":""}}	2026-09-11 07:32:04.042658+00	
00000000-0000-0000-0000-000000000000	3de2d64d-762c-44b5-8b36-4be4c8853230	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"af1test@example.com","user_id":"09be8c30-d2bf-44b5-970a-a7904154271a","user_phone":""}}	2026-09-11 07:37:44.910634+00	
00000000-0000-0000-0000-000000000000	588cbadc-afe2-4ba3-b2a0-c200eeeca0c4	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"af1noprofile@example.com","user_id":"b1838536-679e-463a-a709-d62cd36d83c1","user_phone":""}}	2026-09-11 07:37:44.966687+00	
00000000-0000-0000-0000-000000000000	70f2152c-133e-4b75-9200-ac17cbc06a26	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"af1test@example.com","user_id":"72609b50-d359-466e-9c23-7d88666925e5","user_phone":""}}	2026-09-11 07:38:18.227773+00	
00000000-0000-0000-0000-000000000000	df0f6b11-8f74-4267-bd0e-e2e1556fa10c	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"af1noprofile@example.com","user_id":"3009bcc0-e0b3-44c2-aebd-daa5333010a7","user_phone":""}}	2026-09-11 07:38:18.341908+00	
00000000-0000-0000-0000-000000000000	a972baf8-4c4e-4fb7-9b56-7b5e40ce8443	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"af1test@example.com","user_id":"72609b50-d359-466e-9c23-7d88666925e5","user_phone":""}}	2026-09-11 07:46:32.840547+00	
00000000-0000-0000-0000-000000000000	7f30ca92-cbd7-4a0c-b868-d56d3901fc54	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"af1noprofile@example.com","user_id":"3009bcc0-e0b3-44c2-aebd-daa5333010a7","user_phone":""}}	2026-09-11 07:46:32.891626+00	
00000000-0000-0000-0000-000000000000	be459e92-33f8-4b42-9f14-097610c1a44d	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ag1-smoke-1789115011@example.com","user_id":"9d0f239b-da5b-4781-b03c-6fc8ce561b92","user_phone":""}}	2026-09-11 08:23:32.148258+00	
00000000-0000-0000-0000-000000000000	5ac73c80-96b7-46d7-88b2-b1221be5e076	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ag1-smoke-1789115011@example.com","user_id":"9d0f239b-da5b-4781-b03c-6fc8ce561b92","user_phone":""}}	2026-09-11 08:23:33.666286+00	
00000000-0000-0000-0000-000000000000	91a23ee3-88a0-428a-bb3e-1cdad2422dfb	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ag1-smoke-1789115090@example.com","user_id":"686cf2f5-cb59-44a6-b415-0c88a1c93f85","user_phone":""}}	2026-09-11 08:24:50.315798+00	
00000000-0000-0000-0000-000000000000	911b189a-539b-4ca0-b0d9-7db36675c598	{"action":"login","actor_id":"686cf2f5-cb59-44a6-b415-0c88a1c93f85","actor_username":"ag1-smoke-1789115090@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 08:24:50.990139+00	
00000000-0000-0000-0000-000000000000	8a95be2d-137c-4198-90e6-cc07e4a45510	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ag1-smoke-1789115090@example.com","user_id":"686cf2f5-cb59-44a6-b415-0c88a1c93f85","user_phone":""}}	2026-09-11 08:24:52.988583+00	
00000000-0000-0000-0000-000000000000	ff05efe3-5cd7-4577-851e-09f4759c138d	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ah1-smoke-1789116259@example.com","user_id":"49752e77-6480-47cd-9074-25892d5baceb","user_phone":""}}	2026-09-11 08:44:19.154303+00	
00000000-0000-0000-0000-000000000000	5a026709-c23c-426b-a960-28d14143f6f5	{"action":"login","actor_id":"49752e77-6480-47cd-9074-25892d5baceb","actor_username":"ah1-smoke-1789116259@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 08:44:19.816922+00	
00000000-0000-0000-0000-000000000000	95d4d09e-2910-4533-b130-8cc8cabae43a	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ah1-smoke-1789116259@example.com","user_id":"49752e77-6480-47cd-9074-25892d5baceb","user_phone":""}}	2026-09-11 08:44:21.061226+00	
00000000-0000-0000-0000-000000000000	7adcd84a-7fc3-45d2-8a3a-55ffa8d25ce1	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ah1dbg-1789116319@example.com","user_id":"e3b7ac0f-24a7-497c-ae1b-131e5babfb52","user_phone":""}}	2026-09-11 08:45:19.299032+00	
00000000-0000-0000-0000-000000000000	77f6cf42-f1f6-4b5c-9594-1defaf4ea27e	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ah1dbg-1789116370@example.com","user_id":"d180b0c8-69d8-47e3-b6f5-1d628bdef3ec","user_phone":""}}	2026-09-11 08:46:10.95943+00	
00000000-0000-0000-0000-000000000000	6c44f8b7-1455-4065-ae89-ae300082fa8a	{"action":"login","actor_id":"d180b0c8-69d8-47e3-b6f5-1d628bdef3ec","actor_username":"ah1dbg-1789116370@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 08:46:11.447263+00	
00000000-0000-0000-0000-000000000000	3c3fe25a-1c8a-4ab5-aeed-fe750e6ac36a	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ah1dbg-1789116370@example.com","user_id":"d180b0c8-69d8-47e3-b6f5-1d628bdef3ec","user_phone":""}}	2026-09-11 08:46:12.333613+00	
00000000-0000-0000-0000-000000000000	1a418e4a-6e9e-40d4-b9bf-a49e9ea1bf77	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ah1dbg-1789116319@example.com","user_id":"e3b7ac0f-24a7-497c-ae1b-131e5babfb52","user_phone":""}}	2026-09-11 08:47:25.412902+00	
00000000-0000-0000-0000-000000000000	2d8e4bab-72f2-4e79-b085-3fbe8e9051c4	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ah1-smoke-1789116533@example.com","user_id":"2dfd6d02-2bd4-4d14-9aeb-16480a24a8e6","user_phone":""}}	2026-09-11 08:48:53.283244+00	
00000000-0000-0000-0000-000000000000	ab4b4681-df15-46d4-9feb-8293616fc779	{"action":"login","actor_id":"2dfd6d02-2bd4-4d14-9aeb-16480a24a8e6","actor_username":"ah1-smoke-1789116533@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 08:48:53.878917+00	
00000000-0000-0000-0000-000000000000	9016f9d6-7bea-47e4-880e-f530d3d9c08d	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ah1-smoke-1789116533@example.com","user_id":"2dfd6d02-2bd4-4d14-9aeb-16480a24a8e6","user_phone":""}}	2026-09-11 08:48:54.989519+00	
00000000-0000-0000-0000-000000000000	3044942e-e622-4a84-9d73-36923afe2714	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ai1-op-1789117279@example.com","user_id":"3d91d224-af98-4213-8417-4987fdb1510b","user_phone":""}}	2026-09-11 09:01:19.585764+00	
00000000-0000-0000-0000-000000000000	b2615768-fc0e-4867-900b-ce94e9497589	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ai1-noprof-1789117279@example.com","user_id":"4d3085b0-ad9f-4190-a39e-7b0bc5c3d010","user_phone":""}}	2026-09-11 09:01:19.690337+00	
00000000-0000-0000-0000-000000000000	c6f7a1e5-ed83-4aa6-a972-1f4fefa04d52	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ai1-noprof-1789117279@example.com","user_id":"4d3085b0-ad9f-4190-a39e-7b0bc5c3d010","user_phone":""}}	2026-09-11 09:01:23.079451+00	
00000000-0000-0000-0000-000000000000	899da394-a1bb-4cc3-8b3f-c29e0b32ab9e	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ai1-op-1789117279@example.com","user_id":"3d91d224-af98-4213-8417-4987fdb1510b","user_phone":""}}	2026-09-11 09:03:00.153005+00	
00000000-0000-0000-0000-000000000000	a032bfac-36da-43fe-958e-3c512ed50155	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ai1-op-1789117386@example.com","user_id":"4f3fa687-51bf-4fdb-ac5d-89f6d4e896e7","user_phone":""}}	2026-09-11 09:03:06.868543+00	
00000000-0000-0000-0000-000000000000	a2c09ced-aebb-49ce-8df3-268e7bccdf18	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ai1-noprof-1789117386@example.com","user_id":"373bd475-9237-496d-a0d1-541e4ef134cd","user_phone":""}}	2026-09-11 09:03:06.96511+00	
00000000-0000-0000-0000-000000000000	19671a56-e8be-4385-85fe-595b97861d9d	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ai1-op-1789117386@example.com","user_id":"4f3fa687-51bf-4fdb-ac5d-89f6d4e896e7","user_phone":""}}	2026-09-11 09:03:11.22271+00	
00000000-0000-0000-0000-000000000000	64f1ed50-6afa-48de-9cb5-b56911013b86	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ai1-noprof-1789117386@example.com","user_id":"373bd475-9237-496d-a0d1-541e4ef134cd","user_phone":""}}	2026-09-11 09:03:11.291164+00	
00000000-0000-0000-0000-000000000000	ac99df58-9f27-49e4-af77-a5d67dd6bd9c	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ai1-op-1789117423@example.com","user_id":"46a704e0-e9eb-4058-99d2-eaae9237f099","user_phone":""}}	2026-09-11 09:03:43.318655+00	
00000000-0000-0000-0000-000000000000	22b0b57c-8913-4c0e-a8f1-2f3f99de2a54	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ai1-noprof-1789117423@example.com","user_id":"cc203b7d-d3d0-42fb-a283-63560839bc78","user_phone":""}}	2026-09-11 09:03:43.443301+00	
00000000-0000-0000-0000-000000000000	79b68ab3-39d2-4cad-9138-9e7020aea937	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ai1-op-1789117423@example.com","user_id":"46a704e0-e9eb-4058-99d2-eaae9237f099","user_phone":""}}	2026-09-11 09:03:47.756915+00	
00000000-0000-0000-0000-000000000000	fe85afc8-b099-45fd-aad8-4bbf99294b49	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ai1-noprof-1789117423@example.com","user_id":"cc203b7d-d3d0-42fb-a283-63560839bc78","user_phone":""}}	2026-09-11 09:03:47.806629+00	
00000000-0000-0000-0000-000000000000	ac43f3e9-d3d3-454b-85df-9c7552a8be96	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ai2-smoke-1789119230@example.com","user_id":"0867a735-411d-4ac2-8cbd-c8c73ae5e036","user_phone":""}}	2026-09-11 09:33:50.286774+00	
00000000-0000-0000-0000-000000000000	5bd52ef4-c856-43c7-9afb-e3909ed61624	{"action":"login","actor_id":"0867a735-411d-4ac2-8cbd-c8c73ae5e036","actor_username":"ai2-smoke-1789119230@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 09:33:50.903099+00	
00000000-0000-0000-0000-000000000000	9de3245a-0b19-4fdf-9141-f8404309506e	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ai2-smoke-1789119230@example.com","user_id":"0867a735-411d-4ac2-8cbd-c8c73ae5e036","user_phone":""}}	2026-09-11 09:33:53.593563+00	
00000000-0000-0000-0000-000000000000	dcaeb352-effd-40a5-81d6-cfbe377b3e3a	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ai2dbg-1789119315@example.com","user_id":"d98cda35-fdc8-4a6d-859d-f94f84532185","user_phone":""}}	2026-09-11 09:35:15.676613+00	
00000000-0000-0000-0000-000000000000	3c0f044c-f90d-4e5d-aaf9-2e287c12fd88	{"action":"login","actor_id":"d98cda35-fdc8-4a6d-859d-f94f84532185","actor_username":"ai2dbg-1789119315@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 09:35:16.252931+00	
00000000-0000-0000-0000-000000000000	2a70659f-2b92-41c4-b3d9-409d3896948c	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ai2dbg-1789119315@example.com","user_id":"d98cda35-fdc8-4a6d-859d-f94f84532185","user_phone":""}}	2026-09-11 09:35:17.133387+00	
00000000-0000-0000-0000-000000000000	8612372d-13d7-45d3-9260-e84da03051b5	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ai2-smoke-1789119469@example.com","user_id":"9153fe7f-43f9-4ade-96d6-a0b064636b54","user_phone":""}}	2026-09-11 09:37:49.224971+00	
00000000-0000-0000-0000-000000000000	907e51d1-a4bb-4348-b7be-62f1d0459f4f	{"action":"login","actor_id":"9153fe7f-43f9-4ade-96d6-a0b064636b54","actor_username":"ai2-smoke-1789119469@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 09:37:49.857312+00	
00000000-0000-0000-0000-000000000000	ff32c0ca-52e8-43cd-9ba2-87f82f9dcaf5	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ai2-smoke-1789119469@example.com","user_id":"9153fe7f-43f9-4ade-96d6-a0b064636b54","user_phone":""}}	2026-09-11 09:37:52.343114+00	
00000000-0000-0000-0000-000000000000	eadd1b01-b444-4236-8949-3e7792f5b6e3	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"aj1-smoke-1789119943@example.com","user_id":"744892ec-4c55-4e5e-8f5a-85da9675b65e","user_phone":""}}	2026-09-11 09:45:43.871149+00	
00000000-0000-0000-0000-000000000000	a454ba2a-147e-497d-83e7-659ec00c2f18	{"action":"login","actor_id":"744892ec-4c55-4e5e-8f5a-85da9675b65e","actor_username":"aj1-smoke-1789119943@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 09:45:44.336302+00	
00000000-0000-0000-0000-000000000000	b500acb6-2ed6-432a-8a60-62ab29cea92e	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"aj1-smoke-1789119943@example.com","user_id":"744892ec-4c55-4e5e-8f5a-85da9675b65e","user_phone":""}}	2026-09-11 09:45:45.404253+00	
00000000-0000-0000-0000-000000000000	b513f10e-11f6-46ed-ae1c-6cd288914efe	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ak1-smoke-1789130125@example.com","user_id":"9b6ba063-81d5-4a8a-a750-20e3f06414fc","user_phone":""}}	2026-09-11 12:35:26.173452+00	
00000000-0000-0000-0000-000000000000	2e88807e-35ea-4e7e-873e-dd1ebb12ac27	{"action":"login","actor_id":"9b6ba063-81d5-4a8a-a750-20e3f06414fc","actor_username":"ak1-smoke-1789130125@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 12:35:26.777041+00	
00000000-0000-0000-0000-000000000000	5b20ff7b-82fc-4db7-aaea-1f70f8cd263e	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ak1-smoke-1789130125@example.com","user_id":"9b6ba063-81d5-4a8a-a750-20e3f06414fc","user_phone":""}}	2026-09-11 12:35:28.220213+00	
00000000-0000-0000-0000-000000000000	0100eda5-0eb2-4d61-899b-490f3065e97c	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ak2-op-1789131197@example.com","user_id":"dd5904b3-138e-4e3b-b21f-329a0b7df5a4","user_phone":""}}	2026-09-11 12:53:17.899855+00	
00000000-0000-0000-0000-000000000000	1b44f989-0519-4fca-9665-5c3387725bce	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ak2-sup-1789131197@example.com","user_id":"80c99638-2139-4803-b498-3f55c0b3f4ab","user_phone":""}}	2026-09-11 12:53:18.101921+00	
00000000-0000-0000-0000-000000000000	31d2c847-8ec1-482c-9519-475c16fd8e97	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ak2-adm-1789131197@example.com","user_id":"13bae0c7-0459-4f26-aea5-fe1b45d50c9c","user_phone":""}}	2026-09-11 12:53:18.344861+00	
00000000-0000-0000-0000-000000000000	4a5c23b0-8909-4ff4-a216-63baf8cefa68	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ak2-inact-1789131197@example.com","user_id":"8ba31192-3386-4d36-b1f3-737500bb65cc","user_phone":""}}	2026-09-11 12:53:18.574603+00	
00000000-0000-0000-0000-000000000000	7913c3d3-d00b-4afc-b48c-a30eac817b20	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ak2-op-1789131197@example.com","user_id":"dd5904b3-138e-4e3b-b21f-329a0b7df5a4","user_phone":""}}	2026-09-11 12:53:21.813539+00	
00000000-0000-0000-0000-000000000000	9b5efe8e-9d7b-4a52-86c8-40999cf391ca	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ak2-sup-1789131197@example.com","user_id":"80c99638-2139-4803-b498-3f55c0b3f4ab","user_phone":""}}	2026-09-11 12:53:22.041196+00	
00000000-0000-0000-0000-000000000000	d55abc93-2fe7-43e3-8894-67a0d7975fa0	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ak2-adm-1789131197@example.com","user_id":"13bae0c7-0459-4f26-aea5-fe1b45d50c9c","user_phone":""}}	2026-09-11 12:53:22.28753+00	
00000000-0000-0000-0000-000000000000	1b24c282-d734-4275-90f4-b339a7f678e9	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ak2-inact-1789131197@example.com","user_id":"8ba31192-3386-4d36-b1f3-737500bb65cc","user_phone":""}}	2026-09-11 12:53:22.522897+00	
00000000-0000-0000-0000-000000000000	2f0fc28c-d3a4-41e1-a59f-57d4c1ffbbc7	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ak2-op-1789131712@example.com","user_id":"5be93665-104e-431c-84e8-3318f540307b","user_phone":""}}	2026-09-11 13:01:52.622754+00	
00000000-0000-0000-0000-000000000000	f070a39a-11a6-4b4a-97e1-a60ea993a74d	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ak2-sup-1789131712@example.com","user_id":"1132e958-f83e-446e-9c6a-66bfd8e1e4f4","user_phone":""}}	2026-09-11 13:01:52.853643+00	
00000000-0000-0000-0000-000000000000	fe74a8a9-4f63-4325-a5c8-fd1472419888	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ak2-adm-1789131712@example.com","user_id":"c8dbe0d3-e01d-4bd9-8714-318422970b04","user_phone":""}}	2026-09-11 13:01:53.107234+00	
00000000-0000-0000-0000-000000000000	03537d3c-276e-4002-8803-d3047fdb22d3	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ak2-inact-1789131712@example.com","user_id":"cd246191-c76e-45e2-a043-adcc6ba5a296","user_phone":""}}	2026-09-11 13:01:53.340379+00	
00000000-0000-0000-0000-000000000000	16938de4-5b75-44e7-a615-f5de31e83d04	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ak2-op-1789131712@example.com","user_id":"5be93665-104e-431c-84e8-3318f540307b","user_phone":""}}	2026-09-11 13:01:56.580745+00	
00000000-0000-0000-0000-000000000000	a261cf24-bd8e-4ccd-8fe9-c5a18e0db67f	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ak2-sup-1789131712@example.com","user_id":"1132e958-f83e-446e-9c6a-66bfd8e1e4f4","user_phone":""}}	2026-09-11 13:01:56.804794+00	
00000000-0000-0000-0000-000000000000	4a48fd18-318c-4814-8442-a53d5fcfed82	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ak2-adm-1789131712@example.com","user_id":"c8dbe0d3-e01d-4bd9-8714-318422970b04","user_phone":""}}	2026-09-11 13:01:57.081737+00	
00000000-0000-0000-0000-000000000000	47a31c46-861e-409a-9169-76b075d4baf2	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ak2-inact-1789131712@example.com","user_id":"cd246191-c76e-45e2-a043-adcc6ba5a296","user_phone":""}}	2026-09-11 13:01:57.308561+00	
00000000-0000-0000-0000-000000000000	dc3ca8f3-1d06-4d18-98fc-9c6769df68a1	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ak2ui-sup-1789131906@example.com","user_id":"275ab6e6-d507-49e5-8498-6251954f312b","user_phone":""}}	2026-09-11 13:05:06.324441+00	
00000000-0000-0000-0000-000000000000	52139dd8-89b9-4464-ae65-c90b04617a1d	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ak2ui-op-1789131906@example.com","user_id":"21e58bb2-3eb4-4cf4-b990-87fae22933e0","user_phone":""}}	2026-09-11 13:05:06.57207+00	
00000000-0000-0000-0000-000000000000	dc818ee1-0938-44f9-b7c6-118997f456d0	{"action":"login","actor_id":"275ab6e6-d507-49e5-8498-6251954f312b","actor_username":"ak2ui-sup-1789131906@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 13:05:07.134541+00	
00000000-0000-0000-0000-000000000000	01a4e706-de34-4082-9497-12ea05a3e1fc	{"action":"login","actor_id":"21e58bb2-3eb4-4cf4-b990-87fae22933e0","actor_username":"ak2ui-op-1789131906@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 13:05:07.411528+00	
00000000-0000-0000-0000-000000000000	3429c7a4-1528-4f34-be7a-923646bbc986	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ak2ui-sup-1789131906@example.com","user_id":"275ab6e6-d507-49e5-8498-6251954f312b","user_phone":""}}	2026-09-11 13:05:09.546695+00	
00000000-0000-0000-0000-000000000000	1b5b46d0-574e-4c23-924c-66e4c0a48b16	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ak2ui-op-1789131906@example.com","user_id":"21e58bb2-3eb4-4cf4-b990-87fae22933e0","user_phone":""}}	2026-09-11 13:05:09.672502+00	
00000000-0000-0000-0000-000000000000	bc3a0385-5986-448a-b8c8-0253789f2cef	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ak3-op-1789132448@example.com","user_id":"491143db-7f51-4744-95a6-41cef18a7b40","user_phone":""}}	2026-09-11 13:14:08.982461+00	
00000000-0000-0000-0000-000000000000	7a91a1a2-764c-46ae-820d-b7134305f92d	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ak3-sup-1789132448@example.com","user_id":"d29f02b8-5af6-4783-82ed-f4295fd90b81","user_phone":""}}	2026-09-11 13:14:09.21673+00	
00000000-0000-0000-0000-000000000000	f637c0ef-0d59-4d0b-a549-0d077e2c0d46	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ak3-adm-1789132448@example.com","user_id":"8101a6f8-8ded-4f9a-876b-fefce50853bd","user_phone":""}}	2026-09-11 13:14:09.476952+00	
00000000-0000-0000-0000-000000000000	bb6c5da6-ba5e-4038-ac4a-05e897ffb574	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ak3-op-1789132448@example.com","user_id":"491143db-7f51-4744-95a6-41cef18a7b40","user_phone":""}}	2026-09-11 13:14:12.942628+00	
00000000-0000-0000-0000-000000000000	2cb736cb-9df7-4186-ac26-59aa02e0e45c	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ak3-sup-1789132448@example.com","user_id":"d29f02b8-5af6-4783-82ed-f4295fd90b81","user_phone":""}}	2026-09-11 13:14:13.198307+00	
00000000-0000-0000-0000-000000000000	ce2ffd76-7610-4b82-8b9e-74e7978d60a8	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ak3-adm-1789132448@example.com","user_id":"8101a6f8-8ded-4f9a-876b-fefce50853bd","user_phone":""}}	2026-09-11 13:14:13.430782+00	
00000000-0000-0000-0000-000000000000	bd58667d-4c45-4c33-a0fa-5483747f920d	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ak3ui-sup-1789133997@example.com","user_id":"e5213344-dbbe-4a79-bde2-acd838bea505","user_phone":""}}	2026-09-11 13:39:57.259395+00	
00000000-0000-0000-0000-000000000000	d78c6bdd-f79d-40fa-8c7d-426cef85dac9	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ak3ui-op-1789133997@example.com","user_id":"470a9659-446f-4f70-9525-95935c835dfd","user_phone":""}}	2026-09-11 13:39:57.450793+00	
00000000-0000-0000-0000-000000000000	c37bcea5-9251-4680-a4b3-99d4952117f6	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ak3ui-sup-1789133997@example.com","user_id":"e5213344-dbbe-4a79-bde2-acd838bea505","user_phone":""}}	2026-09-11 13:53:47.74129+00	
00000000-0000-0000-0000-000000000000	11ec12b9-c926-4508-8449-ab8260259bb1	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ak3ui-op-1789133997@example.com","user_id":"470a9659-446f-4f70-9525-95935c835dfd","user_phone":""}}	2026-09-11 13:53:47.846765+00	
00000000-0000-0000-0000-000000000000	adc127d3-e5dd-4a27-b232-c73e41c3b466	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ak3ui-sup-1789134837@example.com","user_id":"9ccff4c3-aefb-43e5-8c71-a6f40cca642b","user_phone":""}}	2026-09-11 13:53:57.489257+00	
00000000-0000-0000-0000-000000000000	640d2785-0628-414d-8f4c-751a2bc9f817	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ak3ui-op-1789134837@example.com","user_id":"b85a909a-e664-4d49-9a24-01b21bd7eefa","user_phone":""}}	2026-09-11 13:53:57.722713+00	
00000000-0000-0000-0000-000000000000	d7b52b88-5443-423b-9dc5-3931da504cca	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ak3ui-op-1789134837@example.com","user_id":"b85a909a-e664-4d49-9a24-01b21bd7eefa","user_phone":""}}	2026-09-11 13:54:58.797331+00	
00000000-0000-0000-0000-000000000000	a8ef4cf8-e450-4963-bb6f-fb2229651109	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ak3ui-sup-1789134919@example.com","user_id":"50c0d303-0b71-4774-8b8f-6a81ad05bb79","user_phone":""}}	2026-09-11 13:55:19.742562+00	
00000000-0000-0000-0000-000000000000	86c3a15a-cc8f-43e1-816f-62029823dd1e	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ak3ui-op-1789134919@example.com","user_id":"393650fc-ab9f-4d8e-9dac-6d0a1c90803f","user_phone":""}}	2026-09-11 13:55:19.941908+00	
00000000-0000-0000-0000-000000000000	d98a6885-9728-4bbd-88cf-9ac9ee25aca8	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ak3ui-sup-1789135006@example.com","user_id":"f204bf84-e5de-4ac3-b2bc-82b241d6cf3f","user_phone":""}}	2026-09-11 13:56:46.44162+00	
00000000-0000-0000-0000-000000000000	96c3c18c-183a-401f-8617-d05010ab7441	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ak3ui-op-1789135006@example.com","user_id":"0a7d4b77-936e-4923-8456-2221732065ef","user_phone":""}}	2026-09-11 13:56:46.67325+00	
00000000-0000-0000-0000-000000000000	9a792a4f-ad7e-450d-bfc0-db00e1c5fc91	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ak3ui-op-1789134919@example.com","user_id":"393650fc-ab9f-4d8e-9dac-6d0a1c90803f","user_phone":""}}	2026-09-11 14:04:30.737266+00	
00000000-0000-0000-0000-000000000000	8e3d70df-f50a-4c28-8f92-83e7556ef583	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ak3ui-op-1789135006@example.com","user_id":"0a7d4b77-936e-4923-8456-2221732065ef","user_phone":""}}	2026-09-11 14:04:31.047114+00	
00000000-0000-0000-0000-000000000000	5778949a-c872-420c-bad9-bd2a7cb343e6	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ak3ui-sup-1789134837@example.com","user_id":"9ccff4c3-aefb-43e5-8c71-a6f40cca642b","user_phone":""}}	2026-09-11 14:05:11.537802+00	
00000000-0000-0000-0000-000000000000	b6543706-1960-46e3-8519-d29adda346aa	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ak3ui-sup-1789134919@example.com","user_id":"50c0d303-0b71-4774-8b8f-6a81ad05bb79","user_phone":""}}	2026-09-11 14:05:11.658994+00	
00000000-0000-0000-0000-000000000000	1fba0141-898d-4654-87b2-8fc960ae2413	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ak3ui-sup-1789135006@example.com","user_id":"f204bf84-e5de-4ac3-b2bc-82b241d6cf3f","user_phone":""}}	2026-09-11 14:05:11.765233+00	
00000000-0000-0000-0000-000000000000	c26ecef8-43d8-4f7c-ab75-c5170520de44	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ak3ui-sup-1789135590@example.com","user_id":"60494fa4-103c-44de-a819-0cf848628a54","user_phone":""}}	2026-09-11 14:06:30.559414+00	
00000000-0000-0000-0000-000000000000	3d883c86-cfef-43d8-a1ea-01bdc805ff2b	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ak3ui-op-1789135590@example.com","user_id":"d5d22678-2e8d-4ec0-9429-04e9a6081e3b","user_phone":""}}	2026-09-11 14:06:30.797033+00	
00000000-0000-0000-0000-000000000000	3d3f72ee-bab6-40a1-ae4f-ae73118c8cfe	{"action":"login","actor_id":"60494fa4-103c-44de-a819-0cf848628a54","actor_username":"ak3ui-sup-1789135590@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 14:06:31.463848+00	
00000000-0000-0000-0000-000000000000	f83b3bc5-a7af-4804-82e9-fced088f6906	{"action":"login","actor_id":"d5d22678-2e8d-4ec0-9429-04e9a6081e3b","actor_username":"ak3ui-op-1789135590@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 14:06:31.723217+00	
00000000-0000-0000-0000-000000000000	f4aa053a-72f0-433c-83b1-5e1e48cbb68b	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ak3ui-sup-1789135590@example.com","user_id":"60494fa4-103c-44de-a819-0cf848628a54","user_phone":""}}	2026-09-11 14:06:35.142179+00	
00000000-0000-0000-0000-000000000000	357f7b81-b4d0-40f2-9b24-8a5b4425a795	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ak3ui-op-1789135590@example.com","user_id":"d5d22678-2e8d-4ec0-9429-04e9a6081e3b","user_phone":""}}	2026-09-11 14:06:35.250534+00	
00000000-0000-0000-0000-000000000000	6c6f14c4-9f77-40be-b40b-622f1b355349	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ak3ui-sup-1789135653@example.com","user_id":"454754c4-7e28-4ecb-9d80-11db67747878","user_phone":""}}	2026-09-11 14:07:33.836035+00	
00000000-0000-0000-0000-000000000000	251c248b-c317-4415-8577-0cedbb43d99a	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ak3ui-op-1789135653@example.com","user_id":"958dd015-9110-4994-907b-b291f1efc077","user_phone":""}}	2026-09-11 14:07:34.058073+00	
00000000-0000-0000-0000-000000000000	4efdb4b7-6b0c-491a-bd87-cc8730c07668	{"action":"login","actor_id":"454754c4-7e28-4ecb-9d80-11db67747878","actor_username":"ak3ui-sup-1789135653@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 14:07:34.694428+00	
00000000-0000-0000-0000-000000000000	245e6a53-08c0-44a9-8f0e-f8b633f31c9e	{"action":"login","actor_id":"958dd015-9110-4994-907b-b291f1efc077","actor_username":"ak3ui-op-1789135653@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 14:07:34.972864+00	
00000000-0000-0000-0000-000000000000	8bfed823-8788-4828-9276-658774076425	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ak3ui-sup-1789135653@example.com","user_id":"454754c4-7e28-4ecb-9d80-11db67747878","user_phone":""}}	2026-09-11 14:07:37.741582+00	
00000000-0000-0000-0000-000000000000	4d17b5be-b2da-4d71-817e-3f83a8c0e767	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ak3ui-op-1789135653@example.com","user_id":"958dd015-9110-4994-907b-b291f1efc077","user_phone":""}}	2026-09-11 14:07:37.839881+00	
00000000-0000-0000-0000-000000000000	fa7042fd-ed5c-41ee-b2b9-417f6b05e037	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al1-op-1789137444@example.com","user_id":"e3e03d9d-c4b7-424c-9511-f6e52f35efbf","user_phone":""}}	2026-09-11 14:37:24.717063+00	
00000000-0000-0000-0000-000000000000	db871f6d-fef7-48d0-9bbf-dea8974eae63	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al1-sup-1789137444@example.com","user_id":"f973d0ec-bb25-4c17-a477-6c4cdc57c0a1","user_phone":""}}	2026-09-11 14:37:24.920994+00	
00000000-0000-0000-0000-000000000000	fa35e2c3-26bf-4a6c-83de-7bcd1a9297e1	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al1-adm-1789137444@example.com","user_id":"0f20fd2d-3f9f-4e1d-88f0-0e1b41e92302","user_phone":""}}	2026-09-11 14:37:25.138955+00	
00000000-0000-0000-0000-000000000000	5349af47-1524-4714-996f-a92865d06760	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al1-op-1789137444@example.com","user_id":"e3e03d9d-c4b7-424c-9511-f6e52f35efbf","user_phone":""}}	2026-09-11 14:37:29.358336+00	
00000000-0000-0000-0000-000000000000	279fa2b6-e4f5-4047-b661-5c90e7addda2	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al1-sup-1789137444@example.com","user_id":"f973d0ec-bb25-4c17-a477-6c4cdc57c0a1","user_phone":""}}	2026-09-11 14:37:29.457439+00	
00000000-0000-0000-0000-000000000000	9d00adb6-5cf1-41a0-93ed-bc72cfac1b76	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al1-adm-1789137444@example.com","user_id":"0f20fd2d-3f9f-4e1d-88f0-0e1b41e92302","user_phone":""}}	2026-09-11 14:37:29.57104+00	
00000000-0000-0000-0000-000000000000	55c8dbe1-acd7-4125-9457-4bae50c86dbe	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al1-op-1789137470@example.com","user_id":"f4552628-07e7-49e9-8794-f4dc73910687","user_phone":""}}	2026-09-11 14:37:50.577261+00	
00000000-0000-0000-0000-000000000000	237078ec-0e09-4ef8-9907-629eb18560eb	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al1-sup-1789137470@example.com","user_id":"964724de-8231-4063-bcfe-92f86dc19304","user_phone":""}}	2026-09-11 14:37:50.802857+00	
00000000-0000-0000-0000-000000000000	f5847fd8-5849-4435-bf11-1a32d076b2ae	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al1-adm-1789137470@example.com","user_id":"c3ef001e-3f9a-4f91-8f39-72080ed4894b","user_phone":""}}	2026-09-11 14:37:51.043271+00	
00000000-0000-0000-0000-000000000000	c457d759-9857-4f38-9ac8-041d44193c79	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al1-op-1789137470@example.com","user_id":"f4552628-07e7-49e9-8794-f4dc73910687","user_phone":""}}	2026-09-11 14:37:55.026319+00	
00000000-0000-0000-0000-000000000000	24b21f06-3567-4d18-bad6-cc955f74f414	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al1-sup-1789137470@example.com","user_id":"964724de-8231-4063-bcfe-92f86dc19304","user_phone":""}}	2026-09-11 14:37:55.136599+00	
00000000-0000-0000-0000-000000000000	c2e33343-d372-4230-be50-4079fb12b955	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al1-adm-1789137470@example.com","user_id":"c3ef001e-3f9a-4f91-8f39-72080ed4894b","user_phone":""}}	2026-09-11 14:37:55.244965+00	
00000000-0000-0000-0000-000000000000	a107a4e0-2a5a-4d09-89f2-0637a477d062	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al1ui-adm-1789137675@example.com","user_id":"a8f88c58-3aa0-4ed3-a501-844b1b08cd34","user_phone":""}}	2026-09-11 14:41:16.074178+00	
00000000-0000-0000-0000-000000000000	de159a3f-2c0b-481d-8509-2b1076bfa178	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al1ui-op-1789137675@example.com","user_id":"1079149c-adde-4b8d-bcb2-271c5356b4f9","user_phone":""}}	2026-09-11 14:41:16.301384+00	
00000000-0000-0000-0000-000000000000	299c1cf2-ba50-4f39-8160-6dcd50e3d338	{"action":"login","actor_id":"a8f88c58-3aa0-4ed3-a501-844b1b08cd34","actor_username":"al1ui-adm-1789137675@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 14:41:16.845973+00	
00000000-0000-0000-0000-000000000000	88c62da2-cb47-42d8-aa1a-fea2ba43eee3	{"action":"login","actor_id":"1079149c-adde-4b8d-bcb2-271c5356b4f9","actor_username":"al1ui-op-1789137675@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 14:41:17.117515+00	
00000000-0000-0000-0000-000000000000	978e4601-9c02-47ac-ad3d-de1d29c5f41e	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al1ui-adm-1789137675@example.com","user_id":"a8f88c58-3aa0-4ed3-a501-844b1b08cd34","user_phone":""}}	2026-09-11 14:41:20.688183+00	
00000000-0000-0000-0000-000000000000	be5716ba-ad44-4e19-bca5-70df7c16d185	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al1ui-op-1789137675@example.com","user_id":"1079149c-adde-4b8d-bcb2-271c5356b4f9","user_phone":""}}	2026-09-11 14:41:20.814357+00	
00000000-0000-0000-0000-000000000000	c2fdcfff-2770-4a3c-ac36-92f92884851f	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al1dbg@example.com","user_id":"b59ba97d-ed59-40f0-9b80-280889c75e93","user_phone":""}}	2026-09-11 14:44:21.656826+00	
00000000-0000-0000-0000-000000000000	b269e3ba-fa77-4699-9e63-53fda61b45a3	{"action":"login","actor_id":"b59ba97d-ed59-40f0-9b80-280889c75e93","actor_username":"al1dbg@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 14:44:22.025754+00	
00000000-0000-0000-0000-000000000000	218cc047-8557-4e1d-94fa-d601c3210d9b	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al1dbg@example.com","user_id":"b59ba97d-ed59-40f0-9b80-280889c75e93","user_phone":""}}	2026-09-11 14:47:03.728297+00	
00000000-0000-0000-0000-000000000000	0d64f6a3-6ec4-45e8-8aac-fcb68947c718	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al1ui-adm-1789138023@example.com","user_id":"a4aa0bf8-72f9-4e23-9f4e-70fd416d5c29","user_phone":""}}	2026-09-11 14:47:04.210212+00	
00000000-0000-0000-0000-000000000000	7a1d3997-6e13-4921-817e-49df95093da0	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al1ui-op-1789138023@example.com","user_id":"581ee83d-1178-4b95-a949-f5298d181c5f","user_phone":""}}	2026-09-11 14:47:04.433523+00	
00000000-0000-0000-0000-000000000000	13307bd1-740a-45fb-b10f-e373d8cd8581	{"action":"login","actor_id":"a4aa0bf8-72f9-4e23-9f4e-70fd416d5c29","actor_username":"al1ui-adm-1789138023@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 14:47:04.921477+00	
00000000-0000-0000-0000-000000000000	c5d3b5bc-e4e9-4c78-8900-0f7bda238f02	{"action":"login","actor_id":"581ee83d-1178-4b95-a949-f5298d181c5f","actor_username":"al1ui-op-1789138023@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 14:47:05.193402+00	
00000000-0000-0000-0000-000000000000	d89faeb9-99c4-4d8c-955f-907944269724	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al1ui-op-1789138023@example.com","user_id":"581ee83d-1178-4b95-a949-f5298d181c5f","user_phone":""}}	2026-09-11 14:47:08.754895+00	
00000000-0000-0000-0000-000000000000	35df2f7b-c8da-4e2a-8832-e5d240925bdf	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al1ui-adm-1789138023@example.com","user_id":"a4aa0bf8-72f9-4e23-9f4e-70fd416d5c29","user_phone":""}}	2026-09-11 14:47:08.883197+00	
00000000-0000-0000-0000-000000000000	16accc94-a9d5-4ce2-8697-4f205b84f028	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al2-op-1789139400@example.com","user_id":"5e860f53-99c9-4a18-a678-f6a97e6212af","user_phone":""}}	2026-09-11 15:10:00.471709+00	
00000000-0000-0000-0000-000000000000	c1b762c1-70f1-4b8c-a09d-93c3eb2c571c	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al2-sup-1789139400@example.com","user_id":"0020af9d-2c54-49fb-826c-d2496e091c09","user_phone":""}}	2026-09-11 15:10:00.722726+00	
00000000-0000-0000-0000-000000000000	a1444fb5-0c07-4c00-8f1e-30896dc3c205	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al2-adm-1789139400@example.com","user_id":"05738041-6acb-46e9-8ce8-a0bd99b362ac","user_phone":""}}	2026-09-11 15:10:00.949765+00	
00000000-0000-0000-0000-000000000000	2584c355-70fd-461e-9e50-6b1cad4cd184	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al2-op-1789139400@example.com","user_id":"5e860f53-99c9-4a18-a678-f6a97e6212af","user_phone":""}}	2026-09-11 15:10:04.721733+00	
00000000-0000-0000-0000-000000000000	9dd3f4e4-ec86-4f2f-ae49-3c2d1f7ef0ed	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al2-sup-1789139400@example.com","user_id":"0020af9d-2c54-49fb-826c-d2496e091c09","user_phone":""}}	2026-09-11 15:10:04.844036+00	
00000000-0000-0000-0000-000000000000	6f7091b8-4f2c-40cd-b864-562b130fe76e	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al2-adm-1789139400@example.com","user_id":"05738041-6acb-46e9-8ce8-a0bd99b362ac","user_phone":""}}	2026-09-11 15:10:04.968693+00	
00000000-0000-0000-0000-000000000000	a7234ea3-c28c-4109-804b-eb0cbbaebc43	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al2ui-adm-1789139615@example.com","user_id":"79b2555e-0b64-411b-b666-68a43c5c46e0","user_phone":""}}	2026-09-11 15:13:35.551266+00	
00000000-0000-0000-0000-000000000000	03c9551f-d0cf-4090-8d2e-e0285a2bd83a	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al2ui-op-1789139615@example.com","user_id":"3a503000-9e99-4dc6-9423-31b5979dd08b","user_phone":""}}	2026-09-11 15:13:35.788384+00	
00000000-0000-0000-0000-000000000000	e1f134d0-2c3f-4a92-b21b-9b4120ef28a7	{"action":"login","actor_id":"79b2555e-0b64-411b-b666-68a43c5c46e0","actor_username":"al2ui-adm-1789139615@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 15:13:36.337217+00	
00000000-0000-0000-0000-000000000000	a49e6c6d-d73f-4dae-a9b1-77145cc802e5	{"action":"login","actor_id":"3a503000-9e99-4dc6-9423-31b5979dd08b","actor_username":"al2ui-op-1789139615@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 15:13:36.587067+00	
00000000-0000-0000-0000-000000000000	88ca402a-9ba1-4b61-8a71-b02f2c78cdc5	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al2ui-op-1789139615@example.com","user_id":"3a503000-9e99-4dc6-9423-31b5979dd08b","user_phone":""}}	2026-09-11 15:13:40.663401+00	
00000000-0000-0000-0000-000000000000	ef9f273f-8bde-4746-b713-10628a30d422	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al2ui-adm-1789139615@example.com","user_id":"79b2555e-0b64-411b-b666-68a43c5c46e0","user_phone":""}}	2026-09-11 15:13:40.789299+00	
00000000-0000-0000-0000-000000000000	34581610-d95f-40ce-8acc-44540235b4e8	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al2ui-adm-1789139663@example.com","user_id":"5700363e-1996-4062-9930-dbc2a551add4","user_phone":""}}	2026-09-11 15:14:23.75759+00	
00000000-0000-0000-0000-000000000000	7a52ae3f-3a90-43f7-bd00-b74a212397fd	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al2ui-op-1789139663@example.com","user_id":"4697585b-fc18-4f1d-9bc4-247cbe3f5b73","user_phone":""}}	2026-09-11 15:14:23.965815+00	
00000000-0000-0000-0000-000000000000	6f364e11-9045-4265-80ef-d616a2af20a7	{"action":"login","actor_id":"5700363e-1996-4062-9930-dbc2a551add4","actor_username":"al2ui-adm-1789139663@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 15:14:24.506696+00	
00000000-0000-0000-0000-000000000000	e048176c-b3e3-4beb-a23c-82c3db32a4ff	{"action":"login","actor_id":"4697585b-fc18-4f1d-9bc4-247cbe3f5b73","actor_username":"al2ui-op-1789139663@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 15:14:24.772105+00	
00000000-0000-0000-0000-000000000000	ea3c4ed5-adca-4855-8cf7-f26251c0183e	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al2ui-adm-1789139663@example.com","user_id":"5700363e-1996-4062-9930-dbc2a551add4","user_phone":""}}	2026-09-11 15:14:28.342587+00	
00000000-0000-0000-0000-000000000000	7271a5d3-b01d-4ce1-9ca7-22b0afff8523	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al2ui-op-1789139663@example.com","user_id":"4697585b-fc18-4f1d-9bc4-247cbe3f5b73","user_phone":""}}	2026-09-11 15:14:28.464514+00	
00000000-0000-0000-0000-000000000000	56c41b50-d7d2-46bb-8f67-3bc89321e734	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al3-op-1789141085@example.com","user_id":"d59192ce-07f3-47e2-9cdb-e2b96b194f4b","user_phone":""}}	2026-09-11 15:38:06.029088+00	
00000000-0000-0000-0000-000000000000	bf6d3fce-fb1f-46bf-9f45-1dd594f91e13	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al3-sup-1789141085@example.com","user_id":"90719e91-f350-4d4d-abf8-f8d3379f972c","user_phone":""}}	2026-09-11 15:38:06.1596+00	
00000000-0000-0000-0000-000000000000	eabc8eb5-7bf6-47cc-b27a-fe9214392650	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al3-adm-1789141085@example.com","user_id":"194978e3-c853-4609-8d84-ab140fc1f5c4","user_phone":""}}	2026-09-11 15:38:06.265106+00	
00000000-0000-0000-0000-000000000000	8fb9fa69-f798-4b47-ab24-ed617d26d810	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al3-adm-1789141085@example.com","user_id":"194978e3-c853-4609-8d84-ab140fc1f5c4","user_phone":""}}	2026-09-11 15:38:08.845562+00	
00000000-0000-0000-0000-000000000000	8e066ea8-d17d-4445-8adf-7baf4f156f0f	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al3-op-1789141085@example.com","user_id":"d59192ce-07f3-47e2-9cdb-e2b96b194f4b","user_phone":""}}	2026-09-11 15:38:08.925734+00	
00000000-0000-0000-0000-000000000000	14097d05-e513-4a9a-87ee-2f5d8668e84d	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al3-sup-1789141085@example.com","user_id":"90719e91-f350-4d4d-abf8-f8d3379f972c","user_phone":""}}	2026-09-11 15:38:09.001557+00	
00000000-0000-0000-0000-000000000000	44e79381-6347-4483-be83-d29cd9f1ed2f	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al3ui-adm-1789141290@example.com","user_id":"7a318f2e-6ec4-48d9-a09f-9cf0e4aefb80","user_phone":""}}	2026-09-11 15:41:30.835803+00	
00000000-0000-0000-0000-000000000000	ca2abd5f-7b73-48e5-8355-b37e2ccdf28e	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al3ui-op-1789141290@example.com","user_id":"137dc590-a60e-435e-a4b2-0c64a6d8eb41","user_phone":""}}	2026-09-11 15:41:30.941078+00	
00000000-0000-0000-0000-000000000000	40023e5c-8573-46a0-96bd-f9049908e267	{"action":"login","actor_id":"7a318f2e-6ec4-48d9-a09f-9cf0e4aefb80","actor_username":"al3ui-adm-1789141290@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 15:41:31.222896+00	
00000000-0000-0000-0000-000000000000	48c905ec-f2c8-495c-b03f-ca9d14b3d731	{"action":"login","actor_id":"137dc590-a60e-435e-a4b2-0c64a6d8eb41","actor_username":"al3ui-op-1789141290@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 15:41:31.35844+00	
00000000-0000-0000-0000-000000000000	a03ce6dd-ddea-41d5-b370-2f58eeb02774	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al3ui-adm-1789141290@example.com","user_id":"7a318f2e-6ec4-48d9-a09f-9cf0e4aefb80","user_phone":""}}	2026-09-11 15:41:33.65894+00	
00000000-0000-0000-0000-000000000000	a509c5c0-82b2-41a8-be72-5992cb41e30f	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al3ui-op-1789141290@example.com","user_id":"137dc590-a60e-435e-a4b2-0c64a6d8eb41","user_phone":""}}	2026-09-11 15:41:33.716548+00	
00000000-0000-0000-0000-000000000000	71b62e36-8201-4306-b9c1-471b4361ec57	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al4-op-1789142927@example.com","user_id":"0843b35e-2ec6-4776-9b12-3c00b6577f3a","user_phone":""}}	2026-09-11 16:08:47.886632+00	
00000000-0000-0000-0000-000000000000	2e475212-0dcf-4c24-b969-d61ebec1e3b9	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al4-sup-1789142927@example.com","user_id":"08564a38-929a-44b0-b05e-eae4ff556fe3","user_phone":""}}	2026-09-11 16:08:47.988274+00	
00000000-0000-0000-0000-000000000000	b7f9bae2-90c3-4648-8867-b5505343485e	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al4-adm-1789142927@example.com","user_id":"3e13cfdf-bec8-4ce2-8e93-d8f510575fb0","user_phone":""}}	2026-09-11 16:08:48.121386+00	
00000000-0000-0000-0000-000000000000	d49bda55-fc66-4b47-8260-30841aa4bd03	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al4-adm-1789142927@example.com","user_id":"3e13cfdf-bec8-4ce2-8e93-d8f510575fb0","user_phone":""}}	2026-09-11 16:08:50.137786+00	
00000000-0000-0000-0000-000000000000	816f0072-d06b-41bf-9cc3-484001eb3b77	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al4-op-1789142927@example.com","user_id":"0843b35e-2ec6-4776-9b12-3c00b6577f3a","user_phone":""}}	2026-09-11 16:08:50.201665+00	
00000000-0000-0000-0000-000000000000	c904429e-5484-4f3b-a1eb-4400da9a0b5e	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al4-sup-1789142927@example.com","user_id":"08564a38-929a-44b0-b05e-eae4ff556fe3","user_phone":""}}	2026-09-11 16:08:50.24932+00	
00000000-0000-0000-0000-000000000000	6beb0050-7e84-4bdd-ad22-fc2449da40db	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al4ui-adm-1789143157@example.com","user_id":"338155cf-04e1-47c0-8702-3dd9f66f7b6c","user_phone":""}}	2026-09-11 16:12:37.979743+00	
00000000-0000-0000-0000-000000000000	a80e9ab1-9be8-4077-8ced-13dca1de97ca	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al4ui-op-1789143157@example.com","user_id":"8cf98013-4a26-45cf-abb6-646a8efa36b8","user_phone":""}}	2026-09-11 16:12:38.101794+00	
00000000-0000-0000-0000-000000000000	d2c7dc4c-13bf-4921-a612-38b47f521b38	{"action":"login","actor_id":"338155cf-04e1-47c0-8702-3dd9f66f7b6c","actor_username":"al4ui-adm-1789143157@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 16:12:38.358775+00	
00000000-0000-0000-0000-000000000000	72bc298f-e4a8-4dd4-b56c-ad8e12130bf4	{"action":"login","actor_id":"8cf98013-4a26-45cf-abb6-646a8efa36b8","actor_username":"al4ui-op-1789143157@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 16:12:38.482184+00	
00000000-0000-0000-0000-000000000000	db1eb3ae-4f21-4435-81fc-d41c31d470d8	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al4ui-adm-1789143157@example.com","user_id":"338155cf-04e1-47c0-8702-3dd9f66f7b6c","user_phone":""}}	2026-09-11 16:12:40.804681+00	
00000000-0000-0000-0000-000000000000	a15a6110-b1bc-4346-9b10-418ceb66bcde	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al4ui-op-1789143157@example.com","user_id":"8cf98013-4a26-45cf-abb6-646a8efa36b8","user_phone":""}}	2026-09-11 16:12:40.85783+00	
00000000-0000-0000-0000-000000000000	a4b8df24-3499-40bc-b6b6-31551d7aac59	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al5-op-1789144719@example.com","user_id":"2fbe9fef-60f4-4296-8f27-8b297c9fc433","user_phone":""}}	2026-09-11 16:38:39.622019+00	
00000000-0000-0000-0000-000000000000	a68a374e-74aa-4a86-823c-080de8c609d2	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al5-sup-1789144719@example.com","user_id":"b32f7076-eebb-43cd-a686-3e0540f8ea6c","user_phone":""}}	2026-09-11 16:38:39.742884+00	
00000000-0000-0000-0000-000000000000	594ee938-46aa-4e26-8326-ad2d02bef3e2	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al5-adm-1789144719@example.com","user_id":"ca6a773d-2758-440a-a361-6344b4c94c40","user_phone":""}}	2026-09-11 16:38:39.860424+00	
00000000-0000-0000-0000-000000000000	a132c017-6930-4eb6-bdff-4f5d1a43dfb7	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al5-op-1789144719@example.com","user_id":"2fbe9fef-60f4-4296-8f27-8b297c9fc433","user_phone":""}}	2026-09-11 16:38:42.448652+00	
00000000-0000-0000-0000-000000000000	ed39f850-5452-4035-b4ca-f6e1787cfd2a	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al5-sup-1789144719@example.com","user_id":"b32f7076-eebb-43cd-a686-3e0540f8ea6c","user_phone":""}}	2026-09-11 16:38:42.522932+00	
00000000-0000-0000-0000-000000000000	0e10409e-3d80-4d2e-8163-bdabd2ab8c79	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al5-adm-1789144719@example.com","user_id":"ca6a773d-2758-440a-a361-6344b4c94c40","user_phone":""}}	2026-09-11 16:38:42.586644+00	
00000000-0000-0000-0000-000000000000	ee13aa6d-2961-43d4-8eff-d1f0fd21f15f	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al5-op-1789144853@example.com","user_id":"2fd8fcd5-7317-4071-a83d-a45666ba0708","user_phone":""}}	2026-09-11 16:40:53.992823+00	
00000000-0000-0000-0000-000000000000	fad64fbe-5039-46ba-8f27-876f3fcf443a	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al5-sup-1789144853@example.com","user_id":"cf1c0c91-ee53-4695-b0d4-71834da851e4","user_phone":""}}	2026-09-11 16:40:54.110032+00	
00000000-0000-0000-0000-000000000000	8a2175a1-6c10-4262-8631-b2196f418f04	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al5-adm-1789144853@example.com","user_id":"a9f0db77-9dc4-4ee4-86f7-787f32c6a27b","user_phone":""}}	2026-09-11 16:40:54.274471+00	
00000000-0000-0000-0000-000000000000	b57e3abb-ff37-4a74-b832-348820fe04ab	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al5-op-1789144853@example.com","user_id":"2fd8fcd5-7317-4071-a83d-a45666ba0708","user_phone":""}}	2026-09-11 16:40:57.201546+00	
00000000-0000-0000-0000-000000000000	e99cd1d4-bb53-4605-be3d-a14ac195f1f2	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al5-sup-1789144853@example.com","user_id":"cf1c0c91-ee53-4695-b0d4-71834da851e4","user_phone":""}}	2026-09-11 16:40:57.274647+00	
00000000-0000-0000-0000-000000000000	6067f54f-894d-4d0c-9295-7354b7196bf7	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al5-adm-1789144853@example.com","user_id":"a9f0db77-9dc4-4ee4-86f7-787f32c6a27b","user_phone":""}}	2026-09-11 16:40:57.349244+00	
00000000-0000-0000-0000-000000000000	54c121ba-b901-4745-ab87-a50f0f9566aa	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al5-op-1789145037@example.com","user_id":"64050f52-d834-4819-a78b-49cb42a5ec96","user_phone":""}}	2026-09-11 16:43:57.310948+00	
00000000-0000-0000-0000-000000000000	efdc151e-93f5-4784-bae0-8934f728c105	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al5-sup-1789145037@example.com","user_id":"059b4fa2-4c71-4e2a-8dc1-87c0b05917ad","user_phone":""}}	2026-09-11 16:43:57.426867+00	
00000000-0000-0000-0000-000000000000	357fa9f9-a9f4-41d1-a039-7b7e867a1a74	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al5-adm-1789145037@example.com","user_id":"c409fb81-9ec0-4be5-9e82-3c0dff28ca34","user_phone":""}}	2026-09-11 16:43:57.531274+00	
00000000-0000-0000-0000-000000000000	8c3eb7b2-e606-46cd-a437-060e61cb3891	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al5-op-1789145037@example.com","user_id":"64050f52-d834-4819-a78b-49cb42a5ec96","user_phone":""}}	2026-09-11 16:44:00.438542+00	
00000000-0000-0000-0000-000000000000	dde83416-37c7-4679-b57c-06c085e2948d	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al5-sup-1789145037@example.com","user_id":"059b4fa2-4c71-4e2a-8dc1-87c0b05917ad","user_phone":""}}	2026-09-11 16:44:00.506605+00	
00000000-0000-0000-0000-000000000000	8f668818-f2bd-4a4f-8374-74c30f85076b	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al5-adm-1789145037@example.com","user_id":"c409fb81-9ec0-4be5-9e82-3c0dff28ca34","user_phone":""}}	2026-09-11 16:44:00.580867+00	
00000000-0000-0000-0000-000000000000	acf6ec18-3ab5-4699-8cfa-ad1e2c296ee4	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al5ui-adm-1789145271@example.com","user_id":"7a9f278e-f7df-456b-8c3b-a6f0ac5b4252","user_phone":""}}	2026-09-11 16:47:51.933118+00	
00000000-0000-0000-0000-000000000000	b15f756a-4a1f-4570-98a6-80dd945fbf3b	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al5ui-op-1789145271@example.com","user_id":"6c2675bd-627f-42ee-99e6-8853f05a57bb","user_phone":""}}	2026-09-11 16:47:52.037391+00	
00000000-0000-0000-0000-000000000000	c86005a4-1ca0-49ea-942c-c2cb3576c009	{"action":"login","actor_id":"7a9f278e-f7df-456b-8c3b-a6f0ac5b4252","actor_username":"al5ui-adm-1789145271@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 16:47:52.349235+00	
00000000-0000-0000-0000-000000000000	ddc1ec34-8b25-49e1-a207-e23015db8dc1	{"action":"login","actor_id":"6c2675bd-627f-42ee-99e6-8853f05a57bb","actor_username":"al5ui-op-1789145271@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 16:47:52.482572+00	
00000000-0000-0000-0000-000000000000	9a28e4df-07fc-40a2-ad48-d96563ac77b2	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al5ui-adm-1789145271@example.com","user_id":"7a9f278e-f7df-456b-8c3b-a6f0ac5b4252","user_phone":""}}	2026-09-11 16:47:55.7215+00	
00000000-0000-0000-0000-000000000000	9a0a8e54-5916-46d2-9aff-960e8e5670f7	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al5ui-op-1789145271@example.com","user_id":"6c2675bd-627f-42ee-99e6-8853f05a57bb","user_phone":""}}	2026-09-11 16:47:55.791809+00	
00000000-0000-0000-0000-000000000000	932251be-c22a-4328-b5ee-039a78c0454e	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"probe-1789145528@example.com","user_id":"11d61d6b-2bf8-45b9-b2cd-3b9e15e0b285","user_phone":""}}	2026-09-11 16:52:09.069738+00	
00000000-0000-0000-0000-000000000000	4cd69d04-0651-47d7-8b3f-4b5fcde83cc6	{"action":"login","actor_id":"11d61d6b-2bf8-45b9-b2cd-3b9e15e0b285","actor_username":"probe-1789145528@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 16:52:09.324453+00	
00000000-0000-0000-0000-000000000000	e3f024f8-b5f4-4491-90cf-4828da5da3bf	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"probe-1789145528@example.com","user_id":"11d61d6b-2bf8-45b9-b2cd-3b9e15e0b285","user_phone":""}}	2026-09-11 17:00:10.712648+00	
00000000-0000-0000-0000-000000000000	8e4b3503-5103-482d-9ffe-ee5798a87515	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al5ui-adm-1789146523@example.com","user_id":"df88a971-4d00-4f1a-a042-c54afed807e8","user_phone":""}}	2026-09-11 17:08:43.742344+00	
00000000-0000-0000-0000-000000000000	1fcb6b3d-3ec3-4544-b84d-9f2f9130ea81	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"al5ui-op-1789146523@example.com","user_id":"ab257b29-8d1e-4a1e-81dd-59e8c1715e0c","user_phone":""}}	2026-09-11 17:08:43.855416+00	
00000000-0000-0000-0000-000000000000	f4c7588f-8ee4-43e4-beab-f38e8d016135	{"action":"login","actor_id":"df88a971-4d00-4f1a-a042-c54afed807e8","actor_username":"al5ui-adm-1789146523@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 17:08:44.158553+00	
00000000-0000-0000-0000-000000000000	9c498c07-4ddc-4b27-b48b-344387c8ad6c	{"action":"login","actor_id":"ab257b29-8d1e-4a1e-81dd-59e8c1715e0c","actor_username":"al5ui-op-1789146523@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 17:08:44.337454+00	
00000000-0000-0000-0000-000000000000	0307ec98-b79a-4804-a2be-35bfd78c71dc	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al5ui-adm-1789146523@example.com","user_id":"df88a971-4d00-4f1a-a042-c54afed807e8","user_phone":""}}	2026-09-11 17:08:47.267648+00	
00000000-0000-0000-0000-000000000000	c2649ef3-c958-4b28-a7a7-905ad19f9b9f	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"al5ui-op-1789146523@example.com","user_id":"ab257b29-8d1e-4a1e-81dd-59e8c1715e0c","user_phone":""}}	2026-09-11 17:08:47.345359+00	
00000000-0000-0000-0000-000000000000	48b859f1-fb6e-4015-b253-17b41fe6667d	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"op-an1@example.com","user_id":"38c1d505-1346-411d-99e9-ceb82ecd95f4","user_phone":""}}	2026-09-11 21:58:10.526233+00	
00000000-0000-0000-0000-000000000000	0db9a51a-d1ce-446c-a069-d7c5fc72f549	{"action":"login","actor_id":"38c1d505-1346-411d-99e9-ceb82ecd95f4","actor_username":"op-an1@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 22:01:49.643446+00	
00000000-0000-0000-0000-000000000000	7faf73f1-9b67-432a-85fb-6a21c6f2c82b	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"op-an1@example.com","user_id":"38c1d505-1346-411d-99e9-ceb82ecd95f4","user_phone":""}}	2026-09-11 22:07:59.745871+00	
00000000-0000-0000-0000-000000000000	ad4e1f0b-c180-43fb-aa7c-1aaaf1ab9694	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ao2-smoke@example.com","user_id":"461e630d-bbc4-4617-96e5-f3b0d31a26dc","user_phone":""}}	2026-09-11 22:44:18.765162+00	
00000000-0000-0000-0000-000000000000	22db2ff6-26e7-4d4d-8b6e-6ef5ea11d2e3	{"action":"login","actor_id":"461e630d-bbc4-4617-96e5-f3b0d31a26dc","actor_username":"ao2-smoke@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 22:45:42.374186+00	
00000000-0000-0000-0000-000000000000	8e3d5e01-fd06-4234-86f6-3bc658156ef3	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ao2-smoke@example.com","user_id":"461e630d-bbc4-4617-96e5-f3b0d31a26dc","user_phone":""}}	2026-09-11 22:50:13.827366+00	
00000000-0000-0000-0000-000000000000	8fead771-ef28-4ebb-9283-76cac7b77f66	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ao3-smoke@example.com","user_id":"d65a62c1-3689-4984-94ad-1a84a476b282","user_phone":""}}	2026-09-11 23:10:10.681269+00	
00000000-0000-0000-0000-000000000000	03e24bb1-b07e-40f6-8350-e4a8279e6ac1	{"action":"login","actor_id":"d65a62c1-3689-4984-94ad-1a84a476b282","actor_username":"ao3-smoke@example.com","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-11 23:10:33.265871+00	
00000000-0000-0000-0000-000000000000	fbb8a91d-5e7f-4e46-9d54-53f8000de0e9	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ao3-smoke@example.com","user_id":"d65a62c1-3689-4984-94ad-1a84a476b282","user_phone":""}}	2026-09-11 23:13:09.07513+00	
00000000-0000-0000-0000-000000000000	361a9f49-7a91-4f03-93cc-8e5be09f7edb	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"ap2smoke@test.local","user_id":"7afe1e95-1314-4682-b3bb-003bd1632ff6","user_phone":""}}	2026-09-12 00:43:10.631849+00	
00000000-0000-0000-0000-000000000000	e8008df7-1072-4daa-9455-0c1649def71b	{"action":"login","actor_id":"7afe1e95-1314-4682-b3bb-003bd1632ff6","actor_username":"ap2smoke@test.local","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-12 00:46:12.530022+00	
00000000-0000-0000-0000-000000000000	59161e0e-3275-42c6-b6b6-90504e92fe43	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"ap2smoke@test.local","user_id":"7afe1e95-1314-4682-b3bb-003bd1632ff6","user_phone":""}}	2026-09-12 00:50:48.13756+00	
00000000-0000-0000-0000-000000000000	7306096a-3b43-4861-a2a8-d3b41cc637e1	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"aqsmoke@test.local","user_id":"87756a31-5f6b-4871-83e9-1dc7aee91732","user_phone":""}}	2026-09-12 01:02:17.054283+00	
00000000-0000-0000-0000-000000000000	c4fc285b-334c-45b9-ad5f-03bca72525ad	{"action":"login","actor_id":"87756a31-5f6b-4871-83e9-1dc7aee91732","actor_username":"aqsmoke@test.local","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-12 01:03:57.90902+00	
00000000-0000-0000-0000-000000000000	589dda5b-857e-4f2e-ad5c-32674b778b7a	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"aqsmoke@test.local","user_id":"87756a31-5f6b-4871-83e9-1dc7aee91732","user_phone":""}}	2026-09-12 01:13:15.97744+00	
00000000-0000-0000-0000-000000000000	9dc1693b-3741-4c94-8cc1-d61e6530340a	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"arsmoke@test.local","user_id":"fe4f8f79-3103-4e71-b39a-ca10aa2784fd","user_phone":""}}	2026-09-12 01:26:00.187061+00	
00000000-0000-0000-0000-000000000000	6978c612-3df1-46e8-b1c3-cfd9e698a174	{"action":"login","actor_id":"fe4f8f79-3103-4e71-b39a-ca10aa2784fd","actor_username":"arsmoke@test.local","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-12 01:27:54.678481+00	
00000000-0000-0000-0000-000000000000	ecc5f897-5234-47a7-895e-dbe8ed97fcd3	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"arsmoke@test.local","user_id":"fe4f8f79-3103-4e71-b39a-ca10aa2784fd","user_phone":""}}	2026-09-12 01:29:02.977116+00	
00000000-0000-0000-0000-000000000000	4ff4fd66-1135-432e-8866-a936c9a32e6d	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"atoperator@test.local","user_id":"f3c7b6c9-8cb3-4826-ada3-1ac649f1fcf5","user_phone":""}}	2026-09-12 02:04:22.072391+00	
00000000-0000-0000-0000-000000000000	047be152-f66a-4220-b150-35160e131a91	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"attsupervisor@test.local","user_id":"236c9ba5-7c00-4339-b308-4b15744dd79b","user_phone":""}}	2026-09-12 02:04:22.169267+00	
00000000-0000-0000-0000-000000000000	d82b385d-987c-446e-bd6c-e7f726fa7003	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"attadmin@test.local","user_id":"5c76efb4-cd1b-467c-bfe5-ea3f0054aa92","user_phone":""}}	2026-09-12 02:04:22.267303+00	
00000000-0000-0000-0000-000000000000	6b266166-4d17-4103-befa-e8df4b02c596	{"action":"login","actor_id":"f3c7b6c9-8cb3-4826-ada3-1ac649f1fcf5","actor_username":"atoperator@test.local","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-12 02:05:12.341209+00	
00000000-0000-0000-0000-000000000000	492bfc08-5ce2-4449-8aee-69f8c3ea7dc4	{"action":"login","actor_id":"236c9ba5-7c00-4339-b308-4b15744dd79b","actor_username":"attsupervisor@test.local","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-12 02:05:12.479067+00	
00000000-0000-0000-0000-000000000000	575fbb35-2f60-4cc7-9a24-f2497e7523e3	{"action":"login","actor_id":"5c76efb4-cd1b-467c-bfe5-ea3f0054aa92","actor_username":"attadmin@test.local","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-12 02:05:12.621113+00	
00000000-0000-0000-0000-000000000000	fe9902c8-f922-4d01-9ae8-15fbe48a7a3d	{"action":"login","actor_id":"f3c7b6c9-8cb3-4826-ada3-1ac649f1fcf5","actor_username":"atoperator@test.local","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-12 02:23:26.432861+00	
00000000-0000-0000-0000-000000000000	187a7261-f009-4df0-9880-285486a19015	{"action":"login","actor_id":"236c9ba5-7c00-4339-b308-4b15744dd79b","actor_username":"attsupervisor@test.local","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-12 02:23:26.571458+00	
00000000-0000-0000-0000-000000000000	f240a189-43ad-49de-bbbe-c3d352014b57	{"action":"login","actor_id":"5c76efb4-cd1b-467c-bfe5-ea3f0054aa92","actor_username":"attadmin@test.local","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-12 02:23:26.7121+00	
00000000-0000-0000-0000-000000000000	eab77f39-c532-4446-9fe7-0b216a62646a	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"atoperator@test.local","user_id":"f3c7b6c9-8cb3-4826-ada3-1ac649f1fcf5","user_phone":""}}	2026-09-12 02:25:47.53104+00	
00000000-0000-0000-0000-000000000000	5971e553-1a1f-4195-965c-0b9f27b42106	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"attsupervisor@test.local","user_id":"236c9ba5-7c00-4339-b308-4b15744dd79b","user_phone":""}}	2026-09-12 02:25:50.677415+00	
00000000-0000-0000-0000-000000000000	f17ce440-fca3-4062-8285-9dccdeb34782	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"attadmin@test.local","user_id":"5c76efb4-cd1b-467c-bfe5-ea3f0054aa92","user_phone":""}}	2026-09-12 02:25:53.794219+00	
00000000-0000-0000-0000-000000000000	b4944053-078b-403a-ba4b-ea5d625455d7	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"auoperator@test.local","user_id":"5bea87b9-ac8a-43e4-9514-ab8dfc8e96c9","user_phone":""}}	2026-09-12 02:37:29.651091+00	
00000000-0000-0000-0000-000000000000	e6e263ba-3a38-4156-9a94-4161270d4201	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"auserver@test.local","user_id":"a04fe8d2-7b74-49c8-8d82-ad9674fc60b8","user_phone":""}}	2026-09-12 02:37:29.748563+00	
00000000-0000-0000-0000-000000000000	7243ca11-9d1b-45a6-b4cc-e4d41718c0d0	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"auadmin@test.local","user_id":"ec68e644-2e8c-45a6-9871-119d87d2d737","user_phone":""}}	2026-09-12 02:37:29.862018+00	
00000000-0000-0000-0000-000000000000	e496e26d-08e7-4712-b2c9-4970579ce642	{"action":"login","actor_id":"5bea87b9-ac8a-43e4-9514-ab8dfc8e96c9","actor_username":"auoperator@test.local","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-12 02:40:08.282962+00	
00000000-0000-0000-0000-000000000000	7a41383a-10b9-4176-ad05-621dc185d80b	{"action":"login","actor_id":"a04fe8d2-7b74-49c8-8d82-ad9674fc60b8","actor_username":"auserver@test.local","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-12 02:40:08.413143+00	
00000000-0000-0000-0000-000000000000	583ab5ad-8bf7-478d-b072-b9ea5defa07d	{"action":"login","actor_id":"ec68e644-2e8c-45a6-9871-119d87d2d737","actor_username":"auadmin@test.local","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-12 02:40:08.575614+00	
00000000-0000-0000-0000-000000000000	8caa96bf-08e1-4e40-8d2a-05ee205ba72f	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"auadmin@test.local","user_id":"ec68e644-2e8c-45a6-9871-119d87d2d737","user_phone":""}}	2026-09-12 03:08:09.871702+00	
00000000-0000-0000-0000-000000000000	71a62da5-795a-4762-84b7-66b6e96f70a7	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"auoperator@test.local","user_id":"5bea87b9-ac8a-43e4-9514-ab8dfc8e96c9","user_phone":""}}	2026-09-12 03:09:04.488112+00	
00000000-0000-0000-0000-000000000000	c5ede77f-856f-4215-8bc3-37a2e120773d	{"action":"user_deleted","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"user_email":"auserver@test.local","user_id":"a04fe8d2-7b74-49c8-8d82-ad9674fc60b8","user_phone":""}}	2026-09-12 03:09:04.558243+00	
00000000-0000-0000-0000-000000000000	c3bae126-1f9b-4870-8161-02c084781e38	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"admin@test.local","user_id":"8a271366-4b41-4d2f-813c-4d553c83b968","user_phone":""}}	2026-09-13 15:07:23.727618+00	
00000000-0000-0000-0000-000000000000	ba9184d5-ba3d-4fa3-a19e-121b944009a4	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"supervisor@test.local","user_id":"be18bd95-e3e4-488d-ab33-820ef8ad86d0","user_phone":""}}	2026-09-13 15:07:23.949277+00	
00000000-0000-0000-0000-000000000000	9774090f-b8b5-4e9e-b69a-4654ac2b1ad0	{"action":"user_signedup","actor_id":"00000000-0000-0000-0000-000000000000","actor_username":"service_role","actor_via_sso":false,"log_type":"team","traits":{"provider":"email","user_email":"operator@test.local","user_id":"9ba5032b-93bb-40fa-b665-a45a8c11aff1","user_phone":""}}	2026-09-13 15:07:24.178752+00	
00000000-0000-0000-0000-000000000000	153e2bc0-204e-4603-8796-f28c67b9c0db	{"action":"login","actor_id":"8a271366-4b41-4d2f-813c-4d553c83b968","actor_username":"admin@test.local","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-13 15:08:39.683368+00	
00000000-0000-0000-0000-000000000000	409d066e-8602-40c7-866c-53d122c2c542	{"action":"login","actor_id":"8a271366-4b41-4d2f-813c-4d553c83b968","actor_username":"admin@test.local","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-13 15:19:08.336+00	
00000000-0000-0000-0000-000000000000	742d2152-8b2f-44f3-bf8e-d5424d951fe0	{"action":"login","actor_id":"8a271366-4b41-4d2f-813c-4d553c83b968","actor_username":"admin@test.local","actor_via_sso":false,"log_type":"account","traits":{"provider":"email"}}	2026-09-13 15:25:32.146819+00	
00000000-0000-0000-0000-000000000000	76d765e1-2e5b-429a-829d-845e0811b76d	{"action":"token_refreshed","actor_id":"8a271366-4b41-4d2f-813c-4d553c83b968","actor_username":"admin@test.local","actor_via_sso":false,"log_type":"token"}	2026-09-13 17:41:21.826132+00	
00000000-0000-0000-0000-000000000000	3292f50e-9f75-4778-8fd7-542761a0018b	{"action":"token_revoked","actor_id":"8a271366-4b41-4d2f-813c-4d553c83b968","actor_username":"admin@test.local","actor_via_sso":false,"log_type":"token"}	2026-09-13 17:41:21.827697+00	
\.


--
-- Data for Name: custom_oauth_providers; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.custom_oauth_providers (id, provider_type, identifier, name, client_id, client_secret, acceptable_client_ids, scopes, pkce_enabled, attribute_mapping, authorization_params, enabled, email_optional, issuer, discovery_url, skip_nonce_check, cached_discovery, discovery_cached_at, authorization_url, token_url, userinfo_url, jwks_uri, created_at, updated_at, custom_claims_allowlist) FROM stdin;
\.


--
-- Data for Name: flow_state; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.flow_state (id, user_id, auth_code, code_challenge_method, code_challenge, provider_type, provider_access_token, provider_refresh_token, created_at, updated_at, authentication_method, auth_code_issued_at, invite_token, referrer, oauth_client_state_id, linking_target_id, email_optional) FROM stdin;
\.


--
-- Data for Name: identities; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at, id) FROM stdin;
8a271366-4b41-4d2f-813c-4d553c83b968	8a271366-4b41-4d2f-813c-4d553c83b968	{"sub": "8a271366-4b41-4d2f-813c-4d553c83b968", "email": "admin@test.local", "email_verified": false, "phone_verified": false}	email	2026-09-13 15:07:23.723668+00	2026-09-13 15:07:23.723745+00	2026-09-13 15:07:23.723745+00	c64d204c-0a10-4d4c-8792-011b93ce6367
be18bd95-e3e4-488d-ab33-820ef8ad86d0	be18bd95-e3e4-488d-ab33-820ef8ad86d0	{"sub": "be18bd95-e3e4-488d-ab33-820ef8ad86d0", "email": "supervisor@test.local", "email_verified": false, "phone_verified": false}	email	2026-09-13 15:07:23.945724+00	2026-09-13 15:07:23.945825+00	2026-09-13 15:07:23.945825+00	189d1866-b481-412f-8bf9-1880a120a455
9ba5032b-93bb-40fa-b665-a45a8c11aff1	9ba5032b-93bb-40fa-b665-a45a8c11aff1	{"sub": "9ba5032b-93bb-40fa-b665-a45a8c11aff1", "email": "operator@test.local", "email_verified": false, "phone_verified": false}	email	2026-09-13 15:07:24.175979+00	2026-09-13 15:07:24.176051+00	2026-09-13 15:07:24.176051+00	aaea1cb7-c47a-411b-93c1-4a6de46a8f9e
\.


--
-- Data for Name: instances; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.instances (id, uuid, raw_base_config, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: mfa_amr_claims; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.mfa_amr_claims (session_id, created_at, updated_at, authentication_method, id) FROM stdin;
adb5d566-706c-46b3-9dc6-cb549c8a427f	2026-09-13 15:08:39.706969+00	2026-09-13 15:08:39.706969+00	password	690d8b61-eabb-4f47-b2bf-bc219e4fbd9f
36131142-5ba4-44fd-a428-8d358caed62a	2026-09-13 15:19:08.347332+00	2026-09-13 15:19:08.347332+00	password	340d7b9d-4f4c-4948-8de2-e0b9b4b99b13
9d69aecf-58eb-43fc-82db-7999d1618502	2026-09-13 15:25:32.154465+00	2026-09-13 15:25:32.154465+00	password	c54a12cd-67ab-42e4-941e-b5ef8bfa6fbc
\.


--
-- Data for Name: mfa_challenges; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.mfa_challenges (id, factor_id, created_at, verified_at, ip_address, otp_code, web_authn_session_data) FROM stdin;
\.


--
-- Data for Name: mfa_factors; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at, secret, phone, last_challenged_at, web_authn_credential, web_authn_aaguid, last_webauthn_challenge_data) FROM stdin;
\.


--
-- Data for Name: oauth_authorizations; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_authorizations (id, authorization_id, client_id, user_id, redirect_uri, scope, state, resource, code_challenge, code_challenge_method, response_type, status, authorization_code, created_at, expires_at, approved_at, nonce) FROM stdin;
\.


--
-- Data for Name: oauth_client_states; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_client_states (id, provider_type, code_verifier, created_at) FROM stdin;
\.


--
-- Data for Name: oauth_clients; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_clients (id, client_secret_hash, registration_type, redirect_uris, grant_types, client_name, client_uri, logo_uri, created_at, updated_at, deleted_at, client_type, token_endpoint_auth_method) FROM stdin;
\.


--
-- Data for Name: oauth_consents; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_consents (id, user_id, client_id, scopes, granted_at, revoked_at) FROM stdin;
\.


--
-- Data for Name: one_time_tokens; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.one_time_tokens (id, user_id, token_type, token_hash, relates_to, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: refresh_tokens; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.refresh_tokens (instance_id, id, token, user_id, revoked, created_at, updated_at, parent, session_id) FROM stdin;
00000000-0000-0000-0000-000000000000	65	gnzafm76wpgh	8a271366-4b41-4d2f-813c-4d553c83b968	f	2026-09-13 15:08:39.699699+00	2026-09-13 15:08:39.699699+00	\N	adb5d566-706c-46b3-9dc6-cb549c8a427f
00000000-0000-0000-0000-000000000000	66	2jqh5ytkuum2	8a271366-4b41-4d2f-813c-4d553c83b968	f	2026-09-13 15:19:08.342827+00	2026-09-13 15:19:08.342827+00	\N	36131142-5ba4-44fd-a428-8d358caed62a
00000000-0000-0000-0000-000000000000	67	h6bzixlpckas	8a271366-4b41-4d2f-813c-4d553c83b968	t	2026-09-13 15:25:32.151646+00	2026-09-13 17:41:21.828631+00	\N	9d69aecf-58eb-43fc-82db-7999d1618502
00000000-0000-0000-0000-000000000000	68	7cs7mpl6aipk	8a271366-4b41-4d2f-813c-4d553c83b968	f	2026-09-13 17:41:21.836629+00	2026-09-13 17:41:21.836629+00	h6bzixlpckas	9d69aecf-58eb-43fc-82db-7999d1618502
\.


--
-- Data for Name: saml_providers; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.saml_providers (id, sso_provider_id, entity_id, metadata_xml, metadata_url, attribute_mapping, created_at, updated_at, name_id_format) FROM stdin;
\.


--
-- Data for Name: saml_relay_states; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.saml_relay_states (id, sso_provider_id, request_id, for_email, redirect_to, created_at, updated_at, flow_state_id) FROM stdin;
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.schema_migrations (version) FROM stdin;
20171026211738
20171026211808
20171026211834
20180103212743
20180108183307
20180119214651
20180125194653
00
20210710035447
20210722035447
20210730183235
20210909172000
20210927181326
20211122151130
20211124214934
20211202183645
20220114185221
20220114185340
20220224000811
20220323170000
20220429102000
20220531120530
20220614074223
20220811173540
20221003041349
20221003041400
20221011041400
20221020193600
20221021073300
20221021082433
20221027105023
20221114143122
20221114143410
20221125140132
20221208132122
20221215195500
20221215195800
20221215195900
20230116124310
20230116124412
20230131181311
20230322519590
20230402418590
20230411005111
20230508135423
20230523124323
20230818113222
20230914180801
20231027141322
20231114161723
20231117164230
20240115144230
20240214120130
20240306115329
20240314092811
20240427152123
20240612123726
20240729123726
20240802193726
20240806073726
20241009103726
20250717082212
20250731150234
20250804100000
20250901200500
20250903112500
20250904133000
20250925093508
20251007112900
20251104100000
20251111201300
20251201000000
20260115000000
20260121000000
20260219120000
20260302000000
20260625000000
\.


--
-- Data for Name: sessions; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.sessions (id, user_id, created_at, updated_at, factor_id, aal, not_after, refreshed_at, user_agent, ip, tag, oauth_client_id, refresh_token_hmac_key, refresh_token_counter, scopes) FROM stdin;
adb5d566-706c-46b3-9dc6-cb549c8a427f	8a271366-4b41-4d2f-813c-4d553c83b968	2026-09-13 15:08:39.685267+00	2026-09-13 15:08:39.685267+00	\N	aal1	\N	\N	curl/8.22.0	172.19.0.1	\N	\N	\N	\N	\N
36131142-5ba4-44fd-a428-8d358caed62a	8a271366-4b41-4d2f-813c-4d553c83b968	2026-09-13 15:19:08.33865+00	2026-09-13 15:19:08.33865+00	\N	aal1	\N	\N	node	172.19.0.1	\N	\N	\N	\N	\N
9d69aecf-58eb-43fc-82db-7999d1618502	8a271366-4b41-4d2f-813c-4d553c83b968	2026-09-13 15:25:32.148752+00	2026-09-13 17:41:21.842879+00	\N	aal1	\N	2026-09-13 17:41:21.842745	node	172.19.0.1	\N	\N	\N	\N	\N
\.


--
-- Data for Name: sso_domains; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.sso_domains (id, sso_provider_id, domain, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: sso_providers; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.sso_providers (id, resource_id, created_at, updated_at, disabled) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, invited_at, confirmation_token, confirmation_sent_at, recovery_token, recovery_sent_at, email_change_token_new, email_change, email_change_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at, phone, phone_confirmed_at, phone_change, phone_change_token, phone_change_sent_at, email_change_token_current, email_change_confirm_status, banned_until, reauthentication_token, reauthentication_sent_at, is_sso_user, deleted_at, is_anonymous) FROM stdin;
00000000-0000-0000-0000-000000000000	9ba5032b-93bb-40fa-b665-a45a8c11aff1	authenticated	authenticated	operator@test.local	$2a$10$BQKmoVKuITO37gINhMYmMef47Dgl5uxeditrapKag84pTlipiE7pG	2026-09-13 15:07:24.181505+00	\N		\N		\N			\N	\N	{"provider": "email", "providers": ["email"]}	{"email_verified": true}	\N	2026-09-13 15:07:24.172893+00	2026-09-13 15:07:24.18305+00	\N	\N			\N		0	\N		\N	f	\N	f
00000000-0000-0000-0000-000000000000	8a271366-4b41-4d2f-813c-4d553c83b968	authenticated	authenticated	admin@test.local	$2a$10$DDf45E5ifP0jcZAPsAy77e/F3jj4vHvDNlIcPvCdifPLrbJh1UjQ2	2026-09-13 15:07:23.733461+00	\N		\N		\N			\N	2026-09-13 15:25:32.148643+00	{"provider": "email", "providers": ["email"]}	{"email_verified": true}	\N	2026-09-13 15:07:23.719082+00	2026-09-13 17:41:21.839332+00	\N	\N			\N		0	\N		\N	f	\N	f
00000000-0000-0000-0000-000000000000	be18bd95-e3e4-488d-ab33-820ef8ad86d0	authenticated	authenticated	supervisor@test.local	$2a$10$cLDUNmQXDc6lFhDf9fv8TORuEFfyn/.f5wJZfKo45lPIJnBnroPAa	2026-09-13 15:07:23.952129+00	\N		\N		\N			\N	\N	{"provider": "email", "providers": ["email"]}	{"email_verified": true}	\N	2026-09-13 15:07:23.940429+00	2026-09-13 15:07:23.953699+00	\N	\N			\N		0	\N		\N	f	\N	f
\.


--
-- Data for Name: webauthn_challenges; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.webauthn_challenges (id, user_id, challenge_type, session_data, created_at, expires_at) FROM stdin;
\.


--
-- Data for Name: webauthn_credentials; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.webauthn_credentials (id, user_id, credential_id, public_key, attestation_type, aaguid, sign_count, transports, backup_eligible, backed_up, friendly_name, created_at, updated_at, last_used_at) FROM stdin;
\.


--
-- Data for Name: batch_materials; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.batch_materials (id, batch_id, raw_material_id, material_lot_id, recipe_quantity, recipe_unit, created_at) FROM stdin;
6b3024ce-8766-45e2-bb98-d1f4a09c8cfc	0f1f7350-a81b-4256-91c9-e7afe59f3c93	b69eb108-7662-4849-bdd3-f8a1942c6e92	42459057-5170-4159-90e3-869278fdabfd	1.0	kg	2026-09-13 15:25:44.722319+00
83ffaada-2d76-450c-969c-0a3e9b234825	0f1f7350-a81b-4256-91c9-e7afe59f3c93	5d48ce6d-8f6d-4f69-a164-77a335dab366	87d16600-cc19-4ee7-b06f-9a5816b72b04	0.03	kg	2026-09-13 15:25:44.722319+00
cd6d6f25-0da4-4326-b8af-6d4cf7f301a9	0f1f7350-a81b-4256-91c9-e7afe59f3c93	0000b182-1167-44da-83ff-fb52f1cfee5b	4eae3cb7-a1bd-49a8-b36b-8d82016fdb36	0.02	kg	2026-09-13 15:25:44.722319+00
39d90f6d-cdc3-45b0-a326-a8e5212e6868	679277fd-ac4b-4a30-b478-be935ffeb6f8	b69eb108-7662-4849-bdd3-f8a1942c6e92	42459057-5170-4159-90e3-869278fdabfd	1.0	kg	2026-09-13 17:42:30.149216+00
0643b7e2-2984-4622-8081-22cf687524f4	679277fd-ac4b-4a30-b478-be935ffeb6f8	5d48ce6d-8f6d-4f69-a164-77a335dab366	87d16600-cc19-4ee7-b06f-9a5816b72b04	0.03	kg	2026-09-13 17:42:30.149216+00
20d2d8b8-0694-4b27-86f2-4ea378cc063f	679277fd-ac4b-4a30-b478-be935ffeb6f8	0000b182-1167-44da-83ff-fb52f1cfee5b	4eae3cb7-a1bd-49a8-b36b-8d82016fdb36	0.02	kg	2026-09-13 17:42:30.149216+00
\.


--
-- Data for Name: batch_outputs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.batch_outputs (id, batch_id, product_id, quantity, unit, created_at) FROM stdin;
d5c35a09-c5ec-47eb-afd6-5221ca7dd208	0f1f7350-a81b-4256-91c9-e7afe59f3c93	ddf2c5c2-7ab6-4532-93b9-824d84ab59c2	4	lata	2026-09-13 15:26:06.865367+00
ecbe04ad-a1fa-4179-b3b8-7e3f184deb08	679277fd-ac4b-4a30-b478-be935ffeb6f8	ddf2c5c2-7ab6-4532-93b9-824d84ab59c2	5	unidad	2026-09-13 17:42:37.027593+00
\.


--
-- Data for Name: batch_requests; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.batch_requests (id, batch_id, production_request_id, allocated_quantity, created_at) FROM stdin;
c2f35d8e-37f0-4ec5-8884-1d53e4b0bfc3	0f1f7350-a81b-4256-91c9-e7afe59f3c93	900d8067-259a-4a94-bbce-4ab7ca8dbb79	4	2026-09-13 15:25:44.722319+00
722430f2-e571-49f7-8687-60d78d039166	679277fd-ac4b-4a30-b478-be935ffeb6f8	8f139398-d6d0-46eb-8ca0-89793fc74906	5	2026-09-13 17:42:30.149216+00
\.


--
-- Data for Name: brands; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.brands (id, name, active, created_at, updated_at) FROM stdin;
bf74355b-4a6d-4aa1-bf8d-c2e7c47c731d	Lealtad	t	2026-09-11 03:41:58.284675+00	2026-09-11 03:41:58.284675+00
66a2de49-54ff-41a0-964b-90d58fc9cb37	Dos Anclas	t	2026-09-11 03:41:58.284675+00	2026-09-11 03:41:58.284675+00
87122841-3b77-4906-8742-92abda69c231	Calsa	t	2026-09-11 03:41:58.284675+00	2026-09-11 03:41:58.284675+00
\.


--
-- Data for Name: external_order_items; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.external_order_items (id, external_order_id, product_id, quantity, unit, shift_code, notes, created_at) FROM stdin;
\.


--
-- Data for Name: external_orders; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.external_orders (id, order_number, customer_name, requested_date, delivery_time, status, notes, created_by, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: material_lots; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.material_lots (id, raw_material_id, brand_id, supplier_lot, expiry_date, received_at, opened_at, closed_at, is_current, status, created_by, created_at) FROM stdin;
42459057-5170-4159-90e3-869278fdabfd	b69eb108-7662-4849-bdd3-f8a1942c6e92	bf74355b-4a6d-4aa1-bf8d-c2e7c47c731d	H001	\N	\N	2026-09-13 15:07:46.405908+00	\N	t	in_use	\N	2026-09-13 15:07:46.405908+00
87d16600-cc19-4ee7-b06f-9a5816b72b04	5d48ce6d-8f6d-4f69-a164-77a335dab366	87122841-3b77-4906-8742-92abda69c231	L001	\N	\N	2026-09-13 15:07:46.405908+00	\N	t	in_use	\N	2026-09-13 15:07:46.405908+00
4eae3cb7-a1bd-49a8-b36b-8d82016fdb36	0000b182-1167-44da-83ff-fb52f1cfee5b	66a2de49-54ff-41a0-964b-90d58fc9cb37	S001	\N	\N	2026-09-13 15:07:46.405908+00	\N	t	in_use	\N	2026-09-13 15:07:46.405908+00
\.


--
-- Data for Name: parent_batch_inputs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.parent_batch_inputs (id, child_batch_id, parent_batch_output_id, quantity, unit, created_at) FROM stdin;
\.


--
-- Data for Name: production_batches; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.production_batches (id, production_day_id, recipe_version_id, shift_code, batch_code, status, started_at, started_by, finished_at, finished_by, notes, created_at) FROM stdin;
0f1f7350-a81b-4256-91c9-e7afe59f3c93	8aa30738-8b33-4fd0-823e-1d11f2e1a9a4	1777f522-be69-483b-87d3-42b2cee966e2	morning	PAN-130926-M-001	completed	2026-09-13 15:25:44.722319+00	8a271366-4b41-4d2f-813c-4d553c83b968	2026-09-13 15:26:06.865367+00	8a271366-4b41-4d2f-813c-4d553c83b968	\N	2026-09-13 15:25:44.722319+00
679277fd-ac4b-4a30-b478-be935ffeb6f8	8aa30738-8b33-4fd0-823e-1d11f2e1a9a4	1777f522-be69-483b-87d3-42b2cee966e2	morning	PAN-130926-M-002	completed	2026-09-13 17:42:30.149216+00	8a271366-4b41-4d2f-813c-4d553c83b968	2026-09-13 17:42:37.027593+00	8a271366-4b41-4d2f-813c-4d553c83b968	\N	2026-09-13 17:42:30.149216+00
\.


--
-- Data for Name: production_days; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.production_days (id, production_date, status, opened_at, opened_by, closed_at, closed_by, created_at) FROM stdin;
afe6c8e9-7df0-4e11-8154-51a2c4071a24	2026-09-11	open	2026-09-11 22:01:49.867607+00	\N	\N	\N	2026-09-11 22:01:49.867607+00
8aa30738-8b33-4fd0-823e-1d11f2e1a9a4	2026-09-13	open	2026-09-13 15:19:08.8215+00	8a271366-4b41-4d2f-813c-4d553c83b968	\N	\N	2026-09-13 15:19:08.8215+00
\.


--
-- Data for Name: production_plan_items; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.production_plan_items (id, weekday, shift_code, product_id, planned_quantity, unit, sort_order, active, created_at, updated_at) FROM stdin;
add60507-f9f5-4a0b-85ee-9f473a4a6bfd	6	morning	ddf2c5c2-7ab6-4532-93b9-824d84ab59c2	4	lata	0	t	2026-09-13 15:07:46.405908+00	2026-09-13 15:07:46.405908+00
08a2af1c-5dd3-4d81-9f52-e8965b17e7b5	7	morning	ddf2c5c2-7ab6-4532-93b9-824d84ab59c2	4	lata	0	t	2026-09-13 15:19:53.42382+00	2026-09-13 15:19:53.42382+00
\.


--
-- Data for Name: production_requests; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.production_requests (id, production_day_id, source_type, shift_code, product_id, requested_quantity, unit, external_order_item_id, reason_code, reason_note, status, created_by, created_at) FROM stdin;
c5b9cfdb-c7e5-4f50-9c8c-26ecd51f47c1	8aa30738-8b33-4fd0-823e-1d11f2e1a9a4	additional	morning	35ae09e7-8e14-431a-9482-13324e348cef	1	unidad	\N	increased_demand	\N	pending	8a271366-4b41-4d2f-813c-4d553c83b968	2026-09-13 17:47:45.338833+00
900d8067-259a-4a94-bbce-4ab7ca8dbb79	8aa30738-8b33-4fd0-823e-1d11f2e1a9a4	base	morning	ddf2c5c2-7ab6-4532-93b9-824d84ab59c2	4	lata	\N	\N	\N	completed	8a271366-4b41-4d2f-813c-4d553c83b968	2026-09-13 15:19:53.597508+00
27677e24-4c4c-439d-a3e4-48fa22b172a8	8aa30738-8b33-4fd0-823e-1d11f2e1a9a4	additional	afternoon	35ae09e7-8e14-431a-9482-13324e348cef	1	unidad	\N	other	nkljnkj	pending	8a271366-4b41-4d2f-813c-4d553c83b968	2026-09-13 17:41:51.767618+00
8f139398-d6d0-46eb-8ca0-89793fc74906	8aa30738-8b33-4fd0-823e-1d11f2e1a9a4	additional	morning	ddf2c5c2-7ab6-4532-93b9-824d84ab59c2	5	unidad	\N	remake	\N	completed	8a271366-4b41-4d2f-813c-4d553c83b968	2026-09-13 17:42:27.810105+00
\.


--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.products (id, name, default_unit, default_shift_code, active, created_at, updated_at) FROM stdin;
ddf2c5c2-7ab6-4532-93b9-824d84ab59c2	Baguette	unidad	morning	t	2026-09-11 03:41:58.304713+00	2026-09-11 03:41:58.304713+00
35ae09e7-8e14-431a-9482-13324e348cef	Pan Mignon	unidad	night	t	2026-09-11 03:41:58.304713+00	2026-09-11 03:41:58.304713+00
\.


--
-- Data for Name: profiles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.profiles (id, full_name, role, active, created_at, updated_at) FROM stdin;
8a271366-4b41-4d2f-813c-4d553c83b968	Admin Demo	admin	t	2026-09-13 15:07:46.405908+00	2026-09-13 15:07:46.405908+00
be18bd95-e3e4-488d-ab33-820ef8ad86d0	Supervisor Demo	supervisor	t	2026-09-13 15:07:46.405908+00	2026-09-13 15:07:46.405908+00
9ba5032b-93bb-40fa-b665-a45a8c11aff1	Operador Demo	operator	t	2026-09-13 15:07:46.405908+00	2026-09-13 15:07:46.405908+00
\.


--
-- Data for Name: raw_material_brands; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.raw_material_brands (id, raw_material_id, brand_id, active, created_at) FROM stdin;
1ecdc8ef-88bf-4186-b648-e5ab497e9ee5	b69eb108-7662-4849-bdd3-f8a1942c6e92	bf74355b-4a6d-4aa1-bf8d-c2e7c47c731d	t	2026-09-11 03:41:58.299765+00
8ee034ed-7191-43ab-a630-8ba09d8c1609	0000b182-1167-44da-83ff-fb52f1cfee5b	66a2de49-54ff-41a0-964b-90d58fc9cb37	t	2026-09-11 03:41:58.299765+00
b14caffd-65c7-4c57-8eff-2aedef0056a6	5d48ce6d-8f6d-4f69-a164-77a335dab366	87122841-3b77-4906-8742-92abda69c231	t	2026-09-11 03:41:58.299765+00
\.


--
-- Data for Name: raw_materials; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.raw_materials (id, name, default_unit, active, created_at, updated_at) FROM stdin;
5d48ce6d-8f6d-4f69-a164-77a335dab366	Levadura	kg	t	2026-09-11 03:41:58.268531+00	2026-09-11 03:41:58.268531+00
0000b182-1167-44da-83ff-fb52f1cfee5b	Sal	kg	t	2026-09-11 03:41:58.268531+00	2026-09-11 03:41:58.268531+00
b69eb108-7662-4849-bdd3-f8a1942c6e92	Harina 000	kg	t	2026-09-11 03:41:58.268531+00	2026-09-11 03:41:58.268531+00
\.


--
-- Data for Name: recipe_ingredients; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.recipe_ingredients (id, recipe_version_id, raw_material_id, quantity, unit, sort_order, optional, created_at) FROM stdin;
b7396645-9ba5-470e-b994-5c8b4211373c	1777f522-be69-483b-87d3-42b2cee966e2	b69eb108-7662-4849-bdd3-f8a1942c6e92	1.0	kg	1	f	2026-09-12 03:11:07.696764+00
6bae6f97-40b2-4ba8-88ab-d630b81f8e4b	1777f522-be69-483b-87d3-42b2cee966e2	5d48ce6d-8f6d-4f69-a164-77a335dab366	0.03	kg	3	f	2026-09-12 03:11:07.696764+00
1fd9ee81-fe81-4958-9da7-ab82c434f7a9	1777f522-be69-483b-87d3-42b2cee966e2	0000b182-1167-44da-83ff-fb52f1cfee5b	0.02	kg	2	f	2026-09-12 03:11:07.696764+00
\.


--
-- Data for Name: recipe_product_inputs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.recipe_product_inputs (id, recipe_version_id, source_product_id, quantity, unit, required, created_at) FROM stdin;
\.


--
-- Data for Name: recipe_products; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.recipe_products (id, recipe_id, product_id, sort_order, created_at) FROM stdin;
85803d04-3333-4ca4-90be-4107e140a316	8ab0caba-5912-4320-aca9-3511c7bac340	ddf2c5c2-7ab6-4532-93b9-824d84ab59c2	1	2026-09-11 03:41:58.324387+00
\.


--
-- Data for Name: recipe_versions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.recipe_versions (id, recipe_id, version_number, status, effective_from, effective_to, notes, created_at) FROM stdin;
1777f522-be69-483b-87d3-42b2cee966e2	8ab0caba-5912-4320-aca9-3511c7bac340	1	active	2026-09-11	\N	\N	2026-09-11 03:41:58.310359+00
\.


--
-- Data for Name: recipes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.recipes (id, name, active, created_at, updated_at) FROM stdin;
8ab0caba-5912-4320-aca9-3511c7bac340	Baguette	t	2026-09-11 03:41:58.307959+00	2026-09-11 03:41:58.307959+00
\.


--
-- Data for Name: messages_2026_09_10; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.messages_2026_09_10 (topic, extension, payload, event, private, updated_at, inserted_at, id, binary_payload) FROM stdin;
\.


--
-- Data for Name: messages_2026_09_11; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.messages_2026_09_11 (topic, extension, payload, event, private, updated_at, inserted_at, id, binary_payload) FROM stdin;
\.


--
-- Data for Name: messages_2026_09_12; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.messages_2026_09_12 (topic, extension, payload, event, private, updated_at, inserted_at, id, binary_payload) FROM stdin;
\.


--
-- Data for Name: messages_2026_09_13; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.messages_2026_09_13 (topic, extension, payload, event, private, updated_at, inserted_at, id, binary_payload) FROM stdin;
\.


--
-- Data for Name: messages_2026_09_14; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.messages_2026_09_14 (topic, extension, payload, event, private, updated_at, inserted_at, id, binary_payload) FROM stdin;
\.


--
-- Data for Name: messages_2026_09_15; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.messages_2026_09_15 (topic, extension, payload, event, private, updated_at, inserted_at, id, binary_payload) FROM stdin;
\.


--
-- Data for Name: messages_2026_09_16; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.messages_2026_09_16 (topic, extension, payload, event, private, updated_at, inserted_at, id, binary_payload) FROM stdin;
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.schema_migrations (version, inserted_at) FROM stdin;
20211116024918	2026-09-11 01:20:53
20211116045059	2026-09-11 01:20:53
20211116050929	2026-09-11 01:20:53
20211116051442	2026-09-11 01:20:53
20211116212300	2026-09-11 01:20:53
20211116213355	2026-09-11 01:20:53
20211116213934	2026-09-11 01:20:53
20211116214523	2026-09-11 01:20:53
20211122062447	2026-09-11 01:20:53
20211124070109	2026-09-11 01:20:53
20211202204204	2026-09-11 01:20:53
20211202204605	2026-09-11 01:20:53
20211210212804	2026-09-11 01:20:53
20211228014915	2026-09-11 01:20:53
20220107221237	2026-09-11 01:20:53
20220228202821	2026-09-11 01:20:53
20220312004840	2026-09-11 01:20:53
20220603231003	2026-09-11 01:20:53
20220603232444	2026-09-11 01:20:53
20220615214548	2026-09-11 01:20:53
20220712093339	2026-09-11 01:20:53
20220908172859	2026-09-11 01:20:53
20220916233421	2026-09-11 01:20:53
20230119133233	2026-09-11 01:20:53
20230128025114	2026-09-11 01:20:53
20230128025212	2026-09-11 01:20:53
20230227211149	2026-09-11 01:20:53
20230228184745	2026-09-11 01:20:53
20230308225145	2026-09-11 01:20:53
20230328144023	2026-09-11 01:20:53
20231018144023	2026-09-11 01:20:53
20231204144023	2026-09-11 01:20:53
20231204144024	2026-09-11 01:20:53
20231204144025	2026-09-11 01:20:53
20240108234812	2026-09-11 01:20:53
20240109165339	2026-09-11 01:20:53
20240227174441	2026-09-11 01:20:53
20240311171622	2026-09-11 01:20:53
20240321100241	2026-09-11 01:20:53
20240401105812	2026-09-11 01:20:53
20240418121054	2026-09-11 01:20:53
20240523004032	2026-09-11 01:20:53
20240618124746	2026-09-11 01:20:53
20240801235015	2026-09-11 01:20:53
20240805133720	2026-09-11 01:20:53
20240827160934	2026-09-11 01:20:53
20240919163303	2026-09-11 01:20:53
20240919163305	2026-09-11 01:20:53
20241019105805	2026-09-11 01:20:53
20241030150047	2026-09-11 01:20:53
20241108114728	2026-09-11 01:20:53
20241121104152	2026-09-11 01:20:53
20241130184212	2026-09-11 01:20:53
20241220035512	2026-09-11 01:20:53
20241220123912	2026-09-11 01:20:53
20241224161212	2026-09-11 01:20:53
20250107150512	2026-09-11 01:20:53
20250110162412	2026-09-11 01:20:53
20250123174212	2026-09-11 01:20:53
20250128220012	2026-09-11 01:20:53
20250506224012	2026-09-11 01:20:53
20250523164012	2026-09-11 01:20:53
20250714121412	2026-09-11 01:20:53
20250905041441	2026-09-11 01:20:53
20251103001201	2026-09-11 01:20:53
20251120212548	2026-09-11 01:20:53
20251120215549	2026-09-11 01:20:53
20260218120000	2026-09-11 01:20:53
20260326120000	2026-09-11 01:20:53
20260514120000	2026-09-11 01:20:53
20260527120000	2026-09-11 01:20:53
20260528120000	2026-09-11 01:20:53
20260603120000	2026-09-11 01:20:53
20260605120000	2026-09-11 01:20:53
20260606110000	2026-09-11 01:20:53
20260616120000	2026-09-11 01:20:53
20260624120000	2026-09-11 01:20:53
20260626120000	2026-09-11 01:20:53
20260706120000	2026-09-11 01:20:53
20260707120000	2026-09-11 01:20:53
20260709120000	2026-09-11 01:20:53
\.


--
-- Data for Name: subscription; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.subscription (id, subscription_id, entity, filters, claims, created_at, action_filter, selected_columns) FROM stdin;
\.


--
-- Data for Name: buckets; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.buckets (id, name, owner, created_at, updated_at, public, avif_autodetection, file_size_limit, allowed_mime_types, owner_id, type, versioning_status) FROM stdin;
\.


--
-- Data for Name: buckets_analytics; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.buckets_analytics (name, type, format, created_at, updated_at, id, deleted_at) FROM stdin;
\.


--
-- Data for Name: buckets_vectors; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.buckets_vectors (id, type, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: iceberg_namespaces; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.iceberg_namespaces (id, bucket_name, name, created_at, updated_at, metadata, catalog_id) FROM stdin;
\.


--
-- Data for Name: iceberg_tables; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.iceberg_tables (id, namespace_id, bucket_name, name, location, created_at, updated_at, remote_table_id, shard_key, shard_id, catalog_id) FROM stdin;
\.


--
-- Data for Name: migrations; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.migrations (id, name, hash, executed_at) FROM stdin;
0	create-migrations-table	e18db593bcde2aca2a408c4d1100f6abba2195df	2026-09-11 01:21:03.117884
1	initialmigration	6ab16121fbaa08bbd11b712d05f358f9b555d777	2026-09-11 01:21:03.12707
2	storage-schema	f6a1fa2c93cbcd16d4e487b362e45fca157a8dbd	2026-09-11 01:21:03.132198
3	pathtoken-column	2cb1b0004b817b29d5b0a971af16bafeede4b70d	2026-09-11 01:21:03.151647
4	add-migrations-rls	427c5b63fe1c5937495d9c635c263ee7a5905058	2026-09-11 01:21:03.164321
5	add-size-functions	79e081a1455b63666c1294a440f8ad4b1e6a7f84	2026-09-11 01:21:03.167226
6	change-column-name-in-get-size	ded78e2f1b5d7e616117897e6443a925965b30d2	2026-09-11 01:21:03.170101
7	add-rls-to-buckets	e7e7f86adbc51049f341dfe8d30256c1abca17aa	2026-09-11 01:21:03.174113
8	add-public-to-buckets	fd670db39ed65f9d08b01db09d6202503ca2bab3	2026-09-11 01:21:03.176657
9	fix-search-function	af597a1b590c70519b464a4ab3be54490712796b	2026-09-11 01:21:03.179843
10	search-files-search-function	b595f05e92f7e91211af1bbfe9c6a13bb3391e16	2026-09-11 01:21:03.182692
11	add-trigger-to-auto-update-updated_at-column	7425bdb14366d1739fa8a18c83100636d74dcaa2	2026-09-11 01:21:03.186268
12	add-automatic-avif-detection-flag	8e92e1266eb29518b6a4c5313ab8f29dd0d08df9	2026-09-11 01:21:03.190381
13	add-bucket-custom-limits	cce962054138135cd9a8c4bcd531598684b25e7d	2026-09-11 01:21:03.19431
14	use-bytes-for-max-size	941c41b346f9802b411f06f30e972ad4744dad27	2026-09-11 01:21:03.199295
15	add-can-insert-object-function	934146bc38ead475f4ef4b555c524ee5d66799e5	2026-09-11 01:21:03.221299
16	add-version	76debf38d3fd07dcfc747ca49096457d95b1221b	2026-09-11 01:21:03.225957
17	drop-owner-foreign-key	f1cbb288f1b7a4c1eb8c38504b80ae2a0153d101	2026-09-11 01:21:03.230285
18	add_owner_id_column_deprecate_owner	e7a511b379110b08e2f214be852c35414749fe66	2026-09-11 01:21:03.234003
19	alter-default-value-objects-id	02e5e22a78626187e00d173dc45f58fa66a4f043	2026-09-11 01:21:03.241194
20	list-objects-with-delimiter	cd694ae708e51ba82bf012bba00caf4f3b6393b7	2026-09-11 01:21:03.248412
21	s3-multipart-uploads	8c804d4a566c40cd1e4cc5b3725a664a9303657f	2026-09-11 01:21:03.256145
22	s3-multipart-uploads-big-ints	9737dc258d2397953c9953d9b86920b8be0cdb73	2026-09-11 01:21:03.278132
23	optimize-search-function	9d7e604cddc4b56a5422dc68c9313f4a1b6f132c	2026-09-11 01:21:03.285653
24	operation-function	8312e37c2bf9e76bbe841aa5fda889206d2bf8aa	2026-09-11 01:21:03.288758
25	custom-metadata	d974c6057c3db1c1f847afa0e291e6165693b990	2026-09-11 01:21:03.291563
26	objects-prefixes	215cabcb7f78121892a5a2037a09fedf9a1ae322	2026-09-11 01:21:03.294517
27	search-v2	859ba38092ac96eb3964d83bf53ccc0b141663a6	2026-09-11 01:21:03.297628
28	object-bucket-name-sorting	c73a2b5b5d4041e39705814fd3a1b95502d38ce4	2026-09-11 01:21:03.302996
29	create-prefixes	ad2c1207f76703d11a9f9007f821620017a66c21	2026-09-11 01:21:03.308554
30	update-object-levels	2be814ff05c8252fdfdc7cfb4b7f5c7e17f0bed6	2026-09-11 01:21:03.311694
31	objects-level-index	b40367c14c3440ec75f19bbce2d71e914ddd3da0	2026-09-11 01:21:03.314014
32	backward-compatible-index-on-objects	e0c37182b0f7aee3efd823298fb3c76f1042c0f7	2026-09-11 01:21:03.316693
33	backward-compatible-index-on-prefixes	b480e99ed951e0900f033ec4eb34b5bdcb4e3d49	2026-09-11 01:21:03.32084
34	optimize-search-function-v1	ca80a3dc7bfef894df17108785ce29a7fc8ee456	2026-09-11 01:21:03.32503
35	add-insert-trigger-prefixes	458fe0ffd07ec53f5e3ce9df51bfdf4861929ccc	2026-09-11 01:21:03.328665
36	optimise-existing-functions	6ae5fca6af5c55abe95369cd4f93985d1814ca8f	2026-09-11 01:21:03.331363
37	add-bucket-name-length-trigger	3944135b4e3e8b22d6d4cbb568fe3b0b51df15c1	2026-09-11 01:21:03.333414
38	iceberg-catalog-flag-on-buckets	02716b81ceec9705aed84aa1501657095b32e5c5	2026-09-11 01:21:03.335794
39	add-search-v2-sort-support	6706c5f2928846abee18461279799ad12b279b78	2026-09-11 01:21:03.355727
40	fix-prefix-race-conditions-optimized	7ad69982ae2d372b21f48fc4829ae9752c518f6b	2026-09-11 01:21:03.361333
41	add-object-level-update-trigger	07fcf1a22165849b7a029deed059ffcde08d1ae0	2026-09-11 01:21:03.364771
42	rollback-prefix-triggers	771479077764adc09e2ea2043eb627503c034cd4	2026-09-11 01:21:03.368184
43	fix-object-level	84b35d6caca9d937478ad8a797491f38b8c2979f	2026-09-11 01:21:03.370517
44	vector-bucket-type	99c20c0ffd52bb1ff1f32fb992f3b351e3ef8fb3	2026-09-11 01:21:03.374169
45	vector-buckets	049e27196d77a7cb76497a85afae669d8b230953	2026-09-11 01:21:03.379596
46	buckets-objects-grants	fedeb96d60fefd8e02ab3ded9fbde05632f84aed	2026-09-11 01:21:03.392016
47	iceberg-table-metadata	649df56855c24d8b36dd4cc1aeb8251aa9ad42c2	2026-09-11 01:21:03.396077
48	iceberg-catalog-ids	e0e8b460c609b9999ccd0df9ad14294613eed939	2026-09-11 01:21:03.400988
49	buckets-objects-grants-postgres	072b1195d0d5a2f888af6b2302a1938dd94b8b3d	2026-09-11 01:21:03.443717
50	search-v2-optimised	6323ac4f850aa14e7387eb32102869578b5bd478	2026-09-11 01:21:03.447422
51	index-backward-compatible-search	2ee395d433f76e38bcd3856debaf6e0e5b674011	2026-09-11 01:21:03.466684
52	drop-not-used-indexes-and-functions	5cc44c8696749ac11dd0dc37f2a3802075f3a171	2026-09-11 01:21:03.468643
53	drop-index-lower-name	d0cb18777d9e2a98ebe0bc5cc7a42e57ebe41854	2026-09-11 01:21:03.475712
54	drop-index-object-level	6289e048b1472da17c31a7eba1ded625a6457e67	2026-09-11 01:21:03.477602
55	prevent-direct-deletes	262a4798d5e0f2e7c8970232e03ce8be695d5819	2026-09-11 01:21:03.479497
56	fix-optimized-search-function	b823ed1e418101032fa01374edc9a436e54e3ed4	2026-09-11 01:21:03.484793
57	s3-multipart-uploads-metadata	f127886e00d1b374fadbc7c6b31e09336aad5287	2026-09-11 01:21:03.491773
58	operation-ergonomics	00ca5d483b3fe0d522133d9002ccc5df98365120	2026-09-11 01:21:03.496185
59	drop-unused-functions	38456f13e39691c2bbb4b5151d0d1cdbabd4a8c4	2026-09-11 01:21:03.501553
60	optimize-existing-functions-again	db35e1c91a9201e59f4fef8d972c2f277d68b157	2026-09-11 01:21:03.50445
61	mark-filename-immutable	fe0096517ae9d60aaec1d110172ba9036dc66bb7	2026-09-11 01:21:03.507867
62	object-versioning-core	0b855f00ff3be0bfca91efee02a9858912491a9a	2026-09-11 01:21:03.511677
63	fix-search-name-relative-to-prefix	c7485e417624f795ce8bb2da21927f48e088904d	2026-09-11 01:21:03.521803
64	fix-search-by-timestamp-sqli	0af424ecd388a39bb1645184b222185a12149675	2026-09-11 01:21:03.527691
65	objects-key-version-index	e63aa8274a637c696cfdac70eeb0988245fe87bd	2026-09-11 01:21:03.536611
66	objects-current-version-index	ef7a33ec298fefe19351e9ff542b52b7511c3f02	2026-09-11 01:21:03.54541
67	objects-null-version-index	351b645504ec2ad54c5ef2b42989db04b617579f	2026-09-11 01:21:03.553785
\.


--
-- Data for Name: objects; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.objects (id, bucket_id, name, owner, created_at, updated_at, last_accessed_at, metadata, version, owner_id, user_metadata, archived_at, is_delete_marker, is_versioned) FROM stdin;
\.


--
-- Data for Name: s3_multipart_uploads; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.s3_multipart_uploads (id, in_progress_size, upload_signature, bucket_id, key, version, owner_id, created_at, user_metadata, metadata) FROM stdin;
\.


--
-- Data for Name: s3_multipart_uploads_parts; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.s3_multipart_uploads_parts (id, upload_id, size, part_number, bucket_id, key, etag, owner_id, version, created_at) FROM stdin;
\.


--
-- Data for Name: vector_indexes; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.vector_indexes (id, name, bucket_id, data_type, dimension, distance_metric, metadata_configuration, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: hooks; Type: TABLE DATA; Schema: supabase_functions; Owner: -
--

COPY supabase_functions.hooks (id, hook_table_id, hook_name, created_at, request_id) FROM stdin;
\.


--
-- Data for Name: migrations; Type: TABLE DATA; Schema: supabase_functions; Owner: -
--

COPY supabase_functions.migrations (version, inserted_at) FROM stdin;
initial	2026-09-11 01:20:48.676946+00
20210809183423_update_grants	2026-09-11 01:20:48.676946+00
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: supabase_migrations; Owner: -
--

COPY supabase_migrations.schema_migrations (version, statements, name) FROM stdin;
20250910100001	{"-- Phase E1: application profiles for authenticated users.\n\ncreate table public.profiles (\n  id uuid primary key references auth.users (id) on delete cascade,\n  full_name text not null,\n  role text not null check (role in ('operator', 'supervisor', 'admin')),\n  active boolean not null default true,\n  created_at timestamptz not null default now(),\n  updated_at timestamptz not null default now()\n)","comment on table public.profiles is\n  'Application profile per authenticated user, including the role used by the app.'","alter table public.profiles enable row level security"}	profiles
20250910100002	{"-- Phase F1: raw material master data.\n\ncreate table public.raw_materials (\n  id uuid primary key default gen_random_uuid(),\n  name text not null check (btrim(name) <> ''),\n  default_unit text not null,\n  active boolean not null default true,\n  created_at timestamptz not null default now(),\n  updated_at timestamptz not null default now()\n)","comment on table public.raw_materials is\n  'Raw materials (flour, salt, yeast, ...). Case-insensitive unique name.'","-- Clean case-insensitive uniqueness strategy for name.\ncreate unique index raw_materials_name_lower_key\n  on public.raw_materials (lower(name))","alter table public.raw_materials enable row level security"}	raw_materials
20250910100003	{"-- Phase F2: brands for raw materials.\n\ncreate table public.brands (\n  id uuid primary key default gen_random_uuid(),\n  name text not null check (btrim(name) <> ''),\n  active boolean not null default true,\n  created_at timestamptz not null default now(),\n  updated_at timestamptz not null default now()\n)","comment on table public.brands is 'Raw material brands (Lealtad, Dos Anclas, Calsa, ...).'","alter table public.brands enable row level security"}	brands
20250910100004	{"-- Phase F3: link between raw materials and the brands they use.\n\ncreate table public.raw_material_brands (\n  id uuid primary key default gen_random_uuid(),\n  raw_material_id uuid not null references public.raw_materials (id) on delete restrict,\n  brand_id uuid not null references public.brands (id) on delete restrict,\n  active boolean not null default true,\n  created_at timestamptz not null default now(),\n  unique (raw_material_id, brand_id)\n)","comment on table public.raw_material_brands is\n  'Which brands are valid for each raw material. Restrictive FKs: master data is not deleted while linked.'","alter table public.raw_material_brands enable row level security"}	raw_material_brands
20250910100005	{"-- Phase G1: material lots (received/opened units of a raw material).\n\ncreate table public.material_lots (\n  id uuid primary key default gen_random_uuid(),\n  raw_material_id uuid not null references public.raw_materials (id) on delete restrict,\n  brand_id uuid not null references public.brands (id) on delete restrict,\n  supplier_lot text not null,\n  expiry_date date,\n  received_at timestamptz,\n  opened_at timestamptz,\n  closed_at timestamptz,\n  is_current boolean not null default false,\n  status text not null check (status in ('available', 'in_use', 'closed', 'discarded')),\n  created_by uuid references auth.users (id),\n  created_at timestamptz not null default now()\n)","comment on table public.material_lots is\n  'Lots of a raw material used in production. At most one lot is current per raw material.'","-- Critical rule: at most one is_current = true per raw_material_id.\ncreate unique index material_lots_one_current_per_raw_material\n  on public.material_lots (raw_material_id)\n  where is_current","alter table public.material_lots enable row level security"}	material_lots
20250910100006	{"-- Phase H1: finished products with their default production shift.\n\ncreate table public.products (\n  id uuid primary key default gen_random_uuid(),\n  name text not null,\n  default_unit text not null,\n  default_shift_code text not null check (default_shift_code in ('morning', 'afternoon', 'night')),\n  active boolean not null default true,\n  created_at timestamptz not null default now(),\n  updated_at timestamptz not null default now()\n)","comment on table public.products is\n  'Finished products. default_shift_code is the normal/default shift only: historical shift is copied into production requests and batches, it is never re-inferred from here.'","alter table public.products enable row level security"}	products
20250910100007	{"-- Phase I1: recipes (production formulas).\n\ncreate table public.recipes (\n  id uuid primary key default gen_random_uuid(),\n  name text not null,\n  active boolean not null default true,\n  created_at timestamptz not null default now(),\n  updated_at timestamptz not null default now()\n)","comment on table public.recipes is\n  'A recipe is a production formula/preparation, not necessarily one finished product.'","alter table public.recipes enable row level security"}	recipes
20250910100008	{"-- Phase I2: versioned recipe content.\n\ncreate table public.recipe_versions (\n  id uuid primary key default gen_random_uuid(),\n  recipe_id uuid not null references public.recipes (id) on delete restrict,\n  version_number integer not null check (version_number > 0),\n  status text not null check (status in ('draft', 'active', 'retired')),\n  effective_from date,\n  effective_to date,\n  notes text,\n  created_at timestamptz not null default now(),\n  unique (recipe_id, version_number)\n)","comment on table public.recipe_versions is\n  'Versions of a recipe. Historical batches keep pointing at the version used at batch start.'","-- At most one active version per recipe.\ncreate unique index recipe_versions_one_active_per_recipe\n  on public.recipe_versions (recipe_id)\n  where status = 'active'","alter table public.recipe_versions enable row level security"}	recipe_versions
20250910100009	{"-- Phase I3: raw-material ingredients of a recipe version.\n\ncreate table public.recipe_ingredients (\n  id uuid primary key default gen_random_uuid(),\n  recipe_version_id uuid not null references public.recipe_versions (id) on delete restrict,\n  raw_material_id uuid not null references public.raw_materials (id) on delete restrict,\n  quantity numeric not null check (quantity > 0),\n  unit text not null,\n  sort_order integer not null default 0,\n  optional boolean not null default false,\n  created_at timestamptz not null default now(),\n  unique (recipe_version_id, raw_material_id)\n)","comment on table public.recipe_ingredients is\n  'Raw materials required by one recipe version (one row per material).'","alter table public.recipe_ingredients enable row level security"}	recipe_ingredients
20250910100010	{"-- Phase I4: products produced by a recipe.\n\ncreate table public.recipe_products (\n  id uuid primary key default gen_random_uuid(),\n  recipe_id uuid not null references public.recipes (id) on delete restrict,\n  product_id uuid not null references public.products (id) on delete restrict,\n  sort_order integer not null default 0,\n  created_at timestamptz not null default now(),\n  unique (recipe_id, product_id)\n)","comment on table public.recipe_products is\n  'Links a recipe/preparation to one or multiple products it produces.'","alter table public.recipe_products enable row level security"}	recipe_products
20250910100011	{"-- Phase J1: previously produced products used as inputs of a recipe.\n\ncreate table public.recipe_product_inputs (\n  id uuid primary key default gen_random_uuid(),\n  recipe_version_id uuid not null references public.recipe_versions (id) on delete restrict,\n  source_product_id uuid not null references public.products (id) on delete restrict,\n  quantity numeric check (quantity > 0),\n  unit text,\n  required boolean not null default true,\n  created_at timestamptz not null default now()\n)","comment on table public.recipe_product_inputs is\n  'Declares that a recipe can require a previously produced product as input (e.g. Masa Pan Galleta -> Pan Galleta). Historical batches are linked later via parent_batch_inputs.'","alter table public.recipe_product_inputs enable row level security"}	recipe_product_inputs
20250910100012	{"-- Phase K1: weekly base production plan.\n\ncreate table public.production_plan_items (\n  id uuid primary key default gen_random_uuid(),\n  weekday smallint not null check (weekday between 1 and 7),\n  shift_code text not null check (shift_code in ('morning', 'afternoon', 'night')),\n  product_id uuid not null references public.products (id) on delete restrict,\n  planned_quantity numeric not null check (planned_quantity > 0),\n  unit text not null,\n  sort_order integer not null default 0,\n  active boolean not null default true,\n  created_at timestamptz not null default now(),\n  updated_at timestamptz not null default now()\n)","comment on table public.production_plan_items is\n  'Base production plan by weekday and shift. Weekday: 1 = Monday ... 7 = Sunday.'","-- At most one active row per weekday + shift + product + unit.\ncreate unique index production_plan_items_one_active_per_key\n  on public.production_plan_items (weekday, shift_code, product_id, unit)\n  where active","alter table public.production_plan_items enable row level security"}	production_plan_items
20250910100013	{"-- Phase L1: external (customer) orders.\n\ncreate table public.external_orders (\n  id uuid primary key default gen_random_uuid(),\n  order_number text not null unique,\n  customer_name text not null,\n  requested_date date not null,\n  delivery_time time,\n  status text not null check (status in ('pending', 'in_production', 'completed', 'cancelled')),\n  notes text,\n  created_by uuid references auth.users (id),\n  created_at timestamptz not null default now(),\n  updated_at timestamptz not null default now()\n)","comment on table public.external_orders is 'External customer orders.'","alter table public.external_orders enable row level security"}	external_orders
20250910100014	{"-- Phase L2: items of an external order.\n\ncreate table public.external_order_items (\n  id uuid primary key default gen_random_uuid(),\n  external_order_id uuid not null references public.external_orders (id) on delete restrict,\n  product_id uuid not null references public.products (id) on delete restrict,\n  quantity numeric not null check (quantity > 0),\n  unit text not null,\n  shift_code text not null check (shift_code in ('morning', 'afternoon', 'night')),\n  notes text,\n  created_at timestamptz not null default now()\n)","comment on table public.external_order_items is\n  'Order items. shift_code is the actual planned production shift for this item (defaulted from the product, overridable by supervisor/admin).'","alter table public.external_order_items enable row level security"}	external_order_items
20250910100015	{"-- Phase M1: production day (one row per business date).\n\ncreate table public.production_days (\n  id uuid primary key default gen_random_uuid(),\n  production_date date not null unique,\n  status text not null check (status in ('open', 'closed')),\n  opened_at timestamptz,\n  opened_by uuid references auth.users (id),\n  closed_at timestamptz,\n  closed_by uuid references auth.users (id),\n  created_at timestamptz not null default now()\n)","comment on table public.production_days is\n  'One row per business date (America/Argentina/Cordoba). Created by ensure_production_day in later phases.'","alter table public.production_days enable row level security"}	production_days
20250910100016	{"-- Phase N1: unified production requests (base, external order, additional).\n\ncreate table public.production_requests (\n  id uuid primary key default gen_random_uuid(),\n  production_day_id uuid not null references public.production_days (id) on delete restrict,\n  source_type text not null check (source_type in ('base', 'external_order', 'additional')),\n  shift_code text not null check (shift_code in ('morning', 'afternoon', 'night')),\n  product_id uuid not null references public.products (id) on delete restrict,\n  requested_quantity numeric not null check (requested_quantity > 0),\n  unit text not null,\n  external_order_item_id uuid references public.external_order_items (id) on delete restrict,\n  reason_code text check (reason_code in ('replenishment', 'increased_demand', 'remake', 'other')),\n  reason_note text,\n  status text not null check (status in ('pending', 'in_progress', 'completed', 'cancelled')),\n  created_by uuid references auth.users (id),\n  created_at timestamptz not null default now(),\n\n  -- base: no order item, no reason.\n  constraint production_requests_base_integrity check (\n    source_type <> 'base'\n    or (external_order_item_id is null and reason_code is null and reason_note is null)\n  ),\n\n  -- external_order: exactly one order item, no reason.\n  constraint production_requests_external_order_integrity check (\n    source_type <> 'external_order'\n    or (external_order_item_id is not null and reason_code is null and reason_note is null)\n  ),\n\n  -- additional: no order item, reason required; \\"other\\" requires a non-empty note.\n  constraint production_requests_additional_integrity check (\n    source_type <> 'additional'\n    or (\n      external_order_item_id is null\n      and reason_code is not null\n      and (reason_code <> 'other' or (reason_note is not null and btrim(reason_note) <> ''))\n    )\n  )\n)","comment on table public.production_requests is\n  'Unified production requests. shift_code is historical: it is never re-inferred from products.default_shift_code.'","alter table public.production_requests enable row level security"}	production_requests
20250910100017	{"-- Phase O1: production batches.\n\ncreate table public.production_batches (\n  id uuid primary key default gen_random_uuid(),\n  production_day_id uuid not null references public.production_days (id) on delete restrict,\n  recipe_version_id uuid not null references public.recipe_versions (id) on delete restrict,\n  shift_code text not null check (shift_code in ('morning', 'afternoon', 'night')),\n  batch_code text not null unique,\n  status text not null check (status in ('in_progress', 'completed', 'cancelled')),\n  started_at timestamptz not null,\n  started_by uuid not null references auth.users (id),\n  finished_at timestamptz,\n  finished_by uuid references auth.users (id),\n  notes text,\n  created_at timestamptz not null default now()\n)","comment on table public.production_batches is\n  'Production batches. shift_code is copied from the production request (historical). Batch code format: PAN-DDMMYY-X-NNN (X = M/T/N), generated in later phases.'","alter table public.production_batches enable row level security"}	production_batches
20250910100018	{"-- Phase O2: historical snapshot of the material lots used by a batch.\n\ncreate table public.batch_materials (\n  id uuid primary key default gen_random_uuid(),\n  batch_id uuid not null references public.production_batches (id) on delete restrict,\n  raw_material_id uuid not null references public.raw_materials (id) on delete restrict,\n  material_lot_id uuid not null references public.material_lots (id) on delete restrict,\n  recipe_quantity numeric check (recipe_quantity > 0),\n  recipe_unit text,\n  created_at timestamptz not null default now(),\n  unique (batch_id, raw_material_id, material_lot_id)\n)","comment on table public.batch_materials is\n  'Snapshot of the exact current material lots at batch start. Append-mostly: historical traceability must never be reconstructed from material_lots.is_current.'","alter table public.batch_materials enable row level security"}	batch_materials
20250910100019	{"-- Phase O3: outputs of a batch.\n\ncreate table public.batch_outputs (\n  id uuid primary key default gen_random_uuid(),\n  batch_id uuid not null references public.production_batches (id) on delete restrict,\n  product_id uuid not null references public.products (id) on delete restrict,\n  quantity numeric not null check (quantity > 0),\n  unit text not null,\n  created_at timestamptz not null default now()\n)","comment on table public.batch_outputs is 'Products produced by a batch (one row per product, supports multi-output recipes).'","alter table public.batch_outputs enable row level security"}	batch_outputs
20250910100020	{"-- Phase O4: link between batches and the production requests they cover.\n\ncreate table public.batch_requests (\n  id uuid primary key default gen_random_uuid(),\n  batch_id uuid not null references public.production_batches (id) on delete restrict,\n  production_request_id uuid not null references public.production_requests (id) on delete restrict,\n  allocated_quantity numeric check (allocated_quantity > 0),\n  created_at timestamptz not null default now(),\n  unique (batch_id, production_request_id)\n)","comment on table public.batch_requests is\n  'Links one or more production requests to a batch. Restrictive FKs: history is never cascade-deleted.'","alter table public.batch_requests enable row level security"}	batch_requests
20250910100021	{"-- Phase O5: produced-product-as-input traceability (batch consumes output of a parent batch).\n\ncreate table public.parent_batch_inputs (\n  id uuid primary key default gen_random_uuid(),\n  child_batch_id uuid not null references public.production_batches (id) on delete restrict,\n  parent_batch_output_id uuid not null references public.batch_outputs (id) on delete restrict,\n  quantity numeric check (quantity > 0),\n  unit text,\n  created_at timestamptz not null default now()\n)","comment on table public.parent_batch_inputs is\n  'Links a child batch to the batch output it consumed as input (e.g. Pan Leche Redondo produced from Masa Pan Galleta).'","create or replace function public.reject_parent_batch_self_reference()\nreturns trigger\nlanguage plpgsql\nas $$\ndeclare\n  parent_batch uuid;\nbegin\n  select batch_id\n  into parent_batch\n  from public.batch_outputs\n  where id = new.parent_batch_output_id;\n\n  if parent_batch is not null and parent_batch = new.child_batch_id then\n    raise exception 'a batch cannot consume its own output as input';\n  end if;\n\n  return new;\nend;\n$$","-- Prevent obvious self-reference (a batch using its own output).\ncreate trigger parent_batch_inputs_no_self_reference\n  before insert or update of child_batch_id, parent_batch_output_id\n  on public.parent_batch_inputs\n  for each row\n  execute function public.reject_parent_batch_self_reference()","alter table public.parent_batch_inputs enable row level security"}	parent_batch_inputs
\.


--
-- Data for Name: secrets; Type: TABLE DATA; Schema: vault; Owner: -
--

COPY vault.secrets (id, name, description, secret, key_id, nonce, created_at, updated_at) FROM stdin;
\.


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE SET; Schema: auth; Owner: -
--

SELECT pg_catalog.setval('auth.refresh_tokens_id_seq', 68, true);


--
-- Name: subscription_id_seq; Type: SEQUENCE SET; Schema: realtime; Owner: -
--

SELECT pg_catalog.setval('realtime.subscription_id_seq', 1, false);


--
-- Name: hooks_id_seq; Type: SEQUENCE SET; Schema: supabase_functions; Owner: -
--

SELECT pg_catalog.setval('supabase_functions.hooks_id_seq', 1, false);


--
-- Name: extensions extensions_pkey; Type: CONSTRAINT; Schema: _realtime; Owner: -
--

ALTER TABLE ONLY _realtime.extensions
    ADD CONSTRAINT extensions_pkey PRIMARY KEY (id);


--
-- Name: feature_flags feature_flags_pkey; Type: CONSTRAINT; Schema: _realtime; Owner: -
--

ALTER TABLE ONLY _realtime.feature_flags
    ADD CONSTRAINT feature_flags_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: _realtime; Owner: -
--

ALTER TABLE ONLY _realtime.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: tenants tenants_pkey; Type: CONSTRAINT; Schema: _realtime; Owner: -
--

ALTER TABLE ONLY _realtime.tenants
    ADD CONSTRAINT tenants_pkey PRIMARY KEY (id);


--
-- Name: mfa_amr_claims amr_id_pk; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT amr_id_pk PRIMARY KEY (id);


--
-- Name: audit_log_entries audit_log_entries_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.audit_log_entries
    ADD CONSTRAINT audit_log_entries_pkey PRIMARY KEY (id);


--
-- Name: custom_oauth_providers custom_oauth_providers_identifier_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.custom_oauth_providers
    ADD CONSTRAINT custom_oauth_providers_identifier_key UNIQUE (identifier);


--
-- Name: custom_oauth_providers custom_oauth_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.custom_oauth_providers
    ADD CONSTRAINT custom_oauth_providers_pkey PRIMARY KEY (id);


--
-- Name: flow_state flow_state_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.flow_state
    ADD CONSTRAINT flow_state_pkey PRIMARY KEY (id);


--
-- Name: identities identities_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_pkey PRIMARY KEY (id);


--
-- Name: identities identities_provider_id_provider_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_provider_id_provider_unique UNIQUE (provider_id, provider);


--
-- Name: instances instances_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.instances
    ADD CONSTRAINT instances_pkey PRIMARY KEY (id);


--
-- Name: mfa_amr_claims mfa_amr_claims_session_id_authentication_method_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT mfa_amr_claims_session_id_authentication_method_pkey UNIQUE (session_id, authentication_method);


--
-- Name: mfa_challenges mfa_challenges_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_challenges
    ADD CONSTRAINT mfa_challenges_pkey PRIMARY KEY (id);


--
-- Name: mfa_factors mfa_factors_last_challenged_at_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_last_challenged_at_key UNIQUE (last_challenged_at);


--
-- Name: mfa_factors mfa_factors_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_pkey PRIMARY KEY (id);


--
-- Name: oauth_authorizations oauth_authorizations_authorization_code_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_authorization_code_key UNIQUE (authorization_code);


--
-- Name: oauth_authorizations oauth_authorizations_authorization_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_authorization_id_key UNIQUE (authorization_id);


--
-- Name: oauth_authorizations oauth_authorizations_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_pkey PRIMARY KEY (id);


--
-- Name: oauth_client_states oauth_client_states_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_client_states
    ADD CONSTRAINT oauth_client_states_pkey PRIMARY KEY (id);


--
-- Name: oauth_clients oauth_clients_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_clients
    ADD CONSTRAINT oauth_clients_pkey PRIMARY KEY (id);


--
-- Name: oauth_consents oauth_consents_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_pkey PRIMARY KEY (id);


--
-- Name: oauth_consents oauth_consents_user_client_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_user_client_unique UNIQUE (user_id, client_id);


--
-- Name: one_time_tokens one_time_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.one_time_tokens
    ADD CONSTRAINT one_time_tokens_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_token_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_token_unique UNIQUE (token);


--
-- Name: saml_providers saml_providers_entity_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_entity_id_key UNIQUE (entity_id);


--
-- Name: saml_providers saml_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_pkey PRIMARY KEY (id);


--
-- Name: saml_relay_states saml_relay_states_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: sso_domains sso_domains_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_domains
    ADD CONSTRAINT sso_domains_pkey PRIMARY KEY (id);


--
-- Name: sso_providers sso_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_providers
    ADD CONSTRAINT sso_providers_pkey PRIMARY KEY (id);


--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: webauthn_challenges webauthn_challenges_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_challenges
    ADD CONSTRAINT webauthn_challenges_pkey PRIMARY KEY (id);


--
-- Name: webauthn_credentials webauthn_credentials_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_credentials
    ADD CONSTRAINT webauthn_credentials_pkey PRIMARY KEY (id);


--
-- Name: batch_materials batch_materials_batch_id_raw_material_id_material_lot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_materials
    ADD CONSTRAINT batch_materials_batch_id_raw_material_id_material_lot_id_key UNIQUE (batch_id, raw_material_id, material_lot_id);


--
-- Name: batch_materials batch_materials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_materials
    ADD CONSTRAINT batch_materials_pkey PRIMARY KEY (id);


--
-- Name: batch_outputs batch_outputs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_outputs
    ADD CONSTRAINT batch_outputs_pkey PRIMARY KEY (id);


--
-- Name: batch_requests batch_requests_batch_id_production_request_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_requests
    ADD CONSTRAINT batch_requests_batch_id_production_request_id_key UNIQUE (batch_id, production_request_id);


--
-- Name: batch_requests batch_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_requests
    ADD CONSTRAINT batch_requests_pkey PRIMARY KEY (id);


--
-- Name: brands brands_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brands
    ADD CONSTRAINT brands_pkey PRIMARY KEY (id);


--
-- Name: external_order_items external_order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_order_items
    ADD CONSTRAINT external_order_items_pkey PRIMARY KEY (id);


--
-- Name: external_orders external_orders_order_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_orders
    ADD CONSTRAINT external_orders_order_number_key UNIQUE (order_number);


--
-- Name: external_orders external_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_orders
    ADD CONSTRAINT external_orders_pkey PRIMARY KEY (id);


--
-- Name: material_lots material_lots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.material_lots
    ADD CONSTRAINT material_lots_pkey PRIMARY KEY (id);


--
-- Name: parent_batch_inputs parent_batch_inputs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parent_batch_inputs
    ADD CONSTRAINT parent_batch_inputs_pkey PRIMARY KEY (id);


--
-- Name: production_batches production_batches_batch_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.production_batches
    ADD CONSTRAINT production_batches_batch_code_key UNIQUE (batch_code);


--
-- Name: production_batches production_batches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.production_batches
    ADD CONSTRAINT production_batches_pkey PRIMARY KEY (id);


--
-- Name: production_days production_days_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.production_days
    ADD CONSTRAINT production_days_pkey PRIMARY KEY (id);


--
-- Name: production_days production_days_production_date_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.production_days
    ADD CONSTRAINT production_days_production_date_key UNIQUE (production_date);


--
-- Name: production_plan_items production_plan_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.production_plan_items
    ADD CONSTRAINT production_plan_items_pkey PRIMARY KEY (id);


--
-- Name: production_requests production_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.production_requests
    ADD CONSTRAINT production_requests_pkey PRIMARY KEY (id);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: raw_material_brands raw_material_brands_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.raw_material_brands
    ADD CONSTRAINT raw_material_brands_pkey PRIMARY KEY (id);


--
-- Name: raw_material_brands raw_material_brands_raw_material_id_brand_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.raw_material_brands
    ADD CONSTRAINT raw_material_brands_raw_material_id_brand_id_key UNIQUE (raw_material_id, brand_id);


--
-- Name: raw_materials raw_materials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.raw_materials
    ADD CONSTRAINT raw_materials_pkey PRIMARY KEY (id);


--
-- Name: recipe_ingredients recipe_ingredients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recipe_ingredients
    ADD CONSTRAINT recipe_ingredients_pkey PRIMARY KEY (id);


--
-- Name: recipe_ingredients recipe_ingredients_recipe_version_id_raw_material_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recipe_ingredients
    ADD CONSTRAINT recipe_ingredients_recipe_version_id_raw_material_id_key UNIQUE (recipe_version_id, raw_material_id);


--
-- Name: recipe_product_inputs recipe_product_inputs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recipe_product_inputs
    ADD CONSTRAINT recipe_product_inputs_pkey PRIMARY KEY (id);


--
-- Name: recipe_products recipe_products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recipe_products
    ADD CONSTRAINT recipe_products_pkey PRIMARY KEY (id);


--
-- Name: recipe_products recipe_products_recipe_id_product_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recipe_products
    ADD CONSTRAINT recipe_products_recipe_id_product_id_key UNIQUE (recipe_id, product_id);


--
-- Name: recipe_versions recipe_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recipe_versions
    ADD CONSTRAINT recipe_versions_pkey PRIMARY KEY (id);


--
-- Name: recipe_versions recipe_versions_recipe_id_version_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recipe_versions
    ADD CONSTRAINT recipe_versions_recipe_id_version_number_key UNIQUE (recipe_id, version_number);


--
-- Name: recipes recipes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recipes
    ADD CONSTRAINT recipes_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id, inserted_at);


--
-- Name: messages_2026_09_10 messages_2026_09_10_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages_2026_09_10
    ADD CONSTRAINT messages_2026_09_10_pkey PRIMARY KEY (id, inserted_at);


--
-- Name: messages_2026_09_11 messages_2026_09_11_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages_2026_09_11
    ADD CONSTRAINT messages_2026_09_11_pkey PRIMARY KEY (id, inserted_at);


--
-- Name: messages_2026_09_12 messages_2026_09_12_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages_2026_09_12
    ADD CONSTRAINT messages_2026_09_12_pkey PRIMARY KEY (id, inserted_at);


--
-- Name: messages_2026_09_13 messages_2026_09_13_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages_2026_09_13
    ADD CONSTRAINT messages_2026_09_13_pkey PRIMARY KEY (id, inserted_at);


--
-- Name: messages_2026_09_14 messages_2026_09_14_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages_2026_09_14
    ADD CONSTRAINT messages_2026_09_14_pkey PRIMARY KEY (id, inserted_at);


--
-- Name: messages_2026_09_15 messages_2026_09_15_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages_2026_09_15
    ADD CONSTRAINT messages_2026_09_15_pkey PRIMARY KEY (id, inserted_at);


--
-- Name: messages_2026_09_16 messages_2026_09_16_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages_2026_09_16
    ADD CONSTRAINT messages_2026_09_16_pkey PRIMARY KEY (id, inserted_at);


--
-- Name: messages messages_payload_exclusive; Type: CHECK CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE realtime.messages
    ADD CONSTRAINT messages_payload_exclusive CHECK (((payload IS NULL) OR (binary_payload IS NULL))) NOT VALID;


--
-- Name: subscription pk_subscription; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.subscription
    ADD CONSTRAINT pk_subscription PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: buckets_analytics buckets_analytics_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets_analytics
    ADD CONSTRAINT buckets_analytics_pkey PRIMARY KEY (id);


--
-- Name: buckets buckets_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets
    ADD CONSTRAINT buckets_pkey PRIMARY KEY (id);


--
-- Name: buckets_vectors buckets_vectors_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets_vectors
    ADD CONSTRAINT buckets_vectors_pkey PRIMARY KEY (id);


--
-- Name: iceberg_namespaces iceberg_namespaces_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.iceberg_namespaces
    ADD CONSTRAINT iceberg_namespaces_pkey PRIMARY KEY (id);


--
-- Name: iceberg_tables iceberg_tables_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.iceberg_tables
    ADD CONSTRAINT iceberg_tables_pkey PRIMARY KEY (id);


--
-- Name: migrations migrations_name_key; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.migrations
    ADD CONSTRAINT migrations_name_key UNIQUE (name);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (id);


--
-- Name: objects objects_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.objects
    ADD CONSTRAINT objects_pkey PRIMARY KEY (id);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_pkey PRIMARY KEY (id);


--
-- Name: s3_multipart_uploads s3_multipart_uploads_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads
    ADD CONSTRAINT s3_multipart_uploads_pkey PRIMARY KEY (id);


--
-- Name: vector_indexes vector_indexes_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.vector_indexes
    ADD CONSTRAINT vector_indexes_pkey PRIMARY KEY (id);


--
-- Name: hooks hooks_pkey; Type: CONSTRAINT; Schema: supabase_functions; Owner: -
--

ALTER TABLE ONLY supabase_functions.hooks
    ADD CONSTRAINT hooks_pkey PRIMARY KEY (id);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: supabase_functions; Owner: -
--

ALTER TABLE ONLY supabase_functions.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (version);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: supabase_migrations; Owner: -
--

ALTER TABLE ONLY supabase_migrations.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: extensions_tenant_external_id_index; Type: INDEX; Schema: _realtime; Owner: -
--

CREATE INDEX extensions_tenant_external_id_index ON _realtime.extensions USING btree (tenant_external_id);


--
-- Name: extensions_tenant_external_id_type_index; Type: INDEX; Schema: _realtime; Owner: -
--

CREATE UNIQUE INDEX extensions_tenant_external_id_type_index ON _realtime.extensions USING btree (tenant_external_id, type);


--
-- Name: feature_flags_name_index; Type: INDEX; Schema: _realtime; Owner: -
--

CREATE UNIQUE INDEX feature_flags_name_index ON _realtime.feature_flags USING btree (name);


--
-- Name: tenants_external_id_index; Type: INDEX; Schema: _realtime; Owner: -
--

CREATE UNIQUE INDEX tenants_external_id_index ON _realtime.tenants USING btree (external_id);


--
-- Name: audit_logs_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX audit_logs_instance_id_idx ON auth.audit_log_entries USING btree (instance_id);


--
-- Name: confirmation_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX confirmation_token_idx ON auth.users USING btree (confirmation_token) WHERE ((confirmation_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: custom_oauth_providers_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_created_at_idx ON auth.custom_oauth_providers USING btree (created_at);


--
-- Name: custom_oauth_providers_enabled_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_enabled_idx ON auth.custom_oauth_providers USING btree (enabled);


--
-- Name: custom_oauth_providers_identifier_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_identifier_idx ON auth.custom_oauth_providers USING btree (identifier);


--
-- Name: custom_oauth_providers_provider_type_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_provider_type_idx ON auth.custom_oauth_providers USING btree (provider_type);


--
-- Name: email_change_token_current_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX email_change_token_current_idx ON auth.users USING btree (email_change_token_current) WHERE ((email_change_token_current)::text !~ '^[0-9 ]*$'::text);


--
-- Name: email_change_token_new_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX email_change_token_new_idx ON auth.users USING btree (email_change_token_new) WHERE ((email_change_token_new)::text !~ '^[0-9 ]*$'::text);


--
-- Name: factor_id_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX factor_id_created_at_idx ON auth.mfa_factors USING btree (user_id, created_at);


--
-- Name: flow_state_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX flow_state_created_at_idx ON auth.flow_state USING btree (created_at DESC);


--
-- Name: identities_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX identities_email_idx ON auth.identities USING btree (email text_pattern_ops);


--
-- Name: INDEX identities_email_idx; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON INDEX auth.identities_email_idx IS 'Auth: Ensures indexed queries on the email column';


--
-- Name: identities_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX identities_user_id_idx ON auth.identities USING btree (user_id);


--
-- Name: idx_auth_code; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_auth_code ON auth.flow_state USING btree (auth_code);


--
-- Name: idx_oauth_client_states_created_at; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_oauth_client_states_created_at ON auth.oauth_client_states USING btree (created_at);


--
-- Name: idx_user_id_auth_method; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_user_id_auth_method ON auth.flow_state USING btree (user_id, authentication_method);


--
-- Name: mfa_challenge_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX mfa_challenge_created_at_idx ON auth.mfa_challenges USING btree (created_at DESC);


--
-- Name: mfa_factors_user_friendly_name_unique; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX mfa_factors_user_friendly_name_unique ON auth.mfa_factors USING btree (friendly_name, user_id) WHERE (TRIM(BOTH FROM friendly_name) <> ''::text);


--
-- Name: mfa_factors_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX mfa_factors_user_id_idx ON auth.mfa_factors USING btree (user_id);


--
-- Name: oauth_auth_pending_exp_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_auth_pending_exp_idx ON auth.oauth_authorizations USING btree (expires_at) WHERE (status = 'pending'::auth.oauth_authorization_status);


--
-- Name: oauth_clients_deleted_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_clients_deleted_at_idx ON auth.oauth_clients USING btree (deleted_at);


--
-- Name: oauth_consents_active_client_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_active_client_idx ON auth.oauth_consents USING btree (client_id) WHERE (revoked_at IS NULL);


--
-- Name: oauth_consents_active_user_client_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_active_user_client_idx ON auth.oauth_consents USING btree (user_id, client_id) WHERE (revoked_at IS NULL);


--
-- Name: oauth_consents_user_order_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_user_order_idx ON auth.oauth_consents USING btree (user_id, granted_at DESC);


--
-- Name: one_time_tokens_relates_to_hash_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX one_time_tokens_relates_to_hash_idx ON auth.one_time_tokens USING hash (relates_to);


--
-- Name: one_time_tokens_token_hash_hash_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX one_time_tokens_token_hash_hash_idx ON auth.one_time_tokens USING hash (token_hash);


--
-- Name: one_time_tokens_user_id_token_type_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX one_time_tokens_user_id_token_type_key ON auth.one_time_tokens USING btree (user_id, token_type);


--
-- Name: reauthentication_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX reauthentication_token_idx ON auth.users USING btree (reauthentication_token) WHERE ((reauthentication_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: recovery_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX recovery_token_idx ON auth.users USING btree (recovery_token) WHERE ((recovery_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: refresh_tokens_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_instance_id_idx ON auth.refresh_tokens USING btree (instance_id);


--
-- Name: refresh_tokens_instance_id_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_instance_id_user_id_idx ON auth.refresh_tokens USING btree (instance_id, user_id);


--
-- Name: refresh_tokens_parent_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_parent_idx ON auth.refresh_tokens USING btree (parent);


--
-- Name: refresh_tokens_session_id_revoked_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_session_id_revoked_idx ON auth.refresh_tokens USING btree (session_id, revoked);


--
-- Name: refresh_tokens_updated_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_updated_at_idx ON auth.refresh_tokens USING btree (updated_at DESC);


--
-- Name: saml_providers_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_providers_sso_provider_id_idx ON auth.saml_providers USING btree (sso_provider_id);


--
-- Name: saml_relay_states_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_created_at_idx ON auth.saml_relay_states USING btree (created_at DESC);


--
-- Name: saml_relay_states_for_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_for_email_idx ON auth.saml_relay_states USING btree (for_email);


--
-- Name: saml_relay_states_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_sso_provider_id_idx ON auth.saml_relay_states USING btree (sso_provider_id);


--
-- Name: sessions_not_after_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_not_after_idx ON auth.sessions USING btree (not_after DESC);


--
-- Name: sessions_oauth_client_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_oauth_client_id_idx ON auth.sessions USING btree (oauth_client_id);


--
-- Name: sessions_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_user_id_idx ON auth.sessions USING btree (user_id);


--
-- Name: sso_domains_domain_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX sso_domains_domain_idx ON auth.sso_domains USING btree (lower(domain));


--
-- Name: sso_domains_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sso_domains_sso_provider_id_idx ON auth.sso_domains USING btree (sso_provider_id);


--
-- Name: sso_providers_resource_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX sso_providers_resource_id_idx ON auth.sso_providers USING btree (lower(resource_id));


--
-- Name: sso_providers_resource_id_pattern_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sso_providers_resource_id_pattern_idx ON auth.sso_providers USING btree (resource_id text_pattern_ops);


--
-- Name: unique_phone_factor_per_user; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX unique_phone_factor_per_user ON auth.mfa_factors USING btree (user_id, phone);


--
-- Name: user_id_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX user_id_created_at_idx ON auth.sessions USING btree (user_id, created_at);


--
-- Name: users_email_partial_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX users_email_partial_key ON auth.users USING btree (email) WHERE (is_sso_user = false);


--
-- Name: INDEX users_email_partial_key; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON INDEX auth.users_email_partial_key IS 'Auth: A partial unique index that applies only when is_sso_user is false';


--
-- Name: users_instance_id_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_instance_id_email_idx ON auth.users USING btree (instance_id, lower((email)::text));


--
-- Name: users_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_instance_id_idx ON auth.users USING btree (instance_id);


--
-- Name: users_is_anonymous_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_is_anonymous_idx ON auth.users USING btree (is_anonymous);


--
-- Name: webauthn_challenges_expires_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX webauthn_challenges_expires_at_idx ON auth.webauthn_challenges USING btree (expires_at);


--
-- Name: webauthn_challenges_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX webauthn_challenges_user_id_idx ON auth.webauthn_challenges USING btree (user_id);


--
-- Name: webauthn_credentials_credential_id_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX webauthn_credentials_credential_id_key ON auth.webauthn_credentials USING btree (credential_id);


--
-- Name: webauthn_credentials_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX webauthn_credentials_user_id_idx ON auth.webauthn_credentials USING btree (user_id);


--
-- Name: material_lots_one_current_per_raw_material; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX material_lots_one_current_per_raw_material ON public.material_lots USING btree (raw_material_id) WHERE is_current;


--
-- Name: production_plan_items_one_active_per_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX production_plan_items_one_active_per_key ON public.production_plan_items USING btree (weekday, shift_code, product_id, unit) WHERE active;


--
-- Name: raw_materials_name_lower_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX raw_materials_name_lower_key ON public.raw_materials USING btree (lower(name));


--
-- Name: recipe_versions_one_active_per_recipe; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX recipe_versions_one_active_per_recipe ON public.recipe_versions USING btree (recipe_id) WHERE (status = 'active'::text);


--
-- Name: ix_realtime_subscription_entity; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX ix_realtime_subscription_entity ON realtime.subscription USING btree (entity);


--
-- Name: messages_inserted_at_topic_index; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX messages_inserted_at_topic_index ON ONLY realtime.messages USING btree (inserted_at DESC, topic) WHERE ((extension = 'broadcast'::text) AND (private IS TRUE));


--
-- Name: messages_2026_09_10_inserted_at_topic_idx; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX messages_2026_09_10_inserted_at_topic_idx ON realtime.messages_2026_09_10 USING btree (inserted_at DESC, topic) WHERE ((extension = 'broadcast'::text) AND (private IS TRUE));


--
-- Name: messages_2026_09_11_inserted_at_topic_idx; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX messages_2026_09_11_inserted_at_topic_idx ON realtime.messages_2026_09_11 USING btree (inserted_at DESC, topic) WHERE ((extension = 'broadcast'::text) AND (private IS TRUE));


--
-- Name: messages_2026_09_12_inserted_at_topic_idx; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX messages_2026_09_12_inserted_at_topic_idx ON realtime.messages_2026_09_12 USING btree (inserted_at DESC, topic) WHERE ((extension = 'broadcast'::text) AND (private IS TRUE));


--
-- Name: messages_2026_09_13_inserted_at_topic_idx; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX messages_2026_09_13_inserted_at_topic_idx ON realtime.messages_2026_09_13 USING btree (inserted_at DESC, topic) WHERE ((extension = 'broadcast'::text) AND (private IS TRUE));


--
-- Name: messages_2026_09_14_inserted_at_topic_idx; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX messages_2026_09_14_inserted_at_topic_idx ON realtime.messages_2026_09_14 USING btree (inserted_at DESC, topic) WHERE ((extension = 'broadcast'::text) AND (private IS TRUE));


--
-- Name: messages_2026_09_15_inserted_at_topic_idx; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX messages_2026_09_15_inserted_at_topic_idx ON realtime.messages_2026_09_15 USING btree (inserted_at DESC, topic) WHERE ((extension = 'broadcast'::text) AND (private IS TRUE));


--
-- Name: messages_2026_09_16_inserted_at_topic_idx; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX messages_2026_09_16_inserted_at_topic_idx ON realtime.messages_2026_09_16 USING btree (inserted_at DESC, topic) WHERE ((extension = 'broadcast'::text) AND (private IS TRUE));


--
-- Name: subscription_subscription_id_entity_filters_action_filter_selec; Type: INDEX; Schema: realtime; Owner: -
--

CREATE UNIQUE INDEX subscription_subscription_id_entity_filters_action_filter_selec ON realtime.subscription USING btree (subscription_id, entity, filters, action_filter, COALESCE(selected_columns, '{}'::text[]));


--
-- Name: bname; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX bname ON storage.buckets USING btree (name);


--
-- Name: bucketid_objname; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX bucketid_objname ON storage.objects USING btree (bucket_id, name);


--
-- Name: buckets_analytics_unique_name_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX buckets_analytics_unique_name_idx ON storage.buckets_analytics USING btree (name) WHERE (deleted_at IS NULL);


--
-- Name: idx_iceberg_namespaces_bucket_id; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX idx_iceberg_namespaces_bucket_id ON storage.iceberg_namespaces USING btree (catalog_id, name);


--
-- Name: idx_iceberg_tables_location; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX idx_iceberg_tables_location ON storage.iceberg_tables USING btree (location);


--
-- Name: idx_iceberg_tables_namespace_id; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX idx_iceberg_tables_namespace_id ON storage.iceberg_tables USING btree (catalog_id, namespace_id, name);


--
-- Name: idx_multipart_uploads_list; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_multipart_uploads_list ON storage.s3_multipart_uploads USING btree (bucket_id, key, created_at);


--
-- Name: idx_objects_bucket_id_name; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_objects_bucket_id_name ON storage.objects USING btree (bucket_id, name COLLATE "C");


--
-- Name: idx_objects_bucket_id_name_lower; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_objects_bucket_id_name_lower ON storage.objects USING btree (bucket_id, lower(name) COLLATE "C");


--
-- Name: idx_objects_current_version; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX idx_objects_current_version ON storage.objects USING btree (bucket_id, name) WHERE (archived_at IS NULL);


--
-- Name: idx_objects_null_version; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX idx_objects_null_version ON storage.objects USING btree (bucket_id, name) WHERE (NOT is_versioned);


--
-- Name: name_prefix_search; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX name_prefix_search ON storage.objects USING btree (name text_pattern_ops);


--
-- Name: objects_bucket_id_name_version_key; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX objects_bucket_id_name_version_key ON storage.objects USING btree (bucket_id, name, version) NULLS NOT DISTINCT;


--
-- Name: vector_indexes_name_bucket_id_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX vector_indexes_name_bucket_id_idx ON storage.vector_indexes USING btree (name, bucket_id);


--
-- Name: supabase_functions_hooks_h_table_id_h_name_idx; Type: INDEX; Schema: supabase_functions; Owner: -
--

CREATE INDEX supabase_functions_hooks_h_table_id_h_name_idx ON supabase_functions.hooks USING btree (hook_table_id, hook_name);


--
-- Name: supabase_functions_hooks_request_id_idx; Type: INDEX; Schema: supabase_functions; Owner: -
--

CREATE INDEX supabase_functions_hooks_request_id_idx ON supabase_functions.hooks USING btree (request_id);


--
-- Name: messages_2026_09_10_inserted_at_topic_idx; Type: INDEX ATTACH; Schema: realtime; Owner: -
--

ALTER INDEX realtime.messages_inserted_at_topic_index ATTACH PARTITION realtime.messages_2026_09_10_inserted_at_topic_idx;


--
-- Name: messages_2026_09_10_pkey; Type: INDEX ATTACH; Schema: realtime; Owner: -
--

ALTER INDEX realtime.messages_pkey ATTACH PARTITION realtime.messages_2026_09_10_pkey;


--
-- Name: messages_2026_09_11_inserted_at_topic_idx; Type: INDEX ATTACH; Schema: realtime; Owner: -
--

ALTER INDEX realtime.messages_inserted_at_topic_index ATTACH PARTITION realtime.messages_2026_09_11_inserted_at_topic_idx;


--
-- Name: messages_2026_09_11_pkey; Type: INDEX ATTACH; Schema: realtime; Owner: -
--

ALTER INDEX realtime.messages_pkey ATTACH PARTITION realtime.messages_2026_09_11_pkey;


--
-- Name: messages_2026_09_12_inserted_at_topic_idx; Type: INDEX ATTACH; Schema: realtime; Owner: -
--

ALTER INDEX realtime.messages_inserted_at_topic_index ATTACH PARTITION realtime.messages_2026_09_12_inserted_at_topic_idx;


--
-- Name: messages_2026_09_12_pkey; Type: INDEX ATTACH; Schema: realtime; Owner: -
--

ALTER INDEX realtime.messages_pkey ATTACH PARTITION realtime.messages_2026_09_12_pkey;


--
-- Name: messages_2026_09_13_inserted_at_topic_idx; Type: INDEX ATTACH; Schema: realtime; Owner: -
--

ALTER INDEX realtime.messages_inserted_at_topic_index ATTACH PARTITION realtime.messages_2026_09_13_inserted_at_topic_idx;


--
-- Name: messages_2026_09_13_pkey; Type: INDEX ATTACH; Schema: realtime; Owner: -
--

ALTER INDEX realtime.messages_pkey ATTACH PARTITION realtime.messages_2026_09_13_pkey;


--
-- Name: messages_2026_09_14_inserted_at_topic_idx; Type: INDEX ATTACH; Schema: realtime; Owner: -
--

ALTER INDEX realtime.messages_inserted_at_topic_index ATTACH PARTITION realtime.messages_2026_09_14_inserted_at_topic_idx;


--
-- Name: messages_2026_09_14_pkey; Type: INDEX ATTACH; Schema: realtime; Owner: -
--

ALTER INDEX realtime.messages_pkey ATTACH PARTITION realtime.messages_2026_09_14_pkey;


--
-- Name: messages_2026_09_15_inserted_at_topic_idx; Type: INDEX ATTACH; Schema: realtime; Owner: -
--

ALTER INDEX realtime.messages_inserted_at_topic_index ATTACH PARTITION realtime.messages_2026_09_15_inserted_at_topic_idx;


--
-- Name: messages_2026_09_15_pkey; Type: INDEX ATTACH; Schema: realtime; Owner: -
--

ALTER INDEX realtime.messages_pkey ATTACH PARTITION realtime.messages_2026_09_15_pkey;


--
-- Name: messages_2026_09_16_inserted_at_topic_idx; Type: INDEX ATTACH; Schema: realtime; Owner: -
--

ALTER INDEX realtime.messages_inserted_at_topic_index ATTACH PARTITION realtime.messages_2026_09_16_inserted_at_topic_idx;


--
-- Name: messages_2026_09_16_pkey; Type: INDEX ATTACH; Schema: realtime; Owner: -
--

ALTER INDEX realtime.messages_pkey ATTACH PARTITION realtime.messages_2026_09_16_pkey;


--
-- Name: parent_batch_inputs parent_batch_inputs_no_self_reference; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER parent_batch_inputs_no_self_reference BEFORE INSERT OR UPDATE OF child_batch_id, parent_batch_output_id ON public.parent_batch_inputs FOR EACH ROW EXECUTE FUNCTION public.reject_parent_batch_self_reference();


--
-- Name: subscription tr_check_filters; Type: TRIGGER; Schema: realtime; Owner: -
--

CREATE TRIGGER tr_check_filters BEFORE INSERT OR UPDATE ON realtime.subscription FOR EACH ROW EXECUTE FUNCTION realtime.subscription_check_filters();


--
-- Name: buckets enforce_bucket_name_length_trigger; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER enforce_bucket_name_length_trigger BEFORE INSERT OR UPDATE OF name ON storage.buckets FOR EACH ROW EXECUTE FUNCTION storage.enforce_bucket_name_length();


--
-- Name: buckets protect_buckets_delete; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER protect_buckets_delete BEFORE DELETE ON storage.buckets FOR EACH STATEMENT EXECUTE FUNCTION storage.protect_delete();


--
-- Name: objects protect_objects_delete; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER protect_objects_delete BEFORE DELETE ON storage.objects FOR EACH STATEMENT EXECUTE FUNCTION storage.protect_delete();


--
-- Name: objects update_objects_updated_at; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER update_objects_updated_at BEFORE UPDATE ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.update_updated_at_column();


--
-- Name: extensions extensions_tenant_external_id_fkey; Type: FK CONSTRAINT; Schema: _realtime; Owner: -
--

ALTER TABLE ONLY _realtime.extensions
    ADD CONSTRAINT extensions_tenant_external_id_fkey FOREIGN KEY (tenant_external_id) REFERENCES _realtime.tenants(external_id) ON DELETE CASCADE;


--
-- Name: identities identities_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: mfa_amr_claims mfa_amr_claims_session_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT mfa_amr_claims_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE;


--
-- Name: mfa_challenges mfa_challenges_auth_factor_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_challenges
    ADD CONSTRAINT mfa_challenges_auth_factor_id_fkey FOREIGN KEY (factor_id) REFERENCES auth.mfa_factors(id) ON DELETE CASCADE;


--
-- Name: mfa_factors mfa_factors_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: oauth_authorizations oauth_authorizations_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_authorizations oauth_authorizations_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: oauth_consents oauth_consents_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_consents oauth_consents_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: one_time_tokens one_time_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.one_time_tokens
    ADD CONSTRAINT one_time_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: refresh_tokens refresh_tokens_session_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE;


--
-- Name: saml_providers saml_providers_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: saml_relay_states saml_relay_states_flow_state_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_flow_state_id_fkey FOREIGN KEY (flow_state_id) REFERENCES auth.flow_state(id) ON DELETE CASCADE;


--
-- Name: saml_relay_states saml_relay_states_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_oauth_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_oauth_client_id_fkey FOREIGN KEY (oauth_client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: sso_domains sso_domains_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_domains
    ADD CONSTRAINT sso_domains_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: webauthn_challenges webauthn_challenges_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_challenges
    ADD CONSTRAINT webauthn_challenges_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: webauthn_credentials webauthn_credentials_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_credentials
    ADD CONSTRAINT webauthn_credentials_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: batch_materials batch_materials_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_materials
    ADD CONSTRAINT batch_materials_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.production_batches(id) ON DELETE RESTRICT;


--
-- Name: batch_materials batch_materials_material_lot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_materials
    ADD CONSTRAINT batch_materials_material_lot_id_fkey FOREIGN KEY (material_lot_id) REFERENCES public.material_lots(id) ON DELETE RESTRICT;


--
-- Name: batch_materials batch_materials_raw_material_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_materials
    ADD CONSTRAINT batch_materials_raw_material_id_fkey FOREIGN KEY (raw_material_id) REFERENCES public.raw_materials(id) ON DELETE RESTRICT;


--
-- Name: batch_outputs batch_outputs_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_outputs
    ADD CONSTRAINT batch_outputs_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.production_batches(id) ON DELETE RESTRICT;


--
-- Name: batch_outputs batch_outputs_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_outputs
    ADD CONSTRAINT batch_outputs_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT;


--
-- Name: batch_requests batch_requests_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_requests
    ADD CONSTRAINT batch_requests_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.production_batches(id) ON DELETE RESTRICT;


--
-- Name: batch_requests batch_requests_production_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_requests
    ADD CONSTRAINT batch_requests_production_request_id_fkey FOREIGN KEY (production_request_id) REFERENCES public.production_requests(id) ON DELETE RESTRICT;


--
-- Name: external_order_items external_order_items_external_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_order_items
    ADD CONSTRAINT external_order_items_external_order_id_fkey FOREIGN KEY (external_order_id) REFERENCES public.external_orders(id) ON DELETE RESTRICT;


--
-- Name: external_order_items external_order_items_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_order_items
    ADD CONSTRAINT external_order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT;


--
-- Name: external_orders external_orders_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_orders
    ADD CONSTRAINT external_orders_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: material_lots material_lots_brand_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.material_lots
    ADD CONSTRAINT material_lots_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.brands(id) ON DELETE RESTRICT;


--
-- Name: material_lots material_lots_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.material_lots
    ADD CONSTRAINT material_lots_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: material_lots material_lots_raw_material_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.material_lots
    ADD CONSTRAINT material_lots_raw_material_id_fkey FOREIGN KEY (raw_material_id) REFERENCES public.raw_materials(id) ON DELETE RESTRICT;


--
-- Name: parent_batch_inputs parent_batch_inputs_child_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parent_batch_inputs
    ADD CONSTRAINT parent_batch_inputs_child_batch_id_fkey FOREIGN KEY (child_batch_id) REFERENCES public.production_batches(id) ON DELETE RESTRICT;


--
-- Name: parent_batch_inputs parent_batch_inputs_parent_batch_output_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parent_batch_inputs
    ADD CONSTRAINT parent_batch_inputs_parent_batch_output_id_fkey FOREIGN KEY (parent_batch_output_id) REFERENCES public.batch_outputs(id) ON DELETE RESTRICT;


--
-- Name: production_batches production_batches_finished_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.production_batches
    ADD CONSTRAINT production_batches_finished_by_fkey FOREIGN KEY (finished_by) REFERENCES auth.users(id);


--
-- Name: production_batches production_batches_production_day_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.production_batches
    ADD CONSTRAINT production_batches_production_day_id_fkey FOREIGN KEY (production_day_id) REFERENCES public.production_days(id) ON DELETE RESTRICT;


--
-- Name: production_batches production_batches_recipe_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.production_batches
    ADD CONSTRAINT production_batches_recipe_version_id_fkey FOREIGN KEY (recipe_version_id) REFERENCES public.recipe_versions(id) ON DELETE RESTRICT;


--
-- Name: production_batches production_batches_started_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.production_batches
    ADD CONSTRAINT production_batches_started_by_fkey FOREIGN KEY (started_by) REFERENCES auth.users(id);


--
-- Name: production_days production_days_closed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.production_days
    ADD CONSTRAINT production_days_closed_by_fkey FOREIGN KEY (closed_by) REFERENCES auth.users(id);


--
-- Name: production_days production_days_opened_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.production_days
    ADD CONSTRAINT production_days_opened_by_fkey FOREIGN KEY (opened_by) REFERENCES auth.users(id);


--
-- Name: production_plan_items production_plan_items_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.production_plan_items
    ADD CONSTRAINT production_plan_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT;


--
-- Name: production_requests production_requests_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.production_requests
    ADD CONSTRAINT production_requests_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: production_requests production_requests_external_order_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.production_requests
    ADD CONSTRAINT production_requests_external_order_item_id_fkey FOREIGN KEY (external_order_item_id) REFERENCES public.external_order_items(id) ON DELETE RESTRICT;


--
-- Name: production_requests production_requests_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.production_requests
    ADD CONSTRAINT production_requests_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT;


--
-- Name: production_requests production_requests_production_day_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.production_requests
    ADD CONSTRAINT production_requests_production_day_id_fkey FOREIGN KEY (production_day_id) REFERENCES public.production_days(id) ON DELETE RESTRICT;


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: raw_material_brands raw_material_brands_brand_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.raw_material_brands
    ADD CONSTRAINT raw_material_brands_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.brands(id) ON DELETE RESTRICT;


--
-- Name: raw_material_brands raw_material_brands_raw_material_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.raw_material_brands
    ADD CONSTRAINT raw_material_brands_raw_material_id_fkey FOREIGN KEY (raw_material_id) REFERENCES public.raw_materials(id) ON DELETE RESTRICT;


--
-- Name: recipe_ingredients recipe_ingredients_raw_material_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recipe_ingredients
    ADD CONSTRAINT recipe_ingredients_raw_material_id_fkey FOREIGN KEY (raw_material_id) REFERENCES public.raw_materials(id) ON DELETE RESTRICT;


--
-- Name: recipe_ingredients recipe_ingredients_recipe_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recipe_ingredients
    ADD CONSTRAINT recipe_ingredients_recipe_version_id_fkey FOREIGN KEY (recipe_version_id) REFERENCES public.recipe_versions(id) ON DELETE RESTRICT;


--
-- Name: recipe_product_inputs recipe_product_inputs_recipe_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recipe_product_inputs
    ADD CONSTRAINT recipe_product_inputs_recipe_version_id_fkey FOREIGN KEY (recipe_version_id) REFERENCES public.recipe_versions(id) ON DELETE RESTRICT;


--
-- Name: recipe_product_inputs recipe_product_inputs_source_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recipe_product_inputs
    ADD CONSTRAINT recipe_product_inputs_source_product_id_fkey FOREIGN KEY (source_product_id) REFERENCES public.products(id) ON DELETE RESTRICT;


--
-- Name: recipe_products recipe_products_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recipe_products
    ADD CONSTRAINT recipe_products_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT;


--
-- Name: recipe_products recipe_products_recipe_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recipe_products
    ADD CONSTRAINT recipe_products_recipe_id_fkey FOREIGN KEY (recipe_id) REFERENCES public.recipes(id) ON DELETE RESTRICT;


--
-- Name: recipe_versions recipe_versions_recipe_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recipe_versions
    ADD CONSTRAINT recipe_versions_recipe_id_fkey FOREIGN KEY (recipe_id) REFERENCES public.recipes(id) ON DELETE RESTRICT;


--
-- Name: iceberg_namespaces iceberg_namespaces_catalog_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.iceberg_namespaces
    ADD CONSTRAINT iceberg_namespaces_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES storage.buckets_analytics(id) ON DELETE CASCADE;


--
-- Name: iceberg_tables iceberg_tables_catalog_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.iceberg_tables
    ADD CONSTRAINT iceberg_tables_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES storage.buckets_analytics(id) ON DELETE CASCADE;


--
-- Name: iceberg_tables iceberg_tables_namespace_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.iceberg_tables
    ADD CONSTRAINT iceberg_tables_namespace_id_fkey FOREIGN KEY (namespace_id) REFERENCES storage.iceberg_namespaces(id) ON DELETE CASCADE;


--
-- Name: objects objects_bucketId_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.objects
    ADD CONSTRAINT "objects_bucketId_fkey" FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads s3_multipart_uploads_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads
    ADD CONSTRAINT s3_multipart_uploads_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_upload_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_upload_id_fkey FOREIGN KEY (upload_id) REFERENCES storage.s3_multipart_uploads(id) ON DELETE CASCADE;


--
-- Name: vector_indexes vector_indexes_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.vector_indexes
    ADD CONSTRAINT vector_indexes_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets_vectors(id);


--
-- Name: audit_log_entries; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.audit_log_entries ENABLE ROW LEVEL SECURITY;

--
-- Name: flow_state; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.flow_state ENABLE ROW LEVEL SECURITY;

--
-- Name: identities; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.identities ENABLE ROW LEVEL SECURITY;

--
-- Name: instances; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.instances ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_amr_claims; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_amr_claims ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_challenges; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_challenges ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_factors; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_factors ENABLE ROW LEVEL SECURITY;

--
-- Name: one_time_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.one_time_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: refresh_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.refresh_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: saml_providers; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.saml_providers ENABLE ROW LEVEL SECURITY;

--
-- Name: saml_relay_states; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.saml_relay_states ENABLE ROW LEVEL SECURITY;

--
-- Name: schema_migrations; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.schema_migrations ENABLE ROW LEVEL SECURITY;

--
-- Name: sessions; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: sso_domains; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sso_domains ENABLE ROW LEVEL SECURITY;

--
-- Name: sso_providers; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sso_providers ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;

--
-- Name: batch_materials; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.batch_materials ENABLE ROW LEVEL SECURITY;

--
-- Name: batch_materials batch_materials_select_active; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY batch_materials_select_active ON public.batch_materials FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles p
  WHERE ((p.id = auth.uid()) AND p.active))));


--
-- Name: batch_outputs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.batch_outputs ENABLE ROW LEVEL SECURITY;

--
-- Name: batch_outputs batch_outputs_select_active; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY batch_outputs_select_active ON public.batch_outputs FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles p
  WHERE ((p.id = auth.uid()) AND p.active))));


--
-- Name: batch_requests; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.batch_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: batch_requests batch_requests_select_active; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY batch_requests_select_active ON public.batch_requests FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles p
  WHERE ((p.id = auth.uid()) AND p.active))));


--
-- Name: brands; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.brands ENABLE ROW LEVEL SECURITY;

--
-- Name: brands brands_select_active; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY brands_select_active ON public.brands FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles p
  WHERE ((p.id = auth.uid()) AND p.active))));


--
-- Name: external_order_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.external_order_items ENABLE ROW LEVEL SECURITY;

--
-- Name: external_order_items external_order_items_select_active; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY external_order_items_select_active ON public.external_order_items FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles p
  WHERE ((p.id = auth.uid()) AND p.active))));


--
-- Name: external_orders; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.external_orders ENABLE ROW LEVEL SECURITY;

--
-- Name: external_orders external_orders_select_active; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY external_orders_select_active ON public.external_orders FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles p
  WHERE ((p.id = auth.uid()) AND p.active))));


--
-- Name: material_lots; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.material_lots ENABLE ROW LEVEL SECURITY;

--
-- Name: material_lots material_lots_select_active; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY material_lots_select_active ON public.material_lots FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles p
  WHERE ((p.id = auth.uid()) AND p.active))));


--
-- Name: parent_batch_inputs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.parent_batch_inputs ENABLE ROW LEVEL SECURITY;

--
-- Name: parent_batch_inputs parent_batch_inputs_select_active; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY parent_batch_inputs_select_active ON public.parent_batch_inputs FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles p
  WHERE ((p.id = auth.uid()) AND p.active))));


--
-- Name: production_batches; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.production_batches ENABLE ROW LEVEL SECURITY;

--
-- Name: production_batches production_batches_select_active; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY production_batches_select_active ON public.production_batches FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles p
  WHERE ((p.id = auth.uid()) AND p.active))));


--
-- Name: production_days; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.production_days ENABLE ROW LEVEL SECURITY;

--
-- Name: production_days production_days_select_active; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY production_days_select_active ON public.production_days FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles p
  WHERE ((p.id = auth.uid()) AND p.active))));


--
-- Name: production_plan_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.production_plan_items ENABLE ROW LEVEL SECURITY;

--
-- Name: production_plan_items production_plan_items_select_active; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY production_plan_items_select_active ON public.production_plan_items FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles p
  WHERE ((p.id = auth.uid()) AND p.active))));


--
-- Name: production_requests; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.production_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: production_requests production_requests_select_active; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY production_requests_select_active ON public.production_requests FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles p
  WHERE ((p.id = auth.uid()) AND p.active))));


--
-- Name: products; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

--
-- Name: products products_select_active; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY products_select_active ON public.products FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles p
  WHERE ((p.id = auth.uid()) AND p.active))));


--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles profiles_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profiles_select_own ON public.profiles FOR SELECT TO authenticated USING ((id = auth.uid()));


--
-- Name: raw_material_brands; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.raw_material_brands ENABLE ROW LEVEL SECURITY;

--
-- Name: raw_material_brands raw_material_brands_select_active; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY raw_material_brands_select_active ON public.raw_material_brands FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles p
  WHERE ((p.id = auth.uid()) AND p.active))));


--
-- Name: raw_materials; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.raw_materials ENABLE ROW LEVEL SECURITY;

--
-- Name: raw_materials raw_materials_select_active; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY raw_materials_select_active ON public.raw_materials FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles p
  WHERE ((p.id = auth.uid()) AND p.active))));


--
-- Name: recipe_ingredients; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.recipe_ingredients ENABLE ROW LEVEL SECURITY;

--
-- Name: recipe_ingredients recipe_ingredients_select_active; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY recipe_ingredients_select_active ON public.recipe_ingredients FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles p
  WHERE ((p.id = auth.uid()) AND p.active))));


--
-- Name: recipe_product_inputs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.recipe_product_inputs ENABLE ROW LEVEL SECURITY;

--
-- Name: recipe_product_inputs recipe_product_inputs_select_active; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY recipe_product_inputs_select_active ON public.recipe_product_inputs FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles p
  WHERE ((p.id = auth.uid()) AND p.active))));


--
-- Name: recipe_products; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.recipe_products ENABLE ROW LEVEL SECURITY;

--
-- Name: recipe_products recipe_products_select_active; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY recipe_products_select_active ON public.recipe_products FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles p
  WHERE ((p.id = auth.uid()) AND p.active))));


--
-- Name: recipe_versions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.recipe_versions ENABLE ROW LEVEL SECURITY;

--
-- Name: recipe_versions recipe_versions_select_active; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY recipe_versions_select_active ON public.recipe_versions FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles p
  WHERE ((p.id = auth.uid()) AND p.active))));


--
-- Name: recipes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.recipes ENABLE ROW LEVEL SECURITY;

--
-- Name: recipes recipes_select_active; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY recipes_select_active ON public.recipes FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles p
  WHERE ((p.id = auth.uid()) AND p.active))));


--
-- Name: messages; Type: ROW SECURITY; Schema: realtime; Owner: -
--

ALTER TABLE realtime.messages ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets_analytics; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets_analytics ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets_vectors; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets_vectors ENABLE ROW LEVEL SECURITY;

--
-- Name: iceberg_namespaces; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.iceberg_namespaces ENABLE ROW LEVEL SECURITY;

--
-- Name: iceberg_tables; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.iceberg_tables ENABLE ROW LEVEL SECURITY;

--
-- Name: migrations; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.migrations ENABLE ROW LEVEL SECURITY;

--
-- Name: objects; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

--
-- Name: s3_multipart_uploads; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.s3_multipart_uploads ENABLE ROW LEVEL SECURITY;

--
-- Name: s3_multipart_uploads_parts; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.s3_multipart_uploads_parts ENABLE ROW LEVEL SECURITY;

--
-- Name: vector_indexes; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.vector_indexes ENABLE ROW LEVEL SECURITY;

--
-- Name: supabase_realtime; Type: PUBLICATION; Schema: -; Owner: -
--

CREATE PUBLICATION supabase_realtime WITH (publish = 'insert, update, delete, truncate');


--
-- Name: SCHEMA auth; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA auth TO anon;
GRANT USAGE ON SCHEMA auth TO authenticated;
GRANT USAGE ON SCHEMA auth TO service_role;
GRANT ALL ON SCHEMA auth TO supabase_auth_admin;
GRANT ALL ON SCHEMA auth TO dashboard_user;
GRANT USAGE ON SCHEMA auth TO postgres;


--
-- Name: SCHEMA extensions; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA extensions TO anon;
GRANT USAGE ON SCHEMA extensions TO authenticated;
GRANT USAGE ON SCHEMA extensions TO service_role;
GRANT ALL ON SCHEMA extensions TO dashboard_user;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- Name: SCHEMA realtime; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA realtime TO postgres WITH GRANT OPTION;
GRANT USAGE ON SCHEMA realtime TO anon;
GRANT USAGE ON SCHEMA realtime TO service_role;
GRANT ALL ON SCHEMA realtime TO supabase_realtime_admin WITH GRANT OPTION;
GRANT USAGE ON SCHEMA realtime TO authenticated;


--
-- Name: SCHEMA storage; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA storage TO postgres WITH GRANT OPTION;
GRANT USAGE ON SCHEMA storage TO anon;
GRANT USAGE ON SCHEMA storage TO authenticated;
GRANT USAGE ON SCHEMA storage TO service_role;
GRANT ALL ON SCHEMA storage TO supabase_storage_admin WITH GRANT OPTION;
GRANT ALL ON SCHEMA storage TO dashboard_user;


--
-- Name: SCHEMA supabase_functions; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA supabase_functions TO postgres;
GRANT USAGE ON SCHEMA supabase_functions TO anon;
GRANT USAGE ON SCHEMA supabase_functions TO authenticated;
GRANT USAGE ON SCHEMA supabase_functions TO service_role;
GRANT ALL ON SCHEMA supabase_functions TO supabase_functions_admin;


--
-- Name: SCHEMA vault; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA vault TO postgres WITH GRANT OPTION;
GRANT USAGE ON SCHEMA vault TO service_role;


--
-- Name: FUNCTION email(); Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON FUNCTION auth.email() TO dashboard_user;


--
-- Name: FUNCTION jwt(); Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON FUNCTION auth.jwt() TO postgres;
GRANT ALL ON FUNCTION auth.jwt() TO dashboard_user;


--
-- Name: FUNCTION role(); Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON FUNCTION auth.role() TO dashboard_user;


--
-- Name: FUNCTION uid(); Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON FUNCTION auth.uid() TO dashboard_user;


--
-- Name: FUNCTION armor(bytea); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.armor(bytea) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.armor(bytea) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION armor(bytea, text[], text[]); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.armor(bytea, text[], text[]) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.armor(bytea, text[], text[]) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION crypt(text, text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.crypt(text, text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.crypt(text, text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION dearmor(text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.dearmor(text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.dearmor(text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION decrypt(bytea, bytea, text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.decrypt(bytea, bytea, text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.decrypt(bytea, bytea, text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION decrypt_iv(bytea, bytea, bytea, text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.decrypt_iv(bytea, bytea, bytea, text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.decrypt_iv(bytea, bytea, bytea, text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION digest(bytea, text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.digest(bytea, text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.digest(bytea, text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION digest(text, text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.digest(text, text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.digest(text, text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION encrypt(bytea, bytea, text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.encrypt(bytea, bytea, text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.encrypt(bytea, bytea, text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION encrypt_iv(bytea, bytea, bytea, text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.encrypt_iv(bytea, bytea, bytea, text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.encrypt_iv(bytea, bytea, bytea, text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION gen_random_bytes(integer); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.gen_random_bytes(integer) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.gen_random_bytes(integer) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION gen_random_uuid(); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.gen_random_uuid() TO dashboard_user;
GRANT ALL ON FUNCTION extensions.gen_random_uuid() TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION gen_salt(text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.gen_salt(text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.gen_salt(text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION gen_salt(text, integer); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.gen_salt(text, integer) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.gen_salt(text, integer) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION grant_pg_cron_access(); Type: ACL; Schema: extensions; Owner: -
--

REVOKE ALL ON FUNCTION extensions.grant_pg_cron_access() FROM supabase_admin;
GRANT ALL ON FUNCTION extensions.grant_pg_cron_access() TO supabase_admin WITH GRANT OPTION;
GRANT ALL ON FUNCTION extensions.grant_pg_cron_access() TO dashboard_user;


--
-- Name: FUNCTION grant_pg_graphql_access(); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.grant_pg_graphql_access() TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION grant_pg_net_access(); Type: ACL; Schema: extensions; Owner: -
--

REVOKE ALL ON FUNCTION extensions.grant_pg_net_access() FROM supabase_admin;
GRANT ALL ON FUNCTION extensions.grant_pg_net_access() TO supabase_admin WITH GRANT OPTION;
GRANT ALL ON FUNCTION extensions.grant_pg_net_access() TO dashboard_user;


--
-- Name: FUNCTION hmac(bytea, bytea, text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.hmac(bytea, bytea, text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.hmac(bytea, bytea, text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION hmac(text, text, text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.hmac(text, text, text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.hmac(text, text, text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION pg_stat_statements(showtext boolean, OUT userid oid, OUT dbid oid, OUT toplevel boolean, OUT queryid bigint, OUT query text, OUT plans bigint, OUT total_plan_time double precision, OUT min_plan_time double precision, OUT max_plan_time double precision, OUT mean_plan_time double precision, OUT stddev_plan_time double precision, OUT calls bigint, OUT total_exec_time double precision, OUT min_exec_time double precision, OUT max_exec_time double precision, OUT mean_exec_time double precision, OUT stddev_exec_time double precision, OUT rows bigint, OUT shared_blks_hit bigint, OUT shared_blks_read bigint, OUT shared_blks_dirtied bigint, OUT shared_blks_written bigint, OUT local_blks_hit bigint, OUT local_blks_read bigint, OUT local_blks_dirtied bigint, OUT local_blks_written bigint, OUT temp_blks_read bigint, OUT temp_blks_written bigint, OUT shared_blk_read_time double precision, OUT shared_blk_write_time double precision, OUT local_blk_read_time double precision, OUT local_blk_write_time double precision, OUT temp_blk_read_time double precision, OUT temp_blk_write_time double precision, OUT wal_records bigint, OUT wal_fpi bigint, OUT wal_bytes numeric, OUT jit_functions bigint, OUT jit_generation_time double precision, OUT jit_inlining_count bigint, OUT jit_inlining_time double precision, OUT jit_optimization_count bigint, OUT jit_optimization_time double precision, OUT jit_emission_count bigint, OUT jit_emission_time double precision, OUT jit_deform_count bigint, OUT jit_deform_time double precision, OUT stats_since timestamp with time zone, OUT minmax_stats_since timestamp with time zone); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.pg_stat_statements(showtext boolean, OUT userid oid, OUT dbid oid, OUT toplevel boolean, OUT queryid bigint, OUT query text, OUT plans bigint, OUT total_plan_time double precision, OUT min_plan_time double precision, OUT max_plan_time double precision, OUT mean_plan_time double precision, OUT stddev_plan_time double precision, OUT calls bigint, OUT total_exec_time double precision, OUT min_exec_time double precision, OUT max_exec_time double precision, OUT mean_exec_time double precision, OUT stddev_exec_time double precision, OUT rows bigint, OUT shared_blks_hit bigint, OUT shared_blks_read bigint, OUT shared_blks_dirtied bigint, OUT shared_blks_written bigint, OUT local_blks_hit bigint, OUT local_blks_read bigint, OUT local_blks_dirtied bigint, OUT local_blks_written bigint, OUT temp_blks_read bigint, OUT temp_blks_written bigint, OUT shared_blk_read_time double precision, OUT shared_blk_write_time double precision, OUT local_blk_read_time double precision, OUT local_blk_write_time double precision, OUT temp_blk_read_time double precision, OUT temp_blk_write_time double precision, OUT wal_records bigint, OUT wal_fpi bigint, OUT wal_bytes numeric, OUT jit_functions bigint, OUT jit_generation_time double precision, OUT jit_inlining_count bigint, OUT jit_inlining_time double precision, OUT jit_optimization_count bigint, OUT jit_optimization_time double precision, OUT jit_emission_count bigint, OUT jit_emission_time double precision, OUT jit_deform_count bigint, OUT jit_deform_time double precision, OUT stats_since timestamp with time zone, OUT minmax_stats_since timestamp with time zone) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION pg_stat_statements_info(OUT dealloc bigint, OUT stats_reset timestamp with time zone); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.pg_stat_statements_info(OUT dealloc bigint, OUT stats_reset timestamp with time zone) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION pg_stat_statements_reset(userid oid, dbid oid, queryid bigint, minmax_only boolean); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.pg_stat_statements_reset(userid oid, dbid oid, queryid bigint, minmax_only boolean) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION pgp_armor_headers(text, OUT key text, OUT value text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.pgp_armor_headers(text, OUT key text, OUT value text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.pgp_armor_headers(text, OUT key text, OUT value text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION pgp_key_id(bytea); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.pgp_key_id(bytea) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.pgp_key_id(bytea) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION pgp_pub_decrypt(bytea, bytea); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.pgp_pub_decrypt(bytea, bytea) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.pgp_pub_decrypt(bytea, bytea) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION pgp_pub_decrypt(bytea, bytea, text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.pgp_pub_decrypt(bytea, bytea, text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.pgp_pub_decrypt(bytea, bytea, text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION pgp_pub_decrypt(bytea, bytea, text, text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.pgp_pub_decrypt(bytea, bytea, text, text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.pgp_pub_decrypt(bytea, bytea, text, text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION pgp_pub_decrypt_bytea(bytea, bytea); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.pgp_pub_decrypt_bytea(bytea, bytea) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.pgp_pub_decrypt_bytea(bytea, bytea) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION pgp_pub_decrypt_bytea(bytea, bytea, text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.pgp_pub_decrypt_bytea(bytea, bytea, text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.pgp_pub_decrypt_bytea(bytea, bytea, text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION pgp_pub_decrypt_bytea(bytea, bytea, text, text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.pgp_pub_decrypt_bytea(bytea, bytea, text, text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.pgp_pub_decrypt_bytea(bytea, bytea, text, text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION pgp_pub_encrypt(text, bytea); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.pgp_pub_encrypt(text, bytea) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.pgp_pub_encrypt(text, bytea) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION pgp_pub_encrypt(text, bytea, text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.pgp_pub_encrypt(text, bytea, text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.pgp_pub_encrypt(text, bytea, text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION pgp_pub_encrypt_bytea(bytea, bytea); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.pgp_pub_encrypt_bytea(bytea, bytea) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.pgp_pub_encrypt_bytea(bytea, bytea) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION pgp_pub_encrypt_bytea(bytea, bytea, text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.pgp_pub_encrypt_bytea(bytea, bytea, text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.pgp_pub_encrypt_bytea(bytea, bytea, text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION pgp_sym_decrypt(bytea, text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.pgp_sym_decrypt(bytea, text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.pgp_sym_decrypt(bytea, text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION pgp_sym_decrypt(bytea, text, text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.pgp_sym_decrypt(bytea, text, text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.pgp_sym_decrypt(bytea, text, text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION pgp_sym_decrypt_bytea(bytea, text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.pgp_sym_decrypt_bytea(bytea, text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.pgp_sym_decrypt_bytea(bytea, text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION pgp_sym_decrypt_bytea(bytea, text, text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.pgp_sym_decrypt_bytea(bytea, text, text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.pgp_sym_decrypt_bytea(bytea, text, text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION pgp_sym_encrypt(text, text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.pgp_sym_encrypt(text, text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.pgp_sym_encrypt(text, text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION pgp_sym_encrypt(text, text, text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.pgp_sym_encrypt(text, text, text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.pgp_sym_encrypt(text, text, text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION pgp_sym_encrypt_bytea(bytea, text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.pgp_sym_encrypt_bytea(bytea, text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.pgp_sym_encrypt_bytea(bytea, text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION pgp_sym_encrypt_bytea(bytea, text, text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.pgp_sym_encrypt_bytea(bytea, text, text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.pgp_sym_encrypt_bytea(bytea, text, text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION pgrst_ddl_watch(); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.pgrst_ddl_watch() TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION pgrst_drop_watch(); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.pgrst_drop_watch() TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION set_graphql_placeholder(); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.set_graphql_placeholder() TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION uuid_generate_v1(); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.uuid_generate_v1() TO dashboard_user;
GRANT ALL ON FUNCTION extensions.uuid_generate_v1() TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION uuid_generate_v1mc(); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.uuid_generate_v1mc() TO dashboard_user;
GRANT ALL ON FUNCTION extensions.uuid_generate_v1mc() TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION uuid_generate_v3(namespace uuid, name text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.uuid_generate_v3(namespace uuid, name text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.uuid_generate_v3(namespace uuid, name text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION uuid_generate_v4(); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.uuid_generate_v4() TO dashboard_user;
GRANT ALL ON FUNCTION extensions.uuid_generate_v4() TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION uuid_generate_v5(namespace uuid, name text); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.uuid_generate_v5(namespace uuid, name text) TO dashboard_user;
GRANT ALL ON FUNCTION extensions.uuid_generate_v5(namespace uuid, name text) TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION uuid_nil(); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.uuid_nil() TO dashboard_user;
GRANT ALL ON FUNCTION extensions.uuid_nil() TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION uuid_ns_dns(); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.uuid_ns_dns() TO dashboard_user;
GRANT ALL ON FUNCTION extensions.uuid_ns_dns() TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION uuid_ns_oid(); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.uuid_ns_oid() TO dashboard_user;
GRANT ALL ON FUNCTION extensions.uuid_ns_oid() TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION uuid_ns_url(); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.uuid_ns_url() TO dashboard_user;
GRANT ALL ON FUNCTION extensions.uuid_ns_url() TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION uuid_ns_x500(); Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON FUNCTION extensions.uuid_ns_x500() TO dashboard_user;
GRANT ALL ON FUNCTION extensions.uuid_ns_x500() TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION graphql("operationName" text, query text, variables jsonb, extensions jsonb); Type: ACL; Schema: graphql_public; Owner: -
--

GRANT ALL ON FUNCTION graphql_public.graphql("operationName" text, query text, variables jsonb, extensions jsonb) TO postgres;
GRANT ALL ON FUNCTION graphql_public.graphql("operationName" text, query text, variables jsonb, extensions jsonb) TO anon;
GRANT ALL ON FUNCTION graphql_public.graphql("operationName" text, query text, variables jsonb, extensions jsonb) TO authenticated;
GRANT ALL ON FUNCTION graphql_public.graphql("operationName" text, query text, variables jsonb, extensions jsonb) TO service_role;


--
-- Name: FUNCTION pg_reload_conf(); Type: ACL; Schema: pg_catalog; Owner: -
--

GRANT ALL ON FUNCTION pg_catalog.pg_reload_conf() TO postgres WITH GRANT OPTION;


--
-- Name: FUNCTION get_auth(p_usename text); Type: ACL; Schema: pgbouncer; Owner: -
--

REVOKE ALL ON FUNCTION pgbouncer.get_auth(p_usename text) FROM PUBLIC;
GRANT ALL ON FUNCTION pgbouncer.get_auth(p_usename text) TO pgbouncer;


--
-- Name: FUNCTION add_external_order_item(p_external_order_id uuid, p_product_id uuid, p_quantity numeric, p_unit text, p_shift_code text, p_notes text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.add_external_order_item(p_external_order_id uuid, p_product_id uuid, p_quantity numeric, p_unit text, p_shift_code text, p_notes text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.add_external_order_item(p_external_order_id uuid, p_product_id uuid, p_quantity numeric, p_unit text, p_shift_code text, p_notes text) TO authenticated;


--
-- Name: FUNCTION change_current_material_lot(p_raw_material_id uuid, p_brand_id uuid, p_supplier_lot text, p_expiry_date date); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.change_current_material_lot(p_raw_material_id uuid, p_brand_id uuid, p_supplier_lot text, p_expiry_date date) FROM PUBLIC;
GRANT ALL ON FUNCTION public.change_current_material_lot(p_raw_material_id uuid, p_brand_id uuid, p_supplier_lot text, p_expiry_date date) TO authenticated;


--
-- Name: FUNCTION complete_multi_output_batch(p_batch_id uuid, p_outputs jsonb); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.complete_multi_output_batch(p_batch_id uuid, p_outputs jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION public.complete_multi_output_batch(p_batch_id uuid, p_outputs jsonb) TO postgres;
GRANT ALL ON FUNCTION public.complete_multi_output_batch(p_batch_id uuid, p_outputs jsonb) TO authenticated;


--
-- Name: FUNCTION complete_production_batch(p_batch_id uuid, p_actual_quantity numeric, p_unit text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.complete_production_batch(p_batch_id uuid, p_actual_quantity numeric, p_unit text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.complete_production_batch(p_batch_id uuid, p_actual_quantity numeric, p_unit text) TO authenticated;


--
-- Name: FUNCTION create_additional_production_request(p_production_day_id uuid, p_product_id uuid, p_requested_quantity numeric, p_unit text, p_shift_code text, p_reason_code text, p_reason_note text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.create_additional_production_request(p_production_day_id uuid, p_product_id uuid, p_requested_quantity numeric, p_unit text, p_shift_code text, p_reason_code text, p_reason_note text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.create_additional_production_request(p_production_day_id uuid, p_product_id uuid, p_requested_quantity numeric, p_unit text, p_shift_code text, p_reason_code text, p_reason_note text) TO authenticated;


--
-- Name: FUNCTION create_brand(p_name text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.create_brand(p_name text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.create_brand(p_name text) TO authenticated;


--
-- Name: FUNCTION create_external_order(p_order_number text, p_customer_name text, p_requested_date date, p_delivery_time text, p_notes text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.create_external_order(p_order_number text, p_customer_name text, p_requested_date date, p_delivery_time text, p_notes text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.create_external_order(p_order_number text, p_customer_name text, p_requested_date date, p_delivery_time text, p_notes text) TO authenticated;


--
-- Name: FUNCTION create_product(p_name text, p_default_unit text, p_default_shift_code text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.create_product(p_name text, p_default_unit text, p_default_shift_code text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.create_product(p_name text, p_default_unit text, p_default_shift_code text) TO authenticated;


--
-- Name: FUNCTION create_production_plan_item(p_weekday smallint, p_shift_code text, p_product_id uuid, p_planned_quantity numeric, p_unit text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.create_production_plan_item(p_weekday smallint, p_shift_code text, p_product_id uuid, p_planned_quantity numeric, p_unit text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.create_production_plan_item(p_weekday smallint, p_shift_code text, p_product_id uuid, p_planned_quantity numeric, p_unit text) TO authenticated;


--
-- Name: FUNCTION create_raw_material(p_name text, p_default_unit text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.create_raw_material(p_name text, p_default_unit text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.create_raw_material(p_name text, p_default_unit text) TO authenticated;


--
-- Name: FUNCTION create_recipe(p_name text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.create_recipe(p_name text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.create_recipe(p_name text) TO authenticated;


--
-- Name: FUNCTION ensure_base_production_requests(p_production_day_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.ensure_base_production_requests(p_production_day_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.ensure_base_production_requests(p_production_day_id uuid) TO authenticated;


--
-- Name: FUNCTION ensure_external_order_requests(p_production_day_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.ensure_external_order_requests(p_production_day_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.ensure_external_order_requests(p_production_day_id uuid) TO authenticated;


--
-- Name: FUNCTION ensure_production_day(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.ensure_production_day() FROM PUBLIC;
GRANT ALL ON FUNCTION public.ensure_production_day() TO authenticated;


--
-- Name: FUNCTION get_business_date(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.get_business_date() FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_business_date() TO authenticated;


--
-- Name: FUNCTION next_batch_code(p_production_day_id uuid, p_shift_code text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.next_batch_code(p_production_day_id uuid, p_shift_code text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.next_batch_code(p_production_day_id uuid, p_shift_code text) TO authenticated;


--
-- Name: FUNCTION reject_parent_batch_self_reference(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.reject_parent_batch_self_reference() FROM PUBLIC;
GRANT ALL ON FUNCTION public.reject_parent_batch_self_reference() TO service_role;


--
-- Name: FUNCTION set_brand_active(p_id uuid, p_active boolean); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.set_brand_active(p_id uuid, p_active boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.set_brand_active(p_id uuid, p_active boolean) TO authenticated;


--
-- Name: FUNCTION set_product_active(p_id uuid, p_active boolean); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.set_product_active(p_id uuid, p_active boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.set_product_active(p_id uuid, p_active boolean) TO authenticated;


--
-- Name: FUNCTION set_production_plan_item_active(p_id uuid, p_active boolean); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.set_production_plan_item_active(p_id uuid, p_active boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.set_production_plan_item_active(p_id uuid, p_active boolean) TO authenticated;


--
-- Name: FUNCTION set_raw_material_active(p_id uuid, p_active boolean); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.set_raw_material_active(p_id uuid, p_active boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.set_raw_material_active(p_id uuid, p_active boolean) TO authenticated;


--
-- Name: FUNCTION set_recipe_active(p_id uuid, p_active boolean); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.set_recipe_active(p_id uuid, p_active boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.set_recipe_active(p_id uuid, p_active boolean) TO authenticated;


--
-- Name: FUNCTION start_production_batch(p_production_request_id uuid, p_product_inputs jsonb); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.start_production_batch(p_production_request_id uuid, p_product_inputs jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION public.start_production_batch(p_production_request_id uuid, p_product_inputs jsonb) TO postgres;
GRANT ALL ON FUNCTION public.start_production_batch(p_production_request_id uuid, p_product_inputs jsonb) TO authenticated;


--
-- Name: FUNCTION update_brand(p_id uuid, p_name text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.update_brand(p_id uuid, p_name text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.update_brand(p_id uuid, p_name text) TO authenticated;


--
-- Name: FUNCTION update_product(p_id uuid, p_name text, p_default_unit text, p_default_shift_code text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.update_product(p_id uuid, p_name text, p_default_unit text, p_default_shift_code text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.update_product(p_id uuid, p_name text, p_default_unit text, p_default_shift_code text) TO authenticated;


--
-- Name: FUNCTION update_production_plan_item(p_id uuid, p_weekday smallint, p_shift_code text, p_product_id uuid, p_planned_quantity numeric, p_unit text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.update_production_plan_item(p_id uuid, p_weekday smallint, p_shift_code text, p_product_id uuid, p_planned_quantity numeric, p_unit text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.update_production_plan_item(p_id uuid, p_weekday smallint, p_shift_code text, p_product_id uuid, p_planned_quantity numeric, p_unit text) TO authenticated;


--
-- Name: FUNCTION update_raw_material(p_id uuid, p_name text, p_default_unit text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.update_raw_material(p_id uuid, p_name text, p_default_unit text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.update_raw_material(p_id uuid, p_name text, p_default_unit text) TO authenticated;


--
-- Name: FUNCTION update_recipe(p_id uuid, p_name text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.update_recipe(p_id uuid, p_name text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.update_recipe(p_id uuid, p_name text) TO authenticated;


--
-- Name: FUNCTION apply_rls(wal jsonb, max_record_bytes integer); Type: ACL; Schema: realtime; Owner: -
--

GRANT ALL ON FUNCTION realtime.apply_rls(wal jsonb, max_record_bytes integer) TO postgres;
GRANT ALL ON FUNCTION realtime.apply_rls(wal jsonb, max_record_bytes integer) TO dashboard_user;
GRANT ALL ON FUNCTION realtime.apply_rls(wal jsonb, max_record_bytes integer) TO anon;
GRANT ALL ON FUNCTION realtime.apply_rls(wal jsonb, max_record_bytes integer) TO authenticated;
GRANT ALL ON FUNCTION realtime.apply_rls(wal jsonb, max_record_bytes integer) TO service_role;


--
-- Name: FUNCTION broadcast_changes(topic_name text, event_name text, operation text, table_name text, table_schema text, new record, old record, level text); Type: ACL; Schema: realtime; Owner: -
--

GRANT ALL ON FUNCTION realtime.broadcast_changes(topic_name text, event_name text, operation text, table_name text, table_schema text, new record, old record, level text) TO postgres;
GRANT ALL ON FUNCTION realtime.broadcast_changes(topic_name text, event_name text, operation text, table_name text, table_schema text, new record, old record, level text) TO dashboard_user;


--
-- Name: FUNCTION build_prepared_statement_sql(prepared_statement_name text, entity regclass, columns realtime.wal_column[]); Type: ACL; Schema: realtime; Owner: -
--

GRANT ALL ON FUNCTION realtime.build_prepared_statement_sql(prepared_statement_name text, entity regclass, columns realtime.wal_column[]) TO postgres;
GRANT ALL ON FUNCTION realtime.build_prepared_statement_sql(prepared_statement_name text, entity regclass, columns realtime.wal_column[]) TO dashboard_user;
GRANT ALL ON FUNCTION realtime.build_prepared_statement_sql(prepared_statement_name text, entity regclass, columns realtime.wal_column[]) TO anon;
GRANT ALL ON FUNCTION realtime.build_prepared_statement_sql(prepared_statement_name text, entity regclass, columns realtime.wal_column[]) TO authenticated;
GRANT ALL ON FUNCTION realtime.build_prepared_statement_sql(prepared_statement_name text, entity regclass, columns realtime.wal_column[]) TO service_role;


--
-- Name: FUNCTION "cast"(val text, type_ regtype); Type: ACL; Schema: realtime; Owner: -
--

GRANT ALL ON FUNCTION realtime."cast"(val text, type_ regtype) TO postgres;
GRANT ALL ON FUNCTION realtime."cast"(val text, type_ regtype) TO dashboard_user;
GRANT ALL ON FUNCTION realtime."cast"(val text, type_ regtype) TO anon;
GRANT ALL ON FUNCTION realtime."cast"(val text, type_ regtype) TO authenticated;
GRANT ALL ON FUNCTION realtime."cast"(val text, type_ regtype) TO service_role;


--
-- Name: FUNCTION check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text); Type: ACL; Schema: realtime; Owner: -
--

GRANT ALL ON FUNCTION realtime.check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text) TO postgres;
GRANT ALL ON FUNCTION realtime.check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text) TO dashboard_user;
GRANT ALL ON FUNCTION realtime.check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text) TO anon;
GRANT ALL ON FUNCTION realtime.check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text) TO authenticated;
GRANT ALL ON FUNCTION realtime.check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text) TO service_role;


--
-- Name: FUNCTION check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text, negate boolean); Type: ACL; Schema: realtime; Owner: -
--

GRANT ALL ON FUNCTION realtime.check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text, negate boolean) TO postgres;
GRANT ALL ON FUNCTION realtime.check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text, negate boolean) TO dashboard_user;
GRANT ALL ON FUNCTION realtime.check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text, negate boolean) TO anon;
GRANT ALL ON FUNCTION realtime.check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text, negate boolean) TO authenticated;
GRANT ALL ON FUNCTION realtime.check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text, negate boolean) TO service_role;


--
-- Name: FUNCTION is_visible_through_filters(columns realtime.wal_column[], filters realtime.user_defined_filter[]); Type: ACL; Schema: realtime; Owner: -
--

GRANT ALL ON FUNCTION realtime.is_visible_through_filters(columns realtime.wal_column[], filters realtime.user_defined_filter[]) TO postgres;
GRANT ALL ON FUNCTION realtime.is_visible_through_filters(columns realtime.wal_column[], filters realtime.user_defined_filter[]) TO dashboard_user;
GRANT ALL ON FUNCTION realtime.is_visible_through_filters(columns realtime.wal_column[], filters realtime.user_defined_filter[]) TO anon;
GRANT ALL ON FUNCTION realtime.is_visible_through_filters(columns realtime.wal_column[], filters realtime.user_defined_filter[]) TO authenticated;
GRANT ALL ON FUNCTION realtime.is_visible_through_filters(columns realtime.wal_column[], filters realtime.user_defined_filter[]) TO service_role;


--
-- Name: FUNCTION list_changes(publication name, slot_name name, max_changes integer, max_record_bytes integer); Type: ACL; Schema: realtime; Owner: -
--

GRANT ALL ON FUNCTION realtime.list_changes(publication name, slot_name name, max_changes integer, max_record_bytes integer) TO postgres;
GRANT ALL ON FUNCTION realtime.list_changes(publication name, slot_name name, max_changes integer, max_record_bytes integer) TO dashboard_user;


--
-- Name: FUNCTION quote_wal2json(entity regclass); Type: ACL; Schema: realtime; Owner: -
--

GRANT ALL ON FUNCTION realtime.quote_wal2json(entity regclass) TO postgres;
GRANT ALL ON FUNCTION realtime.quote_wal2json(entity regclass) TO dashboard_user;
GRANT ALL ON FUNCTION realtime.quote_wal2json(entity regclass) TO anon;
GRANT ALL ON FUNCTION realtime.quote_wal2json(entity regclass) TO authenticated;
GRANT ALL ON FUNCTION realtime.quote_wal2json(entity regclass) TO service_role;


--
-- Name: FUNCTION send(payload jsonb, event text, topic text, private boolean); Type: ACL; Schema: realtime; Owner: -
--

GRANT ALL ON FUNCTION realtime.send(payload jsonb, event text, topic text, private boolean) TO postgres;
GRANT ALL ON FUNCTION realtime.send(payload jsonb, event text, topic text, private boolean) TO dashboard_user;


--
-- Name: FUNCTION send_binary(payload bytea, event text, topic text, private boolean); Type: ACL; Schema: realtime; Owner: -
--

GRANT ALL ON FUNCTION realtime.send_binary(payload bytea, event text, topic text, private boolean) TO postgres;
GRANT ALL ON FUNCTION realtime.send_binary(payload bytea, event text, topic text, private boolean) TO dashboard_user;


--
-- Name: FUNCTION subscription_check_filters(); Type: ACL; Schema: realtime; Owner: -
--

GRANT ALL ON FUNCTION realtime.subscription_check_filters() TO postgres;
GRANT ALL ON FUNCTION realtime.subscription_check_filters() TO dashboard_user;
GRANT ALL ON FUNCTION realtime.subscription_check_filters() TO anon;
GRANT ALL ON FUNCTION realtime.subscription_check_filters() TO authenticated;
GRANT ALL ON FUNCTION realtime.subscription_check_filters() TO service_role;


--
-- Name: FUNCTION to_regrole(role_name text); Type: ACL; Schema: realtime; Owner: -
--

GRANT ALL ON FUNCTION realtime.to_regrole(role_name text) TO postgres;
GRANT ALL ON FUNCTION realtime.to_regrole(role_name text) TO dashboard_user;
GRANT ALL ON FUNCTION realtime.to_regrole(role_name text) TO anon;
GRANT ALL ON FUNCTION realtime.to_regrole(role_name text) TO authenticated;
GRANT ALL ON FUNCTION realtime.to_regrole(role_name text) TO service_role;


--
-- Name: FUNCTION topic(); Type: ACL; Schema: realtime; Owner: -
--

GRANT ALL ON FUNCTION realtime.topic() TO postgres;
GRANT ALL ON FUNCTION realtime.topic() TO dashboard_user;


--
-- Name: FUNCTION wal2json_escape_identifier(name text); Type: ACL; Schema: realtime; Owner: -
--

GRANT ALL ON FUNCTION realtime.wal2json_escape_identifier(name text) TO postgres;
GRANT ALL ON FUNCTION realtime.wal2json_escape_identifier(name text) TO dashboard_user;


--
-- Name: FUNCTION http_request(); Type: ACL; Schema: supabase_functions; Owner: -
--

REVOKE ALL ON FUNCTION supabase_functions.http_request() FROM PUBLIC;
GRANT ALL ON FUNCTION supabase_functions.http_request() TO postgres;
GRANT ALL ON FUNCTION supabase_functions.http_request() TO anon;
GRANT ALL ON FUNCTION supabase_functions.http_request() TO authenticated;
GRANT ALL ON FUNCTION supabase_functions.http_request() TO service_role;


--
-- Name: FUNCTION _crypto_aead_det_decrypt(message bytea, additional bytea, key_id bigint, context bytea, nonce bytea); Type: ACL; Schema: vault; Owner: -
--

GRANT ALL ON FUNCTION vault._crypto_aead_det_decrypt(message bytea, additional bytea, key_id bigint, context bytea, nonce bytea) TO postgres WITH GRANT OPTION;
GRANT ALL ON FUNCTION vault._crypto_aead_det_decrypt(message bytea, additional bytea, key_id bigint, context bytea, nonce bytea) TO service_role;


--
-- Name: FUNCTION create_secret(new_secret text, new_name text, new_description text, new_key_id uuid); Type: ACL; Schema: vault; Owner: -
--

GRANT ALL ON FUNCTION vault.create_secret(new_secret text, new_name text, new_description text, new_key_id uuid) TO postgres WITH GRANT OPTION;
GRANT ALL ON FUNCTION vault.create_secret(new_secret text, new_name text, new_description text, new_key_id uuid) TO service_role;


--
-- Name: FUNCTION update_secret(secret_id uuid, new_secret text, new_name text, new_description text, new_key_id uuid); Type: ACL; Schema: vault; Owner: -
--

GRANT ALL ON FUNCTION vault.update_secret(secret_id uuid, new_secret text, new_name text, new_description text, new_key_id uuid) TO postgres WITH GRANT OPTION;
GRANT ALL ON FUNCTION vault.update_secret(secret_id uuid, new_secret text, new_name text, new_description text, new_key_id uuid) TO service_role;


--
-- Name: TABLE audit_log_entries; Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON TABLE auth.audit_log_entries TO dashboard_user;
GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE auth.audit_log_entries TO postgres;
GRANT SELECT ON TABLE auth.audit_log_entries TO postgres WITH GRANT OPTION;


--
-- Name: TABLE custom_oauth_providers; Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON TABLE auth.custom_oauth_providers TO postgres;
GRANT ALL ON TABLE auth.custom_oauth_providers TO dashboard_user;


--
-- Name: TABLE flow_state; Type: ACL; Schema: auth; Owner: -
--

GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE auth.flow_state TO postgres;
GRANT SELECT ON TABLE auth.flow_state TO postgres WITH GRANT OPTION;
GRANT ALL ON TABLE auth.flow_state TO dashboard_user;


--
-- Name: TABLE identities; Type: ACL; Schema: auth; Owner: -
--

GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE auth.identities TO postgres;
GRANT SELECT ON TABLE auth.identities TO postgres WITH GRANT OPTION;
GRANT ALL ON TABLE auth.identities TO dashboard_user;


--
-- Name: TABLE instances; Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON TABLE auth.instances TO dashboard_user;
GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE auth.instances TO postgres;
GRANT SELECT ON TABLE auth.instances TO postgres WITH GRANT OPTION;


--
-- Name: TABLE mfa_amr_claims; Type: ACL; Schema: auth; Owner: -
--

GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE auth.mfa_amr_claims TO postgres;
GRANT SELECT ON TABLE auth.mfa_amr_claims TO postgres WITH GRANT OPTION;
GRANT ALL ON TABLE auth.mfa_amr_claims TO dashboard_user;


--
-- Name: TABLE mfa_challenges; Type: ACL; Schema: auth; Owner: -
--

GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE auth.mfa_challenges TO postgres;
GRANT SELECT ON TABLE auth.mfa_challenges TO postgres WITH GRANT OPTION;
GRANT ALL ON TABLE auth.mfa_challenges TO dashboard_user;


--
-- Name: TABLE mfa_factors; Type: ACL; Schema: auth; Owner: -
--

GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE auth.mfa_factors TO postgres;
GRANT SELECT ON TABLE auth.mfa_factors TO postgres WITH GRANT OPTION;
GRANT ALL ON TABLE auth.mfa_factors TO dashboard_user;


--
-- Name: TABLE oauth_authorizations; Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON TABLE auth.oauth_authorizations TO postgres;
GRANT ALL ON TABLE auth.oauth_authorizations TO dashboard_user;


--
-- Name: TABLE oauth_client_states; Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON TABLE auth.oauth_client_states TO postgres;
GRANT ALL ON TABLE auth.oauth_client_states TO dashboard_user;


--
-- Name: TABLE oauth_clients; Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON TABLE auth.oauth_clients TO postgres;
GRANT ALL ON TABLE auth.oauth_clients TO dashboard_user;


--
-- Name: TABLE oauth_consents; Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON TABLE auth.oauth_consents TO postgres;
GRANT ALL ON TABLE auth.oauth_consents TO dashboard_user;


--
-- Name: TABLE one_time_tokens; Type: ACL; Schema: auth; Owner: -
--

GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE auth.one_time_tokens TO postgres;
GRANT SELECT ON TABLE auth.one_time_tokens TO postgres WITH GRANT OPTION;
GRANT ALL ON TABLE auth.one_time_tokens TO dashboard_user;


--
-- Name: TABLE refresh_tokens; Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON TABLE auth.refresh_tokens TO dashboard_user;
GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE auth.refresh_tokens TO postgres;
GRANT SELECT ON TABLE auth.refresh_tokens TO postgres WITH GRANT OPTION;


--
-- Name: SEQUENCE refresh_tokens_id_seq; Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON SEQUENCE auth.refresh_tokens_id_seq TO dashboard_user;
GRANT ALL ON SEQUENCE auth.refresh_tokens_id_seq TO postgres;


--
-- Name: TABLE saml_providers; Type: ACL; Schema: auth; Owner: -
--

GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE auth.saml_providers TO postgres;
GRANT SELECT ON TABLE auth.saml_providers TO postgres WITH GRANT OPTION;
GRANT ALL ON TABLE auth.saml_providers TO dashboard_user;


--
-- Name: TABLE saml_relay_states; Type: ACL; Schema: auth; Owner: -
--

GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE auth.saml_relay_states TO postgres;
GRANT SELECT ON TABLE auth.saml_relay_states TO postgres WITH GRANT OPTION;
GRANT ALL ON TABLE auth.saml_relay_states TO dashboard_user;


--
-- Name: TABLE schema_migrations; Type: ACL; Schema: auth; Owner: -
--

GRANT SELECT ON TABLE auth.schema_migrations TO postgres WITH GRANT OPTION;


--
-- Name: TABLE sessions; Type: ACL; Schema: auth; Owner: -
--

GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE auth.sessions TO postgres;
GRANT SELECT ON TABLE auth.sessions TO postgres WITH GRANT OPTION;
GRANT ALL ON TABLE auth.sessions TO dashboard_user;


--
-- Name: TABLE sso_domains; Type: ACL; Schema: auth; Owner: -
--

GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE auth.sso_domains TO postgres;
GRANT SELECT ON TABLE auth.sso_domains TO postgres WITH GRANT OPTION;
GRANT ALL ON TABLE auth.sso_domains TO dashboard_user;


--
-- Name: TABLE sso_providers; Type: ACL; Schema: auth; Owner: -
--

GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE auth.sso_providers TO postgres;
GRANT SELECT ON TABLE auth.sso_providers TO postgres WITH GRANT OPTION;
GRANT ALL ON TABLE auth.sso_providers TO dashboard_user;


--
-- Name: TABLE users; Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON TABLE auth.users TO dashboard_user;
GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE auth.users TO postgres;
GRANT SELECT ON TABLE auth.users TO postgres WITH GRANT OPTION;


--
-- Name: TABLE webauthn_challenges; Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON TABLE auth.webauthn_challenges TO postgres;
GRANT ALL ON TABLE auth.webauthn_challenges TO dashboard_user;


--
-- Name: TABLE webauthn_credentials; Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON TABLE auth.webauthn_credentials TO postgres;
GRANT ALL ON TABLE auth.webauthn_credentials TO dashboard_user;


--
-- Name: TABLE pg_stat_statements; Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON TABLE extensions.pg_stat_statements TO postgres WITH GRANT OPTION;


--
-- Name: TABLE pg_stat_statements_info; Type: ACL; Schema: extensions; Owner: -
--

GRANT ALL ON TABLE extensions.pg_stat_statements_info TO postgres WITH GRANT OPTION;


--
-- Name: TABLE batch_materials; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.batch_materials TO anon;
GRANT ALL ON TABLE public.batch_materials TO authenticated;
GRANT ALL ON TABLE public.batch_materials TO service_role;


--
-- Name: TABLE batch_outputs; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.batch_outputs TO anon;
GRANT ALL ON TABLE public.batch_outputs TO authenticated;
GRANT ALL ON TABLE public.batch_outputs TO service_role;


--
-- Name: TABLE batch_requests; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.batch_requests TO anon;
GRANT ALL ON TABLE public.batch_requests TO authenticated;
GRANT ALL ON TABLE public.batch_requests TO service_role;


--
-- Name: TABLE brands; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.brands TO anon;
GRANT ALL ON TABLE public.brands TO authenticated;
GRANT ALL ON TABLE public.brands TO service_role;


--
-- Name: TABLE external_order_items; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.external_order_items TO anon;
GRANT ALL ON TABLE public.external_order_items TO authenticated;
GRANT ALL ON TABLE public.external_order_items TO service_role;


--
-- Name: TABLE external_orders; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.external_orders TO anon;
GRANT ALL ON TABLE public.external_orders TO authenticated;
GRANT ALL ON TABLE public.external_orders TO service_role;


--
-- Name: TABLE material_lots; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.material_lots TO anon;
GRANT ALL ON TABLE public.material_lots TO authenticated;
GRANT ALL ON TABLE public.material_lots TO service_role;


--
-- Name: TABLE parent_batch_inputs; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.parent_batch_inputs TO anon;
GRANT ALL ON TABLE public.parent_batch_inputs TO authenticated;
GRANT ALL ON TABLE public.parent_batch_inputs TO service_role;


--
-- Name: TABLE production_batches; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.production_batches TO anon;
GRANT ALL ON TABLE public.production_batches TO authenticated;
GRANT ALL ON TABLE public.production_batches TO service_role;


--
-- Name: TABLE production_days; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.production_days TO anon;
GRANT ALL ON TABLE public.production_days TO authenticated;
GRANT ALL ON TABLE public.production_days TO service_role;


--
-- Name: TABLE production_plan_items; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.production_plan_items TO anon;
GRANT ALL ON TABLE public.production_plan_items TO authenticated;
GRANT ALL ON TABLE public.production_plan_items TO service_role;


--
-- Name: TABLE production_requests; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.production_requests TO anon;
GRANT ALL ON TABLE public.production_requests TO authenticated;
GRANT ALL ON TABLE public.production_requests TO service_role;


--
-- Name: TABLE products; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.products TO anon;
GRANT ALL ON TABLE public.products TO authenticated;
GRANT ALL ON TABLE public.products TO service_role;


--
-- Name: TABLE profiles; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.profiles TO anon;
GRANT ALL ON TABLE public.profiles TO authenticated;
GRANT ALL ON TABLE public.profiles TO service_role;


--
-- Name: TABLE raw_material_brands; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.raw_material_brands TO anon;
GRANT ALL ON TABLE public.raw_material_brands TO authenticated;
GRANT ALL ON TABLE public.raw_material_brands TO service_role;


--
-- Name: TABLE raw_materials; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.raw_materials TO anon;
GRANT ALL ON TABLE public.raw_materials TO authenticated;
GRANT ALL ON TABLE public.raw_materials TO service_role;


--
-- Name: TABLE recipe_ingredients; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.recipe_ingredients TO anon;
GRANT ALL ON TABLE public.recipe_ingredients TO authenticated;
GRANT ALL ON TABLE public.recipe_ingredients TO service_role;


--
-- Name: TABLE recipe_product_inputs; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.recipe_product_inputs TO anon;
GRANT ALL ON TABLE public.recipe_product_inputs TO authenticated;
GRANT ALL ON TABLE public.recipe_product_inputs TO service_role;


--
-- Name: TABLE recipe_products; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.recipe_products TO anon;
GRANT ALL ON TABLE public.recipe_products TO authenticated;
GRANT ALL ON TABLE public.recipe_products TO service_role;


--
-- Name: TABLE recipe_versions; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.recipe_versions TO anon;
GRANT ALL ON TABLE public.recipe_versions TO authenticated;
GRANT ALL ON TABLE public.recipe_versions TO service_role;


--
-- Name: TABLE recipes; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.recipes TO anon;
GRANT ALL ON TABLE public.recipes TO authenticated;
GRANT ALL ON TABLE public.recipes TO service_role;


--
-- Name: TABLE messages; Type: ACL; Schema: realtime; Owner: -
--

GRANT ALL ON TABLE realtime.messages TO postgres;
GRANT ALL ON TABLE realtime.messages TO dashboard_user;
GRANT SELECT,INSERT,UPDATE ON TABLE realtime.messages TO anon;
GRANT SELECT,INSERT,UPDATE ON TABLE realtime.messages TO authenticated;
GRANT SELECT,INSERT,UPDATE ON TABLE realtime.messages TO service_role;


--
-- Name: TABLE messages_2026_09_10; Type: ACL; Schema: realtime; Owner: -
--

GRANT ALL ON TABLE realtime.messages_2026_09_10 TO postgres;
GRANT ALL ON TABLE realtime.messages_2026_09_10 TO dashboard_user;


--
-- Name: TABLE messages_2026_09_11; Type: ACL; Schema: realtime; Owner: -
--

GRANT ALL ON TABLE realtime.messages_2026_09_11 TO postgres;
GRANT ALL ON TABLE realtime.messages_2026_09_11 TO dashboard_user;


--
-- Name: TABLE messages_2026_09_12; Type: ACL; Schema: realtime; Owner: -
--

GRANT ALL ON TABLE realtime.messages_2026_09_12 TO postgres;
GRANT ALL ON TABLE realtime.messages_2026_09_12 TO dashboard_user;


--
-- Name: TABLE messages_2026_09_13; Type: ACL; Schema: realtime; Owner: -
--

GRANT ALL ON TABLE realtime.messages_2026_09_13 TO postgres;
GRANT ALL ON TABLE realtime.messages_2026_09_13 TO dashboard_user;


--
-- Name: TABLE messages_2026_09_14; Type: ACL; Schema: realtime; Owner: -
--

GRANT ALL ON TABLE realtime.messages_2026_09_14 TO postgres;
GRANT ALL ON TABLE realtime.messages_2026_09_14 TO dashboard_user;


--
-- Name: TABLE messages_2026_09_15; Type: ACL; Schema: realtime; Owner: -
--

GRANT ALL ON TABLE realtime.messages_2026_09_15 TO postgres;
GRANT ALL ON TABLE realtime.messages_2026_09_15 TO dashboard_user;


--
-- Name: TABLE messages_2026_09_16; Type: ACL; Schema: realtime; Owner: -
--

GRANT ALL ON TABLE realtime.messages_2026_09_16 TO postgres;
GRANT ALL ON TABLE realtime.messages_2026_09_16 TO dashboard_user;


--
-- Name: TABLE schema_migrations; Type: ACL; Schema: realtime; Owner: -
--

GRANT ALL ON TABLE realtime.schema_migrations TO postgres;
GRANT ALL ON TABLE realtime.schema_migrations TO dashboard_user;


--
-- Name: TABLE subscription; Type: ACL; Schema: realtime; Owner: -
--

GRANT ALL ON TABLE realtime.subscription TO postgres;
GRANT ALL ON TABLE realtime.subscription TO dashboard_user;
GRANT SELECT ON TABLE realtime.subscription TO anon;
GRANT SELECT ON TABLE realtime.subscription TO authenticated;
GRANT SELECT ON TABLE realtime.subscription TO service_role;


--
-- Name: SEQUENCE subscription_id_seq; Type: ACL; Schema: realtime; Owner: -
--

GRANT ALL ON SEQUENCE realtime.subscription_id_seq TO postgres;
GRANT ALL ON SEQUENCE realtime.subscription_id_seq TO dashboard_user;
GRANT USAGE ON SEQUENCE realtime.subscription_id_seq TO anon;
GRANT USAGE ON SEQUENCE realtime.subscription_id_seq TO authenticated;
GRANT USAGE ON SEQUENCE realtime.subscription_id_seq TO service_role;


--
-- Name: TABLE buckets; Type: ACL; Schema: storage; Owner: -
--

GRANT ALL ON TABLE storage.buckets TO postgres WITH GRANT OPTION;
GRANT ALL ON TABLE storage.buckets TO service_role;
GRANT ALL ON TABLE storage.buckets TO authenticated;
GRANT ALL ON TABLE storage.buckets TO anon;


--
-- Name: TABLE buckets_analytics; Type: ACL; Schema: storage; Owner: -
--

GRANT ALL ON TABLE storage.buckets_analytics TO service_role;
GRANT ALL ON TABLE storage.buckets_analytics TO authenticated;
GRANT ALL ON TABLE storage.buckets_analytics TO anon;


--
-- Name: TABLE buckets_vectors; Type: ACL; Schema: storage; Owner: -
--

GRANT SELECT ON TABLE storage.buckets_vectors TO service_role;
GRANT SELECT ON TABLE storage.buckets_vectors TO authenticated;
GRANT SELECT ON TABLE storage.buckets_vectors TO anon;


--
-- Name: TABLE iceberg_namespaces; Type: ACL; Schema: storage; Owner: -
--

GRANT ALL ON TABLE storage.iceberg_namespaces TO service_role;
GRANT SELECT ON TABLE storage.iceberg_namespaces TO authenticated;
GRANT SELECT ON TABLE storage.iceberg_namespaces TO anon;


--
-- Name: TABLE iceberg_tables; Type: ACL; Schema: storage; Owner: -
--

GRANT ALL ON TABLE storage.iceberg_tables TO service_role;
GRANT SELECT ON TABLE storage.iceberg_tables TO authenticated;
GRANT SELECT ON TABLE storage.iceberg_tables TO anon;


--
-- Name: TABLE objects; Type: ACL; Schema: storage; Owner: -
--

GRANT ALL ON TABLE storage.objects TO postgres WITH GRANT OPTION;
GRANT ALL ON TABLE storage.objects TO service_role;
GRANT ALL ON TABLE storage.objects TO authenticated;
GRANT ALL ON TABLE storage.objects TO anon;


--
-- Name: TABLE s3_multipart_uploads; Type: ACL; Schema: storage; Owner: -
--

GRANT ALL ON TABLE storage.s3_multipart_uploads TO service_role;
GRANT SELECT ON TABLE storage.s3_multipart_uploads TO authenticated;
GRANT SELECT ON TABLE storage.s3_multipart_uploads TO anon;


--
-- Name: TABLE s3_multipart_uploads_parts; Type: ACL; Schema: storage; Owner: -
--

GRANT ALL ON TABLE storage.s3_multipart_uploads_parts TO service_role;
GRANT SELECT ON TABLE storage.s3_multipart_uploads_parts TO authenticated;
GRANT SELECT ON TABLE storage.s3_multipart_uploads_parts TO anon;


--
-- Name: TABLE vector_indexes; Type: ACL; Schema: storage; Owner: -
--

GRANT SELECT ON TABLE storage.vector_indexes TO service_role;
GRANT SELECT ON TABLE storage.vector_indexes TO authenticated;
GRANT SELECT ON TABLE storage.vector_indexes TO anon;


--
-- Name: TABLE hooks; Type: ACL; Schema: supabase_functions; Owner: -
--

GRANT ALL ON TABLE supabase_functions.hooks TO postgres;
GRANT ALL ON TABLE supabase_functions.hooks TO anon;
GRANT ALL ON TABLE supabase_functions.hooks TO authenticated;
GRANT ALL ON TABLE supabase_functions.hooks TO service_role;


--
-- Name: SEQUENCE hooks_id_seq; Type: ACL; Schema: supabase_functions; Owner: -
--

GRANT ALL ON SEQUENCE supabase_functions.hooks_id_seq TO postgres;
GRANT ALL ON SEQUENCE supabase_functions.hooks_id_seq TO anon;
GRANT ALL ON SEQUENCE supabase_functions.hooks_id_seq TO authenticated;
GRANT ALL ON SEQUENCE supabase_functions.hooks_id_seq TO service_role;


--
-- Name: TABLE migrations; Type: ACL; Schema: supabase_functions; Owner: -
--

GRANT ALL ON TABLE supabase_functions.migrations TO postgres;
GRANT ALL ON TABLE supabase_functions.migrations TO anon;
GRANT ALL ON TABLE supabase_functions.migrations TO authenticated;
GRANT ALL ON TABLE supabase_functions.migrations TO service_role;


--
-- Name: TABLE secrets; Type: ACL; Schema: vault; Owner: -
--

GRANT SELECT,REFERENCES,DELETE,TRUNCATE ON TABLE vault.secrets TO postgres WITH GRANT OPTION;
GRANT SELECT,DELETE ON TABLE vault.secrets TO service_role;


--
-- Name: TABLE decrypted_secrets; Type: ACL; Schema: vault; Owner: -
--

GRANT SELECT,REFERENCES,DELETE,TRUNCATE ON TABLE vault.decrypted_secrets TO postgres WITH GRANT OPTION;
GRANT SELECT,DELETE ON TABLE vault.decrypted_secrets TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: auth; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_auth_admin IN SCHEMA auth GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_auth_admin IN SCHEMA auth GRANT ALL ON SEQUENCES TO dashboard_user;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: auth; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_auth_admin IN SCHEMA auth GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_auth_admin IN SCHEMA auth GRANT ALL ON FUNCTIONS TO dashboard_user;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: auth; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_auth_admin IN SCHEMA auth GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_auth_admin IN SCHEMA auth GRANT ALL ON TABLES TO dashboard_user;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: extensions; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA extensions GRANT ALL ON SEQUENCES TO postgres WITH GRANT OPTION;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: extensions; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA extensions GRANT ALL ON FUNCTIONS TO postgres WITH GRANT OPTION;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: extensions; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA extensions GRANT ALL ON TABLES TO postgres WITH GRANT OPTION;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: graphql; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA graphql GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA graphql GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA graphql GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA graphql GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: graphql; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA graphql GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA graphql GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA graphql GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA graphql GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: graphql; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA graphql GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA graphql GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA graphql GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA graphql GRANT ALL ON TABLES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: graphql_public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA graphql_public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA graphql_public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA graphql_public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA graphql_public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: graphql_public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA graphql_public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA graphql_public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA graphql_public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA graphql_public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: graphql_public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA graphql_public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA graphql_public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA graphql_public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA graphql_public GRANT ALL ON TABLES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: realtime; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA realtime GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA realtime GRANT ALL ON SEQUENCES TO dashboard_user;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: realtime; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA realtime GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA realtime GRANT ALL ON FUNCTIONS TO dashboard_user;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: realtime; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA realtime GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA realtime GRANT ALL ON TABLES TO dashboard_user;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: storage; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: storage; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: storage; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage GRANT ALL ON TABLES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: supabase_functions; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA supabase_functions GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA supabase_functions GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA supabase_functions GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA supabase_functions GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: supabase_functions; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA supabase_functions GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA supabase_functions GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA supabase_functions GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA supabase_functions GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: supabase_functions; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA supabase_functions GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA supabase_functions GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA supabase_functions GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA supabase_functions GRANT ALL ON TABLES TO service_role;


--
-- Name: issue_graphql_placeholder; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_graphql_placeholder ON sql_drop
         WHEN TAG IN ('DROP EXTENSION')
   EXECUTE FUNCTION extensions.set_graphql_placeholder();


--
-- Name: issue_pg_cron_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_cron_access ON ddl_command_end
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION extensions.grant_pg_cron_access();


--
-- Name: issue_pg_graphql_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_graphql_access ON ddl_command_end
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION extensions.grant_pg_graphql_access();


--
-- Name: issue_pg_net_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_net_access ON ddl_command_end
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION extensions.grant_pg_net_access();


--
-- Name: pgrst_ddl_watch; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER pgrst_ddl_watch ON ddl_command_end
   EXECUTE FUNCTION extensions.pgrst_ddl_watch();


--
-- Name: pgrst_drop_watch; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER pgrst_drop_watch ON sql_drop
   EXECUTE FUNCTION extensions.pgrst_drop_watch();


--
-- PostgreSQL database dump complete
--

\unrestrict XF0xtSDsbqYv33Zkge5nqQec5cZQnXhEX2A2ER0qoG09ieYuGLaC0Y0V8A39ltI


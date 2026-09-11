-- Phase U4: RPC execution security hardening.
--
-- Audit of every database function created so far in schema public:
--
-- 1) public.reject_parent_batch_self_reference()
--    - kind: BEFORE INSERT/UPDATE trigger guard on parent_batch_inputs
--      (rejects a batch consuming its own output); not a client-callable RPC.
--    - security: SECURITY INVOKER (deliberate: pure read-only guard, needs
--      no elevated access).
--    - owner: postgres; reachable only through the trigger.
--    - hardening: Supabase default privileges explicitly granted EXECUTE to
--      anon, authenticated and service_role at creation time. Executing this
--      trigger guard is only needed by the role that can write
--      parent_batch_inputs (the trigger fires with the privileges of the
--      inserting role): service_role. anon/authenticated lose EXECUTE; they
--      have no write policies, so the trigger can never fire for them. If a
--      future phase adds a write path for an app role, that same migration
--      must grant EXECUTE explicitly (see SECURITY.md RPC checklist).

revoke execute on function public.reject_parent_batch_self_reference() from public;
revoke execute on function public.reject_parent_batch_self_reference() from anon, authenticated;
grant execute on function public.reject_parent_batch_self_reference() to service_role;

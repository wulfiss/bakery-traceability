import { type Handle } from '@sveltejs/kit';
import { getSupabaseServerClient } from '$lib/supabase/server';
import type { Database } from '$lib/types/database.types';
import type { Role } from '$lib/roles';

// Single auth source per server request:
// - the request-scoped Supabase server client is created here,
// - the session is refreshed/validated (cookie writes land in this response),
// - the user is resolved once and exposed through event.locals,
// - the active profile role is resolved once (profiles_select_own RLS) and
//   exposed as event.locals.profileRole, so nested layouts and page loads
//   authorize without extra queries. Layout load order must not matter.
//   Hiding things in the UI is convenience only — RLS and the RPC role
//   checks remain the real authorization (AT).
export const handle: Handle = async ({ event, resolve }) => {
	const supabase = getSupabaseServerClient(event);
	const { data } = await supabase.auth.getUser();

	event.locals.supabase = supabase;
	event.locals.user = data.user;

	const user = data.user;
	if (user) {
		const rows: Pick<Database['public']['Tables']['profiles']['Row'], 'id' | 'role' | 'active'>[] =
			(await supabase.from('profiles').select('id, role, active').eq('id', user.id).limit(1))
				.data ?? [];
		const profile = rows[0];
		event.locals.profileRole = profile?.active ? (profile.role as Role) : null;
	}

	return resolve(event);
};

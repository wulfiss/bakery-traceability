import { type Handle } from '@sveltejs/kit';
import { getSupabaseServerClient } from '$lib/supabase/server';

// Single auth source per server request:
// - the request-scoped Supabase server client is created here,
// - the session is refreshed/validated (cookie writes land in this response),
// - the user is resolved once and exposed through event.locals,
//   so layouts and pages never call auth again.
export const handle: Handle = async ({ event, resolve }) => {
	const supabase = getSupabaseServerClient(event);
	const { data } = await supabase.auth.getUser();

	event.locals.supabase = supabase;
	event.locals.user = data.user;

	return resolve(event);
};

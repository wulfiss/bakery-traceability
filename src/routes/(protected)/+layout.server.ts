import { redirect } from '@sveltejs/kit';
import type { LayoutServerLoad } from './$types';

// Authentication + active-profile guard for every route inside this
// route group (/production, /lots, /admin/*). hooks.server.ts already
// resolved the session and the caller's active profile role into
// event.locals for this request; a valid session without an active
// profile (profileRole === null) must not enter the app. Nested layouts
// (admin area) and server loads use event.locals.profileRole to
// authorize. Hiding things in the UI is convenience only — RLS and the
// RPC role checks remain the real authorization (AT).
export const load: LayoutServerLoad = (event) => {
	if (!event.locals.user || event.locals.profileRole === null) {
		throw redirect(303, '/login');
	}
};

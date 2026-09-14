import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

// V5.6: "/login" is redirect-only. The login form lives at "/" — an
// authenticated visitor goes to the app, an unauthenticated one to the
// login page. The session is resolved once in hooks.server.ts
// (event.locals).
export const load: PageServerLoad = (event) => {
	throw redirect(303, event.locals.user ? '/production' : '/');
};

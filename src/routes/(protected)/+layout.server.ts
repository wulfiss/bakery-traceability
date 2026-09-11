import { redirect } from '@sveltejs/kit';
import type { LayoutServerLoad } from './$types';

// Authentication guard for every route inside this route group
// (/production, /lots, /admin/*). The session itself is checked exactly
// once in hooks.server.ts; this load only enforces the result.
// Role authorization is intentionally not handled here yet.
export const load: LayoutServerLoad = (event) => {
	if (!event.locals.user) {
		throw redirect(303, '/login');
	}
};

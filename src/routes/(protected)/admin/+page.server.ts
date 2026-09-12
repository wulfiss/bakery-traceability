import type { PageServerLoad } from './$types';
import type { Role } from '$lib/roles';

// Phase AT: expose the resolved role so the UI can hide links the role
// may not use. Convenience only — the admin layout guard and the RPC
// role checks are the real authorization.
export const load: PageServerLoad = (event) => {
	const role: Role | null = event.locals.profileRole ?? null;
	return { role };
};

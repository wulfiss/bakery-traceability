import { redirect } from '@sveltejs/kit';
import type { LayoutServerLoad } from './$types';
import { isAtLeastRole } from '$lib/roles';

// Server-side authorization for the whole /admin area (Phase AT).
// The database RPCs remain the authoritative gate for writes; this keeps
// pages outside the caller's role from rendering at all:
//   operator   -> no /admin access (sent back to production)
//   supervisor -> the /admin hub (order link only) and
//                 /admin/external-orders (order management)
//   admin      -> full /admin
export const load: LayoutServerLoad = (event) => {
	const role = event.locals.profileRole ?? null;

	if (!isAtLeastRole(role, 'supervisor')) {
		throw redirect(303, '/production');
	}

	const inAllowedArea =
		event.url.pathname === '/admin' ||
		event.url.pathname === '/admin/external-orders' ||
		event.url.pathname.startsWith('/admin/external-orders/');

	if (role === 'supervisor' && !inAllowedArea) {
		throw redirect(303, '/admin/external-orders');
	}
};

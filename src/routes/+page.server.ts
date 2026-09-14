import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

// V5.6: "/" is the login page. A visitor with an active session is sent
// straight to the app; the session is resolved once in hooks.server.ts
// (event.locals).
export const load: PageServerLoad = (event) => {
	if (event.locals.user) {
		throw redirect(303, '/production');
	}
};

export const actions: Actions = {
	default: async (event) => {
		const formData = await event.request.formData();
		const rawEmail = formData.get('email');
		const email = typeof rawEmail === 'string' ? rawEmail.trim() : '';
		const rawPassword = formData.get('password');
		const password = typeof rawPassword === 'string' ? rawPassword : '';

		if (!email || !password) {
			return fail(400, { email, error: 'El correo y la contraseña son obligatorios.' });
		}

		// Reuse the request-scoped client created in hooks.server.ts.
		const supabase = event.locals.supabase;
		const { error } = await supabase.auth.signInWithPassword({ email, password });

		if (error) {
			// Do not reveal which part was wrong.
			return fail(400, { email, error: 'Correo o contraseña incorrectos.' });
		}

		throw redirect(303, '/production');
	}
};

// See https://svelte.dev/docs/kit/types#app.d.ts
// for information about these interfaces
import type { SupabaseClient } from '@supabase/ssr';
import type { User } from '@supabase/supabase-js';
import type { Database } from '$lib/types/database.types';
import type { Role } from '$lib/roles';

declare global {
	namespace App {
		// interface Error {}
		interface Locals {
			// Request-scoped Supabase server client (publishable key only).
			supabase: SupabaseClient<Database>;
			// The authenticated user for this request, or null.
			user: User | null;
			// The caller's active profile role, resolved once per request in
			// hooks.server.ts (null when the session has no active profile,
			// undefined for anonymous requests).
			profileRole?: Role | null;
		}
		// interface PageData {}
		// interface PageState {}
		// interface Platform {}
	}
}

export {};

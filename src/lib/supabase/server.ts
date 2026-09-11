import { createServerClient } from '@supabase/ssr';
import { type RequestEvent } from '@sveltejs/kit';
import { PUBLIC_SUPABASE_PUBLISHABLE_KEY, PUBLIC_SUPABASE_URL } from '$env/static/public';
import { type Database } from '$lib/types/database.types';

// Server client. Create one per request and pass the request event.
// Only the public publishable key is used; the service_role key must never
// be available to this client or to the browser.
export function getSupabaseServerClient(event: RequestEvent) {
	return createServerClient<Database>(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_PUBLISHABLE_KEY, {
		cookies: {
			getAll: () => event.cookies.getAll(),
			setAll: (cookiesToSet, headers) => {
				cookiesToSet.forEach(({ name, value, options }) => {
					event.cookies.set(name, value, { path: '/', ...options });
				});
				// Auth cookie writes must not be cached by CDNs or proxies.
				if (Object.keys(headers).length > 0) {
					event.setHeaders(headers);
				}
			}
		}
	});
}

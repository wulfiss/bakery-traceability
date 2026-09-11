import { type Handle } from '@sveltejs/kit'
import { getSupabaseServerClient } from '$lib/supabase/server'

// Wires cookie-based Supabase session handling into every server request.
// The session is refreshed/validated before the page renders, so SSR always
// sees a valid token and refreshed cookies are written to this response.
// No login redirect or page guards yet: those arrive with the login phase.
export const handle: Handle = async ({ event, resolve }) => {
  const supabase = getSupabaseServerClient(event)

  await supabase.auth.getClaims()

  return resolve(event)
}

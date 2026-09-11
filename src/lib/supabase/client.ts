import { createBrowserClient } from '@supabase/ssr'
import { PUBLIC_SUPABASE_PUBLISHABLE_KEY, PUBLIC_SUPABASE_URL } from '$env/static/public'
import { type Database } from '$lib/types/database.types'

// Browser client (client-side only). Never use it in server-only code.
let browserClient: ReturnType<typeof createBrowserClient<Database>> | undefined

export function getSupabaseBrowserClient() {
  if (browserClient) {
    return browserClient
  }
  browserClient = createBrowserClient<Database>(
    PUBLIC_SUPABASE_URL,
    PUBLIC_SUPABASE_PUBLISHABLE_KEY
  )
  return browserClient
}

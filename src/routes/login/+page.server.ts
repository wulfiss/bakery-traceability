import { fail, redirect } from '@sveltejs/kit'
import type { Actions, PageServerLoad } from './$types'
import { getSupabaseServerClient } from '$lib/supabase/server'

// If the user already has a session, sending them to login is pointless.
export const load: PageServerLoad = async (event) => {
  const supabase = getSupabaseServerClient(event)
  const { data } = await supabase.auth.getUser()
  if (data.user) {
    throw redirect(303, '/production')
  }
}

export const actions: Actions = {
  default: async (event) => {
    const formData = await event.request.formData()
    const rawEmail = formData.get('email')
    const email = typeof rawEmail === 'string' ? rawEmail.trim() : ''
    const rawPassword = formData.get('password')
    const password = typeof rawPassword === 'string' ? rawPassword : ''

    if (!email || !password) {
      return fail(400, { email, error: 'El correo y la contraseña son obligatorios.' })
    }

    const supabase = getSupabaseServerClient(event)
    const { error } = await supabase.auth.signInWithPassword({ email, password })

    if (error) {
      // Do not reveal which part was wrong.
      return fail(400, { email, error: 'Correo o contraseña incorrectos.' })
    }

    throw redirect(303, '/production')
  }
}

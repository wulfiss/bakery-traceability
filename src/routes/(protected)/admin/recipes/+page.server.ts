import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import type { Database } from '$lib/types/database.types';

// Explicit row annotation: supabase-js 2.116 under TS 6 does not resolve the
// inferred select type in this toolchain (see AGENTS.md).
type RecipeRow = Pick<Database['public']['Tables']['recipes']['Row'], 'id' | 'name' | 'active'>;

export type Recipe = {
	id: string;
	name: string;
	active: boolean;
};

type CreateFormValues = {
	name: string;
};

type EditFormValues = {
	id: string;
	name: string;
};

const UUID_RE = /^[0-9a-f-]{36}$/i;

export const load: PageServerLoad = async (event) => {
	const supabase = event.locals.supabase;

	// Read-only list. RLS (recipes_select_active) limits rows to users with an
	// active profile. Alphabetical by name.
	const result = await supabase
		.from('recipes')
		.select('id, name, active')
		.order('name', { ascending: true });
	if (result.error) throw result.error;

	const rows: RecipeRow[] = result.data ?? [];

	const recipes: Recipe[] = rows.map((row) => ({
		id: row.id,
		name: row.name,
		active: row.active
	}));

	return { recipes };
};

export const actions: Actions = {
	// AL4: create one recipe. All business validation lives in the create_recipe
	// RPC (admin-only); this action pre-validates the raw input so users get a
	// deterministic Spanish message instead of an RPC token, and maps the RPC's
	// English tokens to Spanish. Recipe names are not uniqueness-constrained
	// (the I1 schema spec only requires a non-empty name).
	create: async (event) => {
		const formData = await event.request.formData();
		const values: CreateFormValues = {
			name: textOf(formData.get('name'))
		};

		if (values.name.trim() === '') {
			return fail(400, { error: 'El nombre no puede estar vacío.', values });
		}

		const result = await event.locals.supabase.rpc('create_recipe', {
			p_name: values.name
		});

		if (result.error) {
			return fail(400, {
				error: recipeErrorMessages(result.error.message, 'No se pudo crear la receta.'),
				values
			});
		}

		if (!result.data) {
			return fail(400, { error: 'No se pudo crear la receta.', values });
		}

		redirect(303, '/admin/recipes');
	},

	// AL4: edit one recipe (name only). The recipe is identified by a hidden
	// field in the per-card edit form.
	update: async (event) => {
		const formData = await event.request.formData();
		const values: EditFormValues = {
			id: textOf(formData.get('id')),
			name: textOf(formData.get('name'))
		};

		if (!UUID_RE.test(values.id)) {
			return fail(400, { error: 'La receta no existe.', values });
		}

		if (values.name.trim() === '') {
			return fail(400, { error: 'El nombre no puede estar vacío.', values });
		}

		const result = await event.locals.supabase.rpc('update_recipe', {
			p_id: values.id,
			p_name: values.name
		});

		if (result.error) {
			return fail(400, {
				error: recipeErrorMessages(result.error.message, 'No se pudo guardar la receta.'),
				values
			});
		}

		if (!result.data) {
			return fail(400, { error: 'No se pudo guardar la receta.', values });
		}

		redirect(303, '/admin/recipes');
	},

	// AL4: activate/deactivate one recipe. Deactivation is soft (active =
	// false); recipes are never physically deleted (recipe_versions and
	// recipe_products reference them with RESTRICT FKs).
	set_active: async (event) => {
		const formData = await event.request.formData();
		const id = textOf(formData.get('id'));
		const active = formData.get('active') === 'true';

		if (!UUID_RE.test(id)) {
			return fail(400, { error: 'La receta no existe.' });
		}

		const result = await event.locals.supabase.rpc('set_recipe_active', {
			p_id: id,
			p_active: active
		});

		if (result.error) {
			return fail(400, {
				error: recipeErrorMessages(
					result.error.message,
					'No se pudo cambiar el estado de la receta.'
				)
			});
		}

		if (!result.data) {
			return fail(400, { error: 'No se pudo cambiar el estado de la receta.' });
		}

		redirect(303, '/admin/recipes');
	}
};

function textOf(value: unknown): string {
	return typeof value === 'string' ? value : '';
}

// Recipe RPC error tokens (English, developer-facing) to user-facing Spanish
// messages. The default message varies per action.
function recipeErrorMessages(message: string, fallback: string): string {
	switch (message) {
		case 'not_authenticated':
			return 'No hay sesión iniciada.';
		case 'no_active_profile':
			return 'Tu perfil no está activo.';
		case 'insufficient_role':
			return 'No tenés permiso para administrar recetas.';
		case 'recipe_not_found':
			return 'La receta no existe.';
		case 'invalid_name':
			return 'El nombre no puede estar vacío.';
		default:
			return fallback;
	}
}

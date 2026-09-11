import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import type { Database } from '$lib/types/database.types';

// Explicit row annotation: supabase-js 2.116 under TS 6 does not resolve the
// inferred select type in this toolchain (see AGENTS.md).
type RawMaterialRow = Pick<
	Database['public']['Tables']['raw_materials']['Row'],
	'id' | 'name' | 'default_unit' | 'active'
>;

export type RawMaterial = {
	id: string;
	name: string;
	defaultUnit: string;
	active: boolean;
};

type CreateFormValues = {
	name: string;
	unit: string;
};

type EditFormValues = {
	id: string;
	name: string;
	unit: string;
};

const UUID_RE = /^[0-9a-f-]{36}$/i;

export const load: PageServerLoad = async (event) => {
	const supabase = event.locals.supabase;

	// Read-only list. RLS (raw_materials_select_active) limits rows to users
	// with an active profile. Alphabetical by name.
	const result = await supabase
		.from('raw_materials')
		.select('id, name, default_unit, active')
		.order('name', { ascending: true });
	if (result.error) throw result.error;

	const rows: RawMaterialRow[] = result.data ?? [];

	const materials: RawMaterial[] = rows.map((row) => ({
		id: row.id,
		name: row.name,
		defaultUnit: row.default_unit,
		active: row.active
	}));

	return { materials };
};

export const actions: Actions = {
	// AL1: create one raw material. All business validation lives in the
	// create_raw_material RPC (admin-only); this action pre-validates the raw
	// inputs so users get deterministic Spanish messages instead of RPC
	// tokens, and maps the RPC's English tokens to Spanish.
	create: async (event) => {
		const formData = await event.request.formData();
		const values: CreateFormValues = {
			name: textOf(formData.get('name')),
			unit: textOf(formData.get('unit'))
		};

		if (values.name.trim() === '') {
			return fail(400, { error: 'El nombre no puede estar vacío.', values });
		}

		if (values.unit.trim() === '') {
			return fail(400, { error: 'La unidad no puede estar vacía.', values });
		}

		const result = await event.locals.supabase.rpc('create_raw_material', {
			p_name: values.name,
			p_default_unit: values.unit
		});

		if (result.error) {
			return fail(400, {
				error: rawMaterialErrorMessages(result.error.message, 'No se pudo crear el material.'),
				values
			});
		}

		if (!result.data) {
			return fail(400, { error: 'No se pudo crear el material.', values });
		}

		redirect(303, '/admin/raw-materials');
	},

	// AL1: edit one raw material (name and default unit). The material is
	// identified by a hidden field in the per-card edit form.
	update: async (event) => {
		const formData = await event.request.formData();
		const values: EditFormValues = {
			id: textOf(formData.get('id')),
			name: textOf(formData.get('name')),
			unit: textOf(formData.get('unit'))
		};

		if (!UUID_RE.test(values.id)) {
			return fail(400, { error: 'El material no existe.', values });
		}

		if (values.name.trim() === '') {
			return fail(400, { error: 'El nombre no puede estar vacío.', values });
		}

		if (values.unit.trim() === '') {
			return fail(400, { error: 'La unidad no puede estar vacía.', values });
		}

		const result = await event.locals.supabase.rpc('update_raw_material', {
			p_id: values.id,
			p_name: values.name,
			p_default_unit: values.unit
		});

		if (result.error) {
			return fail(400, {
				error: rawMaterialErrorMessages(result.error.message, 'No se pudo guardar el material.'),
				values
			});
		}

		if (!result.data) {
			return fail(400, { error: 'No se pudo guardar el material.', values });
		}

		redirect(303, '/admin/raw-materials');
	},

	// AL1: activate/deactivate one raw material. Deactivation is soft
	// (active = false); raw materials are never physically deleted.
	set_active: async (event) => {
		const formData = await event.request.formData();
		const id = textOf(formData.get('id'));
		const active = formData.get('active') === 'true';

		if (!UUID_RE.test(id)) {
			return fail(400, { error: 'El material no existe.' });
		}

		const result = await event.locals.supabase.rpc('set_raw_material_active', {
			p_id: id,
			p_active: active
		});

		if (result.error) {
			return fail(400, {
				error: rawMaterialErrorMessages(
					result.error.message,
					'No se pudo cambiar el estado del material.'
				)
			});
		}

		if (!result.data) {
			return fail(400, { error: 'No se pudo cambiar el estado del material.' });
		}

		redirect(303, '/admin/raw-materials');
	}
};

function textOf(value: unknown): string {
	return typeof value === 'string' ? value : '';
}

// Raw-material RPC error tokens (English, developer-facing) to
// user-facing Spanish messages. The default message varies per action.
function rawMaterialErrorMessages(message: string, fallback: string): string {
	switch (message) {
		case 'not_authenticated':
			return 'No hay sesión iniciada.';
		case 'no_active_profile':
			return 'Tu perfil no está activo.';
		case 'insufficient_role':
			return 'No tenés permiso para administrar materiales.';
		case 'raw_material_not_found':
			return 'El material no existe.';
		case 'raw_material_name_exists':
			return 'Ya existe un material con ese nombre.';
		case 'invalid_name':
			return 'El nombre no puede estar vacío.';
		case 'invalid_unit':
			return 'La unidad no puede estar vacía.';
		default:
			return fallback;
	}
}

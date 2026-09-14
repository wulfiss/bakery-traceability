import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import type { Database } from '$lib/types/database.types';

// Explicit row annotation: supabase-js 2.116 under TS 6 does not resolve the
// inferred select type in this toolchain (see AGENTS.md).
type ProductRow = Pick<
	Database['public']['Tables']['products']['Row'],
	'id' | 'name' | 'default_unit' | 'default_shift_code' | 'active'
>;

export type Product = {
	id: string;
	name: string;
	defaultUnit: string;
	defaultShiftCode: string;
	active: boolean;
};

// V5: MAÑANA and NOCHE only (afternoon is historical, never newly assigned).
const SHIFT_CODES = ['morning', 'night'];

type CreateFormValues = {
	name: string;
	unit: string;
	shift: string;
};

type EditFormValues = CreateFormValues & { id: string };

const UUID_RE = /^[0-9a-f-]{36}$/i;

export const load: PageServerLoad = async (event) => {
	const supabase = event.locals.supabase;

	// Read-only list. RLS (products_select_active) limits rows to users with an
	// active profile. Alphabetical by name.
	const result = await supabase
		.from('products')
		.select('id, name, default_unit, default_shift_code, active')
		.order('name', { ascending: true });
	if (result.error) throw result.error;

	const rows: ProductRow[] = result.data ?? [];

	const products: Product[] = rows.map((row) => ({
		id: row.id,
		name: row.name,
		defaultUnit: row.default_unit,
		defaultShiftCode: row.default_shift_code,
		active: row.active
	}));

	return { products };
};

export const actions: Actions = {
	// AL3: create one product. All business validation lives in the
	// create_product RPC (admin-only); this action pre-validates the raw input
	// so users get deterministic Spanish messages instead of RPC tokens, and
	// maps the RPC's English tokens to Spanish. Product names are not
	// uniqueness-constrained (the H1 schema spec does not require it).
	create: async (event) => {
		const formData = await event.request.formData();
		const values: CreateFormValues = {
			name: textOf(formData.get('name')),
			unit: textOf(formData.get('unit')),
			shift: textOf(formData.get('shift'))
		};

		if (values.name.trim() === '') {
			return fail(400, { error: 'El nombre no puede estar vacío.', values });
		}
		if (values.unit.trim() === '') {
			return fail(400, { error: 'La unidad no puede estar vacía.', values });
		}
		if (!SHIFT_CODES.includes(values.shift)) {
			return fail(400, { error: 'El turno debe ser MAÑANA o NOCHE.', values });
		}

		const result = await event.locals.supabase.rpc('create_product', {
			p_name: values.name,
			p_default_unit: values.unit,
			p_default_shift_code: values.shift
		});

		if (result.error) {
			return fail(400, {
				error: productErrorMessages(result.error.message, 'No se pudo crear el producto.'),
				values
			});
		}

		if (!result.data) {
			return fail(400, { error: 'No se pudo crear el producto.', values });
		}

		redirect(303, '/admin/products');
	},

	// AL3: edit one product (name, default unit, default shift). The product is
	// identified by a hidden field in the per-card edit form.
	update: async (event) => {
		const formData = await event.request.formData();
		const values: EditFormValues = {
			id: textOf(formData.get('id')),
			name: textOf(formData.get('name')),
			unit: textOf(formData.get('unit')),
			shift: textOf(formData.get('shift'))
		};

		if (!UUID_RE.test(values.id)) {
			return fail(400, { error: 'El producto no existe.', values });
		}
		if (values.name.trim() === '') {
			return fail(400, { error: 'El nombre no puede estar vacío.', values });
		}
		if (values.unit.trim() === '') {
			return fail(400, { error: 'La unidad no puede estar vacía.', values });
		}
		if (!SHIFT_CODES.includes(values.shift)) {
			return fail(400, { error: 'El turno debe ser MAÑANA o NOCHE.', values });
		}

		const result = await event.locals.supabase.rpc('update_product', {
			p_id: values.id,
			p_name: values.name,
			p_default_unit: values.unit,
			p_default_shift_code: values.shift
		});

		if (result.error) {
			return fail(400, {
				error: productErrorMessages(result.error.message, 'No se pudo guardar el producto.'),
				values
			});
		}

		if (!result.data) {
			return fail(400, { error: 'No se pudo guardar el producto.', values });
		}

		redirect(303, '/admin/products');
	},

	// AL3: activate/deactivate one product. Deactivation is soft (active =
	// false); products are never physically deleted (six tables reference
	// products with RESTRICT FKs).
	set_active: async (event) => {
		const formData = await event.request.formData();
		const id = textOf(formData.get('id'));
		const active = formData.get('active') === 'true';

		if (!UUID_RE.test(id)) {
			return fail(400, { error: 'El producto no existe.' });
		}

		const result = await event.locals.supabase.rpc('set_product_active', {
			p_id: id,
			p_active: active
		});

		if (result.error) {
			return fail(400, {
				error: productErrorMessages(
					result.error.message,
					'No se pudo cambiar el estado del producto.'
				)
			});
		}

		if (!result.data) {
			return fail(400, { error: 'No se pudo cambiar el estado del producto.' });
		}

		redirect(303, '/admin/products');
	}
};

function textOf(value: unknown): string {
	return typeof value === 'string' ? value : '';
}

// Product RPC error tokens (English, developer-facing) to user-facing Spanish
// messages. The default message varies per action.
function productErrorMessages(message: string, fallback: string): string {
	switch (message) {
		case 'not_authenticated':
			return 'No hay sesión iniciada.';
		case 'no_active_profile':
			return 'Tu perfil no está activo.';
		case 'insufficient_role':
			return 'No tenés permiso para administrar productos.';
		case 'product_not_found':
			return 'El producto no existe.';
		case 'invalid_name':
			return 'El nombre no puede estar vacío.';
		case 'invalid_unit':
			return 'La unidad no puede estar vacía.';
		case 'invalid_shift':
			return 'El turno debe ser MAÑANA o NOCHE.';
		default:
			return fallback;
	}
}

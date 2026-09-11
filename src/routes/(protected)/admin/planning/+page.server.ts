import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import type { Database } from '$lib/types/database.types';

// Explicit row annotation: supabase-js 2.116 under TS 6 does not resolve the
// inferred select type in this toolchain (see AGENTS.md).
type PlanItemRow = Pick<
	Database['public']['Tables']['production_plan_items']['Row'],
	| 'id'
	| 'weekday'
	| 'shift_code'
	| 'product_id'
	| 'planned_quantity'
	| 'unit'
	| 'sort_order'
	| 'active'
> & {
	products: Pick<Database['public']['Tables']['products']['Row'], 'name'> | null;
};

type ProductOption = {
	id: string;
	name: string;
};

export type PlanItem = {
	id: string;
	weekday: number;
	shiftCode: string;
	productId: string;
	productName: string;
	plannedQuantity: string;
	unit: string;
	sortOrder: number;
	active: boolean;
};

type CreateFormValues = {
	weekday: string;
	shift: string;
	productId: string;
	quantity: string;
	unit: string;
};

type EditFormValues = CreateFormValues & { id: string };

const UUID_RE = /^[0-9a-f-]{36}$/i;
const SHIFT_CODES = ['morning', 'afternoon', 'night'] as const;

// Display rank so the list reads MAÑANA, TARDE, NOCHE (alphabetical order of
// the internal codes would give morning, night, afternoon).
const SHIFT_RANK: Record<string, number> = { morning: 0, afternoon: 1, night: 2 };

export const load: PageServerLoad = async (event) => {
	const supabase = event.locals.supabase;

	// Products feed the weekday/shift/product selects.
	const productResult = await supabase.from('products').select('id, name').order('name');
	if (productResult.error) throw productResult.error;
	const productRows = productResult.data as Pick<
		Database['public']['Tables']['products']['Row'],
		'id' | 'name'
	>[];
	const products: ProductOption[] = productRows.map((row) => ({
		id: row.id,
		name: row.name
	}));

	// Plan items, with the product name embedded.
	const itemResult = await supabase
		.from('production_plan_items')
		.select(
			'id, weekday, shift_code, product_id, planned_quantity, unit, sort_order, active, products(name)'
		)
		.order('weekday', { ascending: true })
		.order('sort_order', { ascending: true });
	if (itemResult.error) throw itemResult.error;
	const itemRows: PlanItemRow[] = itemResult.data ?? [];

	// Deterministic display order: weekday, then MAÑANA/TARDE/NOCHE, then the
	// stored sort_order.
	const sorted = [...itemRows].sort((a, b) => {
		if (a.weekday !== b.weekday) return a.weekday - b.weekday;
		const rankA = SHIFT_RANK[a.shift_code] ?? 99;
		const rankB = SHIFT_RANK[b.shift_code] ?? 99;
		if (rankA !== rankB) return rankA - rankB;
		return a.sort_order - b.sort_order;
	});

	const planItems: PlanItem[] = sorted.map((row) => ({
		id: row.id,
		weekday: Number(row.weekday),
		shiftCode: row.shift_code,
		productId: row.product_id,
		productName: row.products?.name ?? '',
		plannedQuantity: String(row.planned_quantity),
		unit: row.unit,
		sortOrder: Number(row.sort_order),
		active: row.active
	}));

	return { products, planItems };
};

// Shared input parsing/pre-validation so users get a deterministic Spanish
// message before any RPC round-trip. Returns the Spanish error or null.
function validatePlanValues(
	weekdayRaw: string,
	shiftRaw: string,
	productRaw: string,
	quantityRaw: string,
	unitRaw: string
): string | null {
	if (!/^[0-9]+$/.test(weekdayRaw) || Number(weekdayRaw) < 1 || Number(weekdayRaw) > 7) {
		return 'El día debe ser entre lunes y domingo.';
	}
	if (!(SHIFT_CODES as readonly string[]).includes(shiftRaw)) {
		return 'El turno debe ser MAÑANA, TARDE o NOCHE.';
	}
	if (!UUID_RE.test(productRaw)) {
		return 'El producto no existe.';
	}
	const quantity = Number(quantityRaw);
	if (!Number.isFinite(quantity) || quantity <= 0) {
		return 'La cantidad debe ser mayor que cero.';
	}
	if (unitRaw.trim() === '') {
		return 'La unidad no puede estar vacía.';
	}
	return null;
}

export const actions: Actions = {
	// AL5: create one weekly plan item. All business validation lives in the
	// create_production_plan_item RPC (admin-only); this action pre-validates
	// the raw inputs and maps the RPC's English tokens to Spanish. At most one
	// active row per (weekday, shift, product, unit) (already_planned).
	create: async (event) => {
		const formData = await event.request.formData();
		const values: CreateFormValues = {
			weekday: textOf(formData.get('weekday')),
			shift: textOf(formData.get('shift')),
			productId: textOf(formData.get('productId')),
			quantity: textOf(formData.get('quantity')),
			unit: textOf(formData.get('unit'))
		};

		const invalid = validatePlanValues(
			values.weekday,
			values.shift,
			values.productId,
			values.quantity,
			values.unit
		);
		if (invalid) {
			return fail(400, { error: invalid, values });
		}

		const result = await event.locals.supabase.rpc('create_production_plan_item', {
			p_weekday: Number(values.weekday),
			p_shift_code: values.shift,
			p_product_id: values.productId,
			p_planned_quantity: Number(values.quantity),
			p_unit: values.unit
		});

		if (result.error) {
			return fail(400, {
				error: planItemErrorMessages(
					result.error.message,
					'No se pudo crear el ítem de planificación.'
				),
				values
			});
		}

		if (!result.data) {
			return fail(400, {
				error: 'No se pudo crear el ítem de planificación.',
				values
			});
		}

		redirect(303, '/admin/planning');
	},

	// AL5: edit one plan item. The item is identified by a hidden field in the
	// per-card edit form.
	update: async (event) => {
		const formData = await event.request.formData();
		const values: EditFormValues = {
			id: textOf(formData.get('id')),
			weekday: textOf(formData.get('weekday')),
			shift: textOf(formData.get('shift')),
			productId: textOf(formData.get('productId')),
			quantity: textOf(formData.get('quantity')),
			unit: textOf(formData.get('unit'))
		};

		if (!UUID_RE.test(values.id)) {
			return fail(400, { error: 'El ítem de planificación no existe.', values });
		}

		const invalid = validatePlanValues(
			values.weekday,
			values.shift,
			values.productId,
			values.quantity,
			values.unit
		);
		if (invalid) {
			return fail(400, { error: invalid, values });
		}

		const result = await event.locals.supabase.rpc('update_production_plan_item', {
			p_id: values.id,
			p_weekday: Number(values.weekday),
			p_shift_code: values.shift,
			p_product_id: values.productId,
			p_planned_quantity: Number(values.quantity),
			p_unit: values.unit
		});

		if (result.error) {
			return fail(400, {
				error: planItemErrorMessages(
					result.error.message,
					'No se pudo guardar el ítem de planificación.'
				),
				values
			});
		}

		if (!result.data) {
			return fail(400, {
				error: 'No se pudo guardar el ítem de planificación.',
				values
			});
		}

		redirect(303, '/admin/planning');
	},

	// AL5: activate/deactivate one plan item. Deactivation is soft (active =
	// false); a deactivated item is never generated as a base request.
	set_active: async (event) => {
		const formData = await event.request.formData();
		const id = textOf(formData.get('id'));
		const active = formData.get('active') === 'true';

		if (!UUID_RE.test(id)) {
			return fail(400, { error: 'El ítem de planificación no existe.' });
		}

		const result = await event.locals.supabase.rpc('set_production_plan_item_active', {
			p_id: id,
			p_active: active
		});

		if (result.error) {
			return fail(400, {
				error: planItemErrorMessages(
					result.error.message,
					'No se pudo cambiar el estado del ítem de planificación.'
				)
			});
		}

		if (!result.data) {
			return fail(400, { error: 'No se pudo cambiar el estado del ítem de planificación.' });
		}

		redirect(303, '/admin/planning');
	}
};

function textOf(value: unknown): string {
	return typeof value === 'string' ? value : '';
}

// Plan-item RPC error tokens (English, developer-facing) to user-facing
// Spanish messages. The default message varies per action.
function planItemErrorMessages(message: string, fallback: string): string {
	switch (message) {
		case 'not_authenticated':
			return 'No hay sesión iniciada.';
		case 'no_active_profile':
			return 'Tu perfil no está activo.';
		case 'insufficient_role':
			return 'No tenés permiso para administrar la planificación.';
		case 'production_plan_item_not_found':
			return 'El ítem de planificación no existe.';
		case 'product_not_found':
			return 'El producto no existe.';
		case 'invalid_weekday':
			return 'El día debe ser entre lunes y domingo.';
		case 'invalid_shift':
			return 'El turno debe ser MAÑANA, TARDE o NOCHE.';
		case 'invalid_quantity':
			return 'La cantidad debe ser mayor que cero.';
		case 'invalid_unit':
			return 'La unidad no puede estar vacía.';
		case 'already_planned':
			return 'Ya existe un ítem activo para ese día, turno, producto y unidad.';
		default:
			return fallback;
	}
}

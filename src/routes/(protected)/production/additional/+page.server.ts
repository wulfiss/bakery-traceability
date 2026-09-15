import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { SHIFTS, SHIFT_COOKIE, type Shift } from '$lib/shifts';
import type { Database } from '$lib/types/database.types';

// Explicit row annotations: supabase-js 2.116 under TS 6 does not resolve the
// inferred select type in this toolchain (see AGENTS.md).
type ProductLite = Pick<
	Database['public']['Tables']['products']['Row'],
	'id' | 'name' | 'default_unit'
>;

export const load: PageServerLoad = async (event) => {
	const supabase = event.locals.supabase;

	// The currently selected shift is the default for the Turno field;
	// it is read from the non-sensitive cookie and never inferred from time.
	const cookieValue = event.cookies.get(SHIFT_COOKIE);
	const shift: Shift | null = SHIFTS.includes(cookieValue as Shift) ? (cookieValue as Shift) : null;

	const productsResult = await supabase
		.from('products')
		.select('id, name, default_unit')
		.eq('active', true)
		.order('name', { ascending: true });
	if (productsResult.error) throw productsResult.error;

	const products: ProductLite[] = productsResult.data ?? [];

	return {
		shift,
		products: products.map((product) => ({
			id: product.id,
			name: product.name,
			defaultUnit: product.default_unit
		}))
	};
};

// RPC error tokens (English, developer-facing) to user-facing Spanish messages.
const rpcErrors: Record<string, string> = {
	not_authenticated: 'Tu sesión no es válida. Inicia sesión de nuevo.',
	no_active_profile: 'Tu perfil no está activo. Contacta a una persona con administración.',
	production_day_not_found: 'No se encontró el día de producción.',
	product_not_found: 'El producto seleccionado no existe o no está activo.',
	invalid_quantity: 'La cantidad debe ser mayor que cero.',
	invalid_unit: 'La unidad no puede estar vacía.',
	invalid_shift: 'El turno seleccionado no es válido.'
};

const toText = (value: string | File | null): string | null =>
	typeof value === 'string' ? value : null;

// V5.7: the additional-production form no longer carries a reason; new
// requests save reason_code = NULL / reason_note = NULL (the RPC defaults).
type Submitted = {
	product_id: string | null;
	requested_quantity: string | null;
	unit: string | null;
	shift_code: string | null;
};

export const actions: Actions = {
	default: async (event) => {
		const formData = await event.request.formData();

		const submitted: Submitted = {
			product_id: toText(formData.get('product_id')),
			requested_quantity: toText(formData.get('requested_quantity')),
			unit: toText(formData.get('unit')),
			shift_code: toText(formData.get('shift_code'))
		};

		const quantity =
			submitted.requested_quantity === null ? NaN : Number(submitted.requested_quantity);

		if (
			!submitted.product_id ||
			Number.isNaN(quantity) ||
			!submitted.unit ||
			!submitted.shift_code
		) {
			return fail(400, { error: 'Completa los datos de la producción adicional.', ...submitted });
		}

		// Ensure today's production day exists (idempotent; Cordoba business date).
		const dayResult = await event.locals.supabase.rpc('ensure_production_day');
		if (dayResult.error) throw dayResult.error;
		const productionDayId: string | null = dayResult.data;
		if (!productionDayId)
			throw dayResult.error ?? new Error('ensure_production_day returned no id');

		// V5.7: no reason fields are sent; the RPC defaults store NULL/NULL.
		const rpcArgs: Database['public']['Functions']['create_additional_production_request']['Args'] =
			{
				p_production_day_id: productionDayId,
				p_product_id: submitted.product_id,
				p_requested_quantity: quantity,
				p_unit: submitted.unit,
				p_shift_code: submitted.shift_code
			};

		const { error } = await event.locals.supabase.rpc(
			'create_additional_production_request',
			rpcArgs
		);

		if (error) {
			return fail(400, { error: rpcErrors[error.message] ?? error.message, ...submitted });
		}

		// The selected-shift cookie is untouched, so the selection is preserved.
		redirect(303, '/production');
	}
};

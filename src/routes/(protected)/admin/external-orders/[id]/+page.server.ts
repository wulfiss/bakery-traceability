import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import type { Database } from '$lib/types/database.types';

// Explicit row annotations: supabase-js 2.116 under TS 6 does not resolve the
// inferred select type in this toolchain (see AGENTS.md).
type OrderRow = Pick<
	Database['public']['Tables']['external_orders']['Row'],
	'id' | 'order_number' | 'customer_name' | 'requested_date' | 'status'
>;

type ItemRow = Pick<
	Database['public']['Tables']['external_order_items']['Row'],
	'id' | 'product_id' | 'quantity' | 'unit' | 'shift_code' | 'notes'
>;

type ProductRow = Pick<
	Database['public']['Tables']['products']['Row'],
	'id' | 'name' | 'default_unit' | 'default_shift_code' | 'active'
>;

export type OrderView = {
	id: string;
	orderNumber: string;
	customerName: string;
	requestedDate: string;
	status: OrderRow['status'];
};

export type ItemView = {
	id: string;
	productName: string;
	quantity: number;
	unit: string;
	shiftCode: ItemRow['shift_code'];
	notes: string | null;
};

export type ProductOption = {
	id: string;
	name: string;
	defaultUnit: string;
	defaultShiftCode: string;
};

type ItemFormValues = {
	productId: string;
	quantity: string;
	unit: string;
	shiftCode: string;
	notes: string;
};

const VALID_SHIFTS = ['morning', 'afternoon', 'night'];
const UUID_RE = /^[0-9a-f-]{36}$/i;

export const load: PageServerLoad = async (event) => {
	const supabase = event.locals.supabase;
	const orderId = event.params.id;

	// A malformed id would make PostgREST fail the uuid cast with a 500;
	// treat it as a plain not-found (same behavior as the action precheck).
	if (!UUID_RE.test(orderId)) {
		return { order: null, items: [], products: [] };
	}

	const orderResult = await supabase
		.from('external_orders')
		.select('id, order_number, customer_name, requested_date, status')
		.eq('id', orderId)
		.maybeSingle();
	if (orderResult.error) throw orderResult.error;

	if (!orderResult.data) return { order: null, items: [], products: [] };

	const order: OrderRow = orderResult.data;

	// Items are rendered exactly as stored: their shift is never recalculated
	// from the product's current default (AK3 rule).
	const itemsResult = await supabase
		.from('external_order_items')
		.select('id, product_id, quantity, unit, shift_code, notes')
		.eq('external_order_id', orderId)
		.order('created_at', { ascending: true });
	if (itemsResult.error) throw itemsResult.error;
	const items: ItemRow[] = itemsResult.data ?? [];

	// All products (names for stored items, even inactive ones); the form
	// offers only the active ones.
	const productsResult = await supabase
		.from('products')
		.select('id, name, default_unit, default_shift_code, active')
		.order('name', { ascending: true });
	if (productsResult.error) throw productsResult.error;
	const products: ProductRow[] = productsResult.data ?? [];

	const productNameById = new Map(products.map((product) => [product.id, product.name]));

	return {
		order: {
			id: order.id,
			orderNumber: order.order_number,
			customerName: order.customer_name,
			requestedDate: formatRequestedDate(order.requested_date),
			status: order.status
		},
		items: items.map((item) => ({
			id: item.id,
			productName: productNameById.get(item.product_id) ?? 'Producto desconocido',
			quantity: item.quantity,
			unit: item.unit,
			shiftCode: item.shift_code,
			notes: item.notes
		})),
		products: products
			.filter((product) => product.active)
			.map((product) => ({
				id: product.id,
				name: product.name,
				defaultUnit: product.default_unit,
				defaultShiftCode: product.default_shift_code
			}))
	};
};

export const actions: Actions = {
	// AK3: add one product item to the order identified by the route param.
	// Final shift/unit are submitted by the form (preselected from the product
	// defaults client-side) and stored verbatim. All business validation lives
	// in the add_external_order_item RPC; this action pre-validates the raw
	// inputs so users get deterministic Spanish messages instead of PostgREST
	// cast errors, and maps the RPC's English tokens to Spanish.
	add_item: async (event) => {
		const orderId = event.params.id;
		const formData = await event.request.formData();
		const values: ItemFormValues = {
			productId: textOf(formData.get('product_id')),
			quantity: textOf(formData.get('quantity')),
			unit: textOf(formData.get('unit')),
			shiftCode: textOf(formData.get('shift_code')),
			notes: textOf(formData.get('notes'))
		};

		if (!UUID_RE.test(orderId)) {
			return fail(400, { error: 'El pedido no existe.', values });
		}

		if (!UUID_RE.test(values.productId)) {
			return fail(400, { error: 'Selecciona un producto.', values });
		}

		const quantity = Number(values.quantity);
		if (!Number.isFinite(quantity) || quantity <= 0) {
			return fail(400, { error: 'La cantidad debe ser mayor a cero.', values });
		}

		if (values.unit.trim() === '') {
			return fail(400, { error: 'La unidad no puede estar vacía.', values });
		}

		if (!VALID_SHIFTS.includes(values.shiftCode)) {
			return fail(400, { error: 'El turno de producción no es válido.', values });
		}

		const result = await event.locals.supabase.rpc('add_external_order_item', {
			p_external_order_id: orderId,
			p_product_id: values.productId,
			p_quantity: quantity,
			p_unit: values.unit,
			p_shift_code: values.shiftCode,
			p_notes: values.notes
		});

		if (result.error) {
			return fail(400, { error: addItemErrorMessages(result.error.message), values });
		}

		if (!result.data) {
			return fail(400, { error: 'No se pudo agregar el producto.', values });
		}

		redirect(303, `/admin/external-orders/${orderId}`);
	}
};

function textOf(value: unknown): string {
	return typeof value === 'string' ? value : '';
}

// 'YYYY-MM-DD' (stored) -> 'DD/MM/YYYY' (UI display only).
function formatRequestedDate(value: string): string {
	const parts = value.split('-');
	if (parts.length !== 3) return value;
	return `${parts[2]}/${parts[1]}/${parts[0]}`;
}

// add_external_order_item error tokens (English, developer-facing) to
// user-facing Spanish messages.
function addItemErrorMessages(message: string): string {
	switch (message) {
		case 'not_authenticated':
			return 'No hay sesión iniciada.';
		case 'no_active_profile':
			return 'Tu perfil no está activo.';
		case 'insufficient_role':
			return 'No tenés permiso para agregar productos.';
		case 'order_not_found':
			return 'El pedido no existe.';
		case 'product_not_available':
			return 'El producto no está disponible.';
		case 'invalid_quantity':
			return 'La cantidad debe ser mayor a cero.';
		case 'invalid_unit':
			return 'La unidad no puede estar vacía.';
		case 'invalid_shift':
			return 'El turno de producción no es válido.';
		default:
			return 'No se pudo agregar el producto.';
	}
}

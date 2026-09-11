import { fail, redirect } from '@sveltejs/kit';
import type { Actions } from './$types';

type OrderFormValues = {
	orderNumber: string;
	customerName: string;
	requestedDate: string;
	deliveryTime: string;
	notes: string;
};

export const actions: Actions = {
	// AK2: create the external-order HEADER only (items are managed in a later
	// phase). All business validation (auth, supervisor/admin role, duplicate
	// number, formats) lives in the create_external_order RPC; this action
	// maps its English tokens to Spanish messages and preserves the submitted
	// values on failure.
	create: async (event) => {
		const formData = await event.request.formData();
		const values: OrderFormValues = {
			orderNumber: textOf(formData.get('order_number')),
			customerName: textOf(formData.get('customer_name')),
			requestedDate: textOf(formData.get('requested_date')),
			deliveryTime: textOf(formData.get('delivery_time')),
			notes: textOf(formData.get('notes'))
		};

		// A blank date would fail as a Postgres cast error before the RPC runs;
		// reject it here so the mapped Spanish message is deterministic.
		if (values.requestedDate === '') {
			return fail(400, { error: 'La fecha requerida no es válida.', values });
		}

		const result = await event.locals.supabase.rpc('create_external_order', {
			p_order_number: values.orderNumber,
			p_customer_name: values.customerName,
			p_requested_date: values.requestedDate,
			p_delivery_time: values.deliveryTime,
			p_notes: values.notes
		});

		if (result.error) {
			return fail(400, { error: createOrderErrorMessages(result.error.message), values });
		}

		if (!result.data) {
			return fail(400, { error: 'No se pudo crear el pedido.', values });
		}

		redirect(303, '/admin/external-orders');
	}
};

function textOf(value: unknown): string {
	return typeof value === 'string' ? value : '';
}

// create_external_order error tokens (English, developer-facing) to
// user-facing Spanish messages.
function createOrderErrorMessages(message: string): string {
	switch (message) {
		case 'not_authenticated':
			return 'No hay sesión iniciada.';
		case 'no_active_profile':
			return 'Tu perfil no está activo.';
		case 'insufficient_role':
			return 'No tenés permiso para crear pedidos.';
		case 'invalid_order_number':
			return 'El N° pedido no puede estar vacío.';
		case 'order_number_exists':
			return 'El N° pedido ya existe.';
		case 'invalid_customer_name':
			return 'El cliente no puede estar vacío.';
		case 'invalid_requested_date':
			return 'La fecha requerida no es válida.';
		case 'invalid_delivery_time':
			return 'La hora de entrega no es válida.';
		default:
			return 'No se pudo crear el pedido.';
	}
}

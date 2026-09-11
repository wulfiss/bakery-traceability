import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { SHIFTS, SHIFT_COOKIE, type Shift } from '$lib/shifts';
import type { Database } from '$lib/types/database.types';

const ONE_YEAR_SECONDS = 60 * 60 * 24 * 365;

// Explicit row annotations: supabase-js 2.116 under TS 6 does not resolve the
// inferred select type in this toolchain (see AGENTS.md).
type ProductionRequestLite = Pick<
	Database['public']['Tables']['production_requests']['Row'],
	'id' | 'source_type' | 'product_id' | 'requested_quantity' | 'unit' | 'status'
>;
type ProductLite = Pick<Database['public']['Tables']['products']['Row'], 'id' | 'name'>;

export type RequestItem = {
	id: string;
	productName: string;
	quantity: number;
	unit: string;
	status: Database['public']['Tables']['production_requests']['Row']['status'];
};

export const load: PageServerLoad = async (event) => {
	const supabase = event.locals.supabase;

	// 1. Ensure today's production day exists (idempotent; Cordoba business date).
	const dayResult = await supabase.rpc('ensure_production_day');
	if (dayResult.error) throw dayResult.error;
	const productionDayId: string | null = dayResult.data;
	if (!productionDayId) throw dayResult.error ?? new Error('ensure_production_day returned no id');

	// 2. and 3. Ensure base and external-order requests exist (idempotent).
	// Sequential awaits: Promise.all loses the result types in this
	// supabase-js version (see AGENTS.md).
	const baseResult = await supabase.rpc('ensure_base_production_requests', {
		p_production_day_id: productionDayId
	});
	if (baseResult.error) throw baseResult.error;
	const externalResult = await supabase.rpc('ensure_external_order_requests', {
		p_production_day_id: productionDayId
	});
	if (externalResult.error) throw externalResult.error;

	// 4. Read the selected shift from the non-sensitive cookie.
	const cookieValue = event.cookies.get(SHIFT_COOKIE);
	const shift: Shift | null = SHIFTS.includes(cookieValue as Shift) ? (cookieValue as Shift) : null;

	// 7. Load ONLY today's requests matching the selected shift.
	const base: RequestItem[] = [];
	const external: RequestItem[] = [];
	const additional: RequestItem[] = [];

	if (shift) {
		const requestsResult = await supabase
			.from('production_requests')
			.select('id, source_type, product_id, requested_quantity, unit, status')
			.eq('production_day_id', productionDayId)
			.eq('shift_code', shift);
		if (requestsResult.error) throw requestsResult.error;

		const productsResult = await supabase.from('products').select('id, name');
		if (productsResult.error) throw productsResult.error;

		const requests: ProductionRequestLite[] = requestsResult.data ?? [];
		const products: ProductLite[] = productsResult.data ?? [];
		const productNames = new Map<string, string>(
			products.map((product) => [product.id, product.name])
		);

		for (const request of requests) {
			const item: RequestItem = {
				id: request.id,
				productName: productNames.get(request.product_id) ?? '—',
				quantity: request.requested_quantity,
				unit: request.unit,
				status: request.status
			};
			if (request.source_type === 'base') base.push(item);
			else if (request.source_type === 'external_order') external.push(item);
			else additional.push(item);
		}
	}

	// 8. AJ1: shift progress, computed in memory from the requests loaded
	// above and never stored in the DB. "total" counts every request of the
	// selected shift; "completed" counts those with status 'completed'.
	const all = [...base, ...external, ...additional];
	const progress = {
		completed: all.filter((item) => item.status === 'completed').length,
		total: all.length
	};

	return { shift, base, external, additional, progress };
};

export const actions: Actions = {
	// Persist the selected shift (UI preference only) and re-render the page.
	select: async (event) => {
		const formData = await event.request.formData();
		const value =
			typeof formData.get('shift') === 'string' ? (formData.get('shift') as string) : '';

		if (!SHIFTS.includes(value as Shift)) {
			return redirect(303, '/production');
		}

		event.cookies.set(SHIFT_COOKIE, value, {
			path: '/',
			httpOnly: true,
			sameSite: 'lax',
			maxAge: ONE_YEAR_SECONDS
		});
		redirect(303, '/production');
	},

	// Go back to the shift selection screen.
	change: async (event) => {
		event.cookies.delete(SHIFT_COOKIE, { path: '/' });
		redirect(303, '/production');
	},

	// Start the production batch for one pending request. All business rules
	// (pending state, active recipe, current lots, safe batch code) live in the
	// start_production_batch RPC; this action only maps its error tokens to
	// Spanish user messages.
	start: async (event) => {
		const formData = await event.request.formData();
		const requestId =
			typeof formData.get('request_id') === 'string' ? (formData.get('request_id') as string) : '';

		if (!requestId) {
			return fail(400, { error: 'No se puede iniciar la elaboración.', missingLots: [] });
		}

		const result = await event.locals.supabase.rpc('start_production_batch', {
			p_production_request_id: requestId
		});
		if (result.error) {
			const message = result.error.message;
			if (message.startsWith('missing_material_lot:')) {
				const names = message
					.slice('missing_material_lot:'.length)
					.split(',')
					.map((name: string) => name.trim())
					.filter((name: string) => name !== '');
				return fail(400, {
					error: 'No se puede iniciar la elaboración.',
					missingLots: names
				});
			}
			return fail(400, { error: startErrorMessages(message), missingLots: [] });
		}

		const batch = result.data;
		if (!batch?.batch_id) {
			return fail(400, { error: 'No se puede iniciar la elaboración.', missingLots: [] });
		}
		redirect(303, `/production/${batch.batch_id}`);
	}
};

// start_production_batch error tokens (English, developer-facing) to
// user-facing Spanish messages.
function startErrorMessages(message: string): string {
	switch (message) {
		case 'production_request_not_found':
			return 'La producción no existe.';
		case 'request_not_pending':
			return 'La producción ya fue iniciada.';
		case 'no_recipe':
			return 'El producto no tiene receta.';
		case 'no_active_version':
			return 'El producto no tiene una versión de receta activa.';
		case 'ambiguous_recipes':
			return 'El producto tiene varias recetas con versión activa.';
		case 'not_authenticated':
			return 'No hay sesión iniciada.';
		case 'no_active_profile':
			return 'Tu perfil no está activo.';
		default:
			return 'No se puede iniciar la elaboración.';
	}
}

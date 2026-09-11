import { redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import type { Database } from '$lib/types/database.types';

// The selected shift is a UI preference only (cookie `bakery_shift`).
// It is never authorization and never inferred from the current time.
export type Shift = 'morning' | 'afternoon' | 'night';
const SHIFTS: Shift[] = ['morning', 'afternoon', 'night'];
const SHIFT_COOKIE = 'bakery_shift';
const ONE_YEAR_SECONDS = 60 * 60 * 24 * 365;

// Explicit row annotations: supabase-js 2.116 under TS 6 does not resolve the
// inferred select type in this toolchain (see AGENTS.md).
type ProductionRequestLite = Pick<
	Database['public']['Tables']['production_requests']['Row'],
	'id' | 'source_type' | 'product_id' | 'requested_quantity' | 'unit'
>;
type ProductLite = Pick<Database['public']['Tables']['products']['Row'], 'id' | 'name'>;

export type RequestItem = {
	id: string;
	productName: string;
	quantity: number;
	unit: string;
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
			.select('id, source_type, product_id, requested_quantity, unit')
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
				unit: request.unit
			};
			if (request.source_type === 'base') base.push(item);
			else if (request.source_type === 'external_order') external.push(item);
			else additional.push(item);
		}
	}

	return { shift, base, external, additional };
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
	}
};

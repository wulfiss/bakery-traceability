import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { spanishWeekdayLabel } from '$lib/weekday';
import type { Database } from '$lib/types/database.types';

// Explicit row annotations: supabase-js 2.116 under TS 6 does not resolve the
// inferred select type in this toolchain (see AGENTS.md).
type ProductLite = Pick<Database['public']['Tables']['products']['Row'], 'id' | 'name'>;
type ProductionDayLite = Pick<
	Database['public']['Tables']['production_days']['Row'],
	'production_date'
>;
type SelectionLite = Pick<
	Database['public']['Tables']['daily_production_selections']['Row'],
	'id' | 'suggestion_id' | 'status'
>;
type SelectionItemLite = Pick<
	Database['public']['Tables']['daily_production_selection_items']['Row'],
	'id' | 'product_id' | 'shift_code' | 'quantity' | 'unit' | 'is_selected' | 'production_request_id'
>;
type SuggestionLite = Pick<Database['public']['Tables']['production_suggestions']['Row'], 'code'>;
type RequestLite = Pick<
	Database['public']['Tables']['production_requests']['Row'],
	'id' | 'status'
>;

// One line of the day's snapshot (V6.10): checkable through the secure
// toggle RPC; locked when its linked production request is in progress or
// completed.
export type ReviewLine = {
	itemId: string;
	productId: string;
	productName: string;
	quantity: number;
	unit: string;
	isSelected: boolean;
	locked: boolean;
};

export const load: PageServerLoad = async (event) => {
	const supabase = event.locals.supabase;

	// Current business production day (existing database business-date flow).
	const dayResult = await supabase.rpc('ensure_production_day');
	if (dayResult.error) throw dayResult.error;
	const productionDayId: string | null = dayResult.data;
	if (!productionDayId) throw new Error('ensure_production_day returned no day id');

	const dateResult = await supabase
		.from('production_days')
		.select('production_date')
		.eq('id', productionDayId)
		.maybeSingle();
	if (dateResult.error) throw dateResult.error;
	const day: ProductionDayLite | null = dateResult.data ?? null;
	const businessDate = day?.production_date ?? '';

	// The day's selection; without one there is nothing to review yet.
	const selectionResult = await supabase
		.from('daily_production_selections')
		.select('id, suggestion_id, status')
		.eq('production_day_id', productionDayId)
		.maybeSingle();
	if (selectionResult.error) throw selectionResult.error;
	const selection: SelectionLite | null = selectionResult.data ?? null;
	if (!selection) redirect(303, '/production/suggestions');

	const suggestionResult = await supabase
		.from('production_suggestions')
		.select('code')
		.eq('id', selection.suggestion_id)
		.maybeSingle();
	if (suggestionResult.error) throw suggestionResult.error;
	const code = (suggestionResult.data as SuggestionLite | null)?.code ?? '—';

	// The snapshot items (insertion order: sort_order, then id for
	// determinism when a merge kept items from another suggestion).
	const itemsResult = await supabase
		.from('daily_production_selection_items')
		.select('id, product_id, shift_code, quantity, unit, is_selected, production_request_id')
		.eq('daily_selection_id', selection.id)
		.order('sort_order', { ascending: true })
		.order('id', { ascending: true });
	if (itemsResult.error) throw itemsResult.error;
	const items: SelectionItemLite[] = itemsResult.data ?? [];

	// Statuses of the linked production requests (V6.10: an item linked to
	// an in_progress or completed request is locked; pending is not).
	const requestIds = [
		...new Set(items.map((i) => i.production_request_id).filter((id): id is string => id !== null))
	];
	const requestStatuses = new Map<string, string>();
	if (requestIds.length > 0) {
		const requestsResult = await supabase
			.from('production_requests')
			.select('id, status')
			.in('id', requestIds);
		if (requestsResult.error) throw requestsResult.error;
		const requests: RequestLite[] = requestsResult.data ?? [];
		for (const request of requests) requestStatuses.set(request.id, request.status);
	}

	const productsResult = await supabase.from('products').select('id, name');
	if (productsResult.error) throw productsResult.error;
	const products: ProductLite[] = productsResult.data ?? [];
	const productNames = new Map<string, string>(products.map((p) => [p.id, p.name]));

	const morning: ReviewLine[] = [];
	const night: ReviewLine[] = [];
	for (const item of items) {
		const requestStatus = item.production_request_id
			? requestStatuses.get(item.production_request_id)
			: undefined;
		const line: ReviewLine = {
			itemId: item.id,
			productId: item.product_id,
			productName: productNames.get(item.product_id) ?? '—',
			quantity: item.quantity,
			unit: item.unit,
			isSelected: item.is_selected,
			locked: requestStatus === 'in_progress' || requestStatus === 'completed'
		};
		(item.shift_code === 'morning' ? morning : night).push(line);
	}

	return {
		businessDate,
		weekdayLabel: spanishWeekdayLabel(businessDate),
		code,
		status: selection.status === 'confirmed' ? 'confirmed' : 'draft',
		morning,
		night,
		// V6.14 (spec §63): role for the back-to-Admin link (supervisor+ only).
		role: event.locals.profileRole ?? null
	};
};

export const actions: Actions = {
	// V6.10 (spec §59): check/uncheck one snapshot item through the secure
	// RPC (toggle_daily_selection_item). No direct table writes from the
	// browser. Toggling a confirmed selection returns it to draft (RPC).
	toggle: async (event) => {
		const formData = await event.request.formData();
		const itemId =
			typeof formData.get('item_id') === 'string' ? (formData.get('item_id') as string) : '';
		if (!itemId) return fail(400, { error: 'No se pudo identificar el producto.' });

		const args: Database['public']['Functions']['toggle_daily_selection_item']['Args'] = {
			p_item_id: itemId
		};
		const { error } = await event.locals.supabase.rpc('toggle_daily_selection_item', args);
		if (error) return fail(400, { error: toggleErrorMessages(error.message) });
		// Success: no return value, so `use:enhance` refreshes the page data.
	},

	// V6.11 (spec §60): reconcile the day's selection into the existing base
	// production-request model and confirm it, through the secure atomic RPC
	// (no direct table writes from the browser).
	confirm: async (event) => {
		const { error } = await event.locals.supabase.rpc('confirm_daily_production');
		if (error) return fail(400, { error: confirmErrorMessages(error.message) });
		// V6.17: after confirming, the operator goes back to /production,
		// where the confirmed day's requests are started.
		redirect(303, '/production');
	}
};

// toggle_daily_selection_item error tokens (English, developer-facing) to
// user-facing Spanish messages.
function toggleErrorMessages(message: string): string {
	switch (message) {
		case 'item_not_found':
			return 'Este producto ya no está en la lista de hoy.';
		case 'not_current_production_day':
			return 'Solo se pueden modificar los productos de la jornada actual.';
		case 'item_locked':
			return 'Este producto ya inició o completó producción y no se puede modificar.';
		case 'not_authenticated':
			return 'No hay sesión iniciada.';
		case 'no_active_profile':
			return 'Tu perfil no está activo.';
		case 'insufficient_role':
			return 'No tenés permiso para modificar la selección.';
		default:
			return 'No se pudo modificar el producto. Volvé a intentarlo.';
	}
}

// confirm_daily_production error tokens (English, developer-facing) to
// user-facing Spanish messages.
function confirmErrorMessages(message: string): string {
	switch (message) {
		case 'no_selection_for_today':
			return 'Todavía no elegiste la producción de hoy.';
		case 'not_authenticated':
			return 'No hay sesión iniciada.';
		case 'no_active_profile':
			return 'Tu perfil no está activo.';
		case 'insufficient_role':
			return 'No tenés permiso para confirmar la producción.';
		default:
			return 'No se pudo confirmar la producción. Volvé a intentarlo.';
	}
}

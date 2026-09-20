import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { isodowFromDateIso, spanishWeekdayLabel } from '$lib/weekday';
import type { Database } from '$lib/types/database.types';

// Explicit row annotations: supabase-js 2.116 under TS 6 does not resolve the
// inferred select type in this toolchain (see AGENTS.md).
type SuggestionLite = Pick<
	Database['public']['Tables']['production_suggestions']['Row'],
	'id' | 'code'
>;
type SuggestionItemLite = Pick<
	Database['public']['Tables']['production_suggestion_items']['Row'],
	'suggestion_id' | 'product_id' | 'shift_code' | 'suggested_quantity' | 'unit'
>;
type ProductLite = Pick<Database['public']['Tables']['products']['Row'], 'id' | 'name'>;
type ProductionDayLite = Pick<
	Database['public']['Tables']['production_days']['Row'],
	'production_date'
>;
type SelectionLite = Pick<
	Database['public']['Tables']['daily_production_selections']['Row'],
	'suggestion_id' | 'status'
>;

// One product line inside a suggestion card.
export type SuggestionLine = {
	productId: string;
	productName: string;
	quantity: number;
	unit: string;
};

// One selectable option (A/B/C/D/E) with its lines grouped by shift.
// Every line is returned before selection: the UI may collapse long cards
// ("VER TODOS") but the full contents are available in the page data.
export type SuggestionView = {
	id: string;
	code: string;
	morning: SuggestionLine[];
	night: SuggestionLine[];
	itemCount: number;
};

// The day's current selection, when there is one (status banner).
export type CurrentSelection = {
	code: string;
	status: 'draft' | 'confirmed';
};

type ChooseArgs = Database['public']['Functions']['choose_daily_production_suggestion']['Args'];

export const load: PageServerLoad = async (event) => {
	const supabase = event.locals.supabase;

	// 1. Current business production day (existing database business-date flow).
	const dayResult = await supabase.rpc('ensure_production_day');
	if (dayResult.error) throw dayResult.error;
	const productionDayId: string | null = dayResult.data;
	if (!productionDayId) throw new Error('ensure_production_day returned no day id');

	// 2. Stored date of that day (weekday math uses the stored date only).
	const dateResult = await supabase
		.from('production_days')
		.select('production_date')
		.eq('id', productionDayId)
		.maybeSingle();
	if (dateResult.error) throw dateResult.error;
	const day: ProductionDayLite | null = dateResult.data ?? null;
	const businessDate = day?.production_date ?? '';
	const isodow = isodowFromDateIso(businessDate);

	// 3. Only the active suggestions valid for that weekday, in A..E order.
	const suggestionsResult = await supabase
		.from('production_suggestions')
		.select('id, code')
		.eq('active', true)
		.eq('weekday', isodow)
		.order('code', { ascending: true });
	if (suggestionsResult.error) throw suggestionsResult.error;
	const suggestions: SuggestionLite[] = suggestionsResult.data ?? [];

	// 4. Their active items (source order) plus product names, grouped by
	//    shift per suggestion.
	const views: SuggestionView[] = [];
	if (suggestions.length > 0) {
		const itemsResult = await supabase
			.from('production_suggestion_items')
			.select('suggestion_id, product_id, shift_code, suggested_quantity, unit')
			.eq('active', true)
			.in(
				'suggestion_id',
				suggestions.map((s) => s.id)
			)
			.order('sort_order', { ascending: true });
		if (itemsResult.error) throw itemsResult.error;
		const items: SuggestionItemLite[] = itemsResult.data ?? [];

		const productsResult = await supabase.from('products').select('id, name');
		if (productsResult.error) throw productsResult.error;
		const products: ProductLite[] = productsResult.data ?? [];
		const productNames = new Map<string, string>(products.map((p) => [p.id, p.name]));

		// Items already arrive in source (sort_order) order; keep that order
		// inside each shift group of each suggestion (single pass).
		for (const suggestion of suggestions) {
			const view: SuggestionView = {
				id: suggestion.id,
				code: suggestion.code,
				morning: [],
				night: [],
				itemCount: 0
			};
			for (const item of items) {
				if (item.suggestion_id !== suggestion.id) continue;
				const line: SuggestionLine = {
					productId: item.product_id,
					productName: productNames.get(item.product_id) ?? '—',
					quantity: item.suggested_quantity,
					unit: item.unit
				};
				(item.shift_code === 'morning' ? view.morning : view.night).push(line);
			}
			view.itemCount = view.morning.length + view.night.length;
			views.push(view);
		}
	}

	// 5. The day's current selection (if any), for the status banner.
	const selectionResult = await supabase
		.from('daily_production_selections')
		.select('suggestion_id, status')
		.eq('production_day_id', productionDayId)
		.maybeSingle();
	if (selectionResult.error) throw selectionResult.error;
	const selection: SelectionLite | null = selectionResult.data ?? null;

	let current: CurrentSelection | null = null;
	if (selection) {
		const loaded = suggestions.find((s) => s.id === selection.suggestion_id);
		let code = loaded?.code;
		if (!code) {
			// The selected suggestion may belong to another weekday (not in
			// the list above) — fetch its code directly.
			const otherResult = await supabase
				.from('production_suggestions')
				.select('code')
				.eq('id', selection.suggestion_id)
				.maybeSingle();
			if (otherResult.error) throw otherResult.error;
			code = (otherResult.data as SuggestionLite | null)?.code ?? '—';
		}
		current = { code, status: selection.status === 'confirmed' ? 'confirmed' : 'draft' };
	}

	return {
		businessDate,
		weekdayLabel: spanishWeekdayLabel(businessDate),
		suggestions: views,
		current,
		// V6.14 (spec §63): role for the back-to-Admin link (supervisor+ only).
		role: event.locals.profileRole ?? null
	};
};

export const actions: Actions = {
	// V6.9: choose one of the day's suggestions through the secure RPC
	// (choose_daily_production_suggestion, V6.8). After a successful choice
	// the operator goes to the daily review screen/state (V6.10).
	choose: async (event) => {
		const formData = await event.request.formData();
		const suggestionId =
			typeof formData.get('suggestion_id') === 'string'
				? (formData.get('suggestion_id') as string)
				: '';
		if (!suggestionId) return fail(400, { error: 'Elegí una opción de producción.' });

		const dayResult = await event.locals.supabase.rpc('ensure_production_day');
		if (dayResult.error) throw dayResult.error;
		const productionDayId: string | null = dayResult.data;
		if (!productionDayId)
			return fail(400, { error: 'No se pudo identificar el día de producción.' });

		const args: ChooseArgs = {
			p_production_day_id: productionDayId,
			p_suggestion_id: suggestionId
		};
		const { error } = await event.locals.supabase.rpc('choose_daily_production_suggestion', args);
		if (error) return fail(400, { error: chooseErrorMessages(error.message) });

		redirect(303, '/production/suggestions/review');
	}
};

// choose_daily_production_suggestion error tokens (English, developer-facing)
// to user-facing Spanish messages.
function chooseErrorMessages(message: string): string {
	switch (message) {
		case 'production_day_not_found':
			return 'No se pudo identificar el día de producción.';
		case 'suggestion_not_found':
			return 'La opción seleccionada no está disponible.';
		case 'weekday_mismatch':
			return 'La opción no corresponde al día de producción de hoy.';
		case 'not_authenticated':
			return 'No hay sesión iniciada.';
		case 'no_active_profile':
			return 'Tu perfil no está activo.';
		case 'insufficient_role':
			return 'No tenés permiso para elegir la producción.';
		default:
			return 'No se pudo elegir la producción. Volvé a intentarlo.';
	}
}

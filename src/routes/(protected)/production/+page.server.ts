import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { resolveActiveRecipeForProduct } from '$lib/active-recipe';
import { SHIFTS, SHIFT_COOKIE, type Shift } from '$lib/shifts';
import type { Database } from '$lib/types/database.types';

const ONE_YEAR_SECONDS = 60 * 60 * 24 * 365;

// Explicit row annotations: supabase-js 2.116 under TS 6 does not resolve the
// inferred select type in this toolchain (see AGENTS.md).
type ProductionRequestLite = Pick<
	Database['public']['Tables']['production_requests']['Row'],
	| 'id'
	| 'source_type'
	| 'product_id'
	| 'requested_quantity'
	| 'unit'
	| 'status'
	| 'external_order_item_id'
>;
type ProductLite = Pick<Database['public']['Tables']['products']['Row'], 'id' | 'name'>;
type OrderItemLite = Pick<
	Database['public']['Tables']['external_order_items']['Row'],
	'id' | 'external_order_id'
>;
type ExternalOrderLite = Pick<
	Database['public']['Tables']['external_orders']['Row'],
	'id' | 'order_number'
>;
type RecipeProductInputLite = Pick<
	Database['public']['Tables']['recipe_product_inputs']['Row'],
	'id' | 'source_product_id'
>;
type BatchOutputLite = Pick<
	Database['public']['Tables']['batch_outputs']['Row'],
	'id' | 'batch_id' | 'product_id' | 'quantity' | 'unit'
>;
type ParentBatchLite = Pick<
	Database['public']['Tables']['production_batches']['Row'],
	'id' | 'batch_code' | 'production_day_id'
>;
type ProductionDayLite = Pick<
	Database['public']['Tables']['production_days']['Row'],
	'id' | 'production_date'
>;

// AP2: one selectable historical lot for a required produced-product input.
export type SourceLotOption = {
	outputId: string;
	batchCode: string;
	quantity: number;
	unit: string;
	dateLabel: string | null;
};

// AP2: a required produced-product input of the group's active recipe with
// the eligible parent lots (outputs of completed batches of that product).
export type RequiredSourceInput = {
	sourceProductId: string;
	sourceProductName: string;
	options: SourceLotOption[];
};

export type RequestItem = {
	id: string;
	productId: string;
	sourceType: Database['public']['Tables']['production_requests']['Row']['source_type'];
	orderNumber: string | null;
	productName: string;
	quantity: number;
	unit: string;
	status: Database['public']['Tables']['production_requests']['Row']['status'];
};

export type ProductGroup = {
	productId: string;
	productName: string;
	items: RequestItem[];
	total: number | null;
	totalUnit: string | null;
	// AP2: required produced-product inputs of the group's active recipe.
	// Empty when the recipe has none or cannot be resolved (the start RPC
	// then reports the exact reason); the operator must pick one lot per
	// non-empty input before the batch can start.
	productInputs: RequiredSourceInput[];
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
	const groups: ProductGroup[] = [];

	if (shift) {
		const requestsResult = await supabase
			.from('production_requests')
			.select(
				'id, source_type, product_id, requested_quantity, unit, status, external_order_item_id'
			)
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

		// Resolve external order numbers so each external-order contribution
		// can be labelled "Pedido <order number>" (AN1, presentation only).
		const orderNumberByItem = new Map<string, string>();
		const orderItemIds = requests
			.filter((r) => r.source_type === 'external_order' && r.external_order_item_id)
			.map((r) => r.external_order_item_id as string);
		if (orderItemIds.length > 0) {
			const itemsResult = await supabase
				.from('external_order_items')
				.select('id, external_order_id')
				.in('id', orderItemIds);
			if (itemsResult.error) throw itemsResult.error;
			const orderItems: OrderItemLite[] = itemsResult.data ?? [];
			const orderIds = [...new Set(orderItems.map((item) => item.external_order_id))];
			const ordersResult = await supabase
				.from('external_orders')
				.select('id, order_number')
				.in('id', orderIds);
			if (ordersResult.error) throw ordersResult.error;
			const orders: ExternalOrderLite[] = ordersResult.data ?? [];
			const orderNumberById = new Map<string, string>(
				orders.map((order) => [order.id, order.order_number])
			);
			for (const orderItem of orderItems) {
				const number = orderNumberById.get(orderItem.external_order_id);
				if (number) orderNumberByItem.set(orderItem.id, number);
			}
		}

		// Flat list with one entry per request (each stays independently
		// startable; no allocation or combined-batch logic is introduced).
		const flat: RequestItem[] = [];
		for (const request of requests) {
			flat.push({
				id: request.id,
				productId: request.product_id,
				sourceType: request.source_type,
				orderNumber:
					request.source_type === 'external_order' && request.external_order_item_id
						? (orderNumberByItem.get(request.external_order_item_id) ?? null)
						: null,
				productName: productNames.get(request.product_id) ?? '—',
				quantity: request.requested_quantity,
				unit: request.unit,
				status: request.status
			});
		}

		// AN1: group by product. The page already filters to a single shift,
		// so grouping by product is equivalent to grouping by product + shift.
		const byProduct = new Map<string, RequestItem[]>();
		for (const item of flat) {
			const list = byProduct.get(item.productId) ?? [];
			list.push(item);
			byProduct.set(item.productId, list);
		}

		const SOURCE_ORDER: Record<string, number> = { base: 0, external_order: 1, additional: 2 };

		for (const [productId, items] of byProduct) {
			items.sort((a, b) => (SOURCE_ORDER[a.sourceType] ?? 3) - (SOURCE_ORDER[b.sourceType] ?? 3));
			// Only show a total when every contribution shares the same unit;
			// summing different units would invent a quantity that does not
			// exist, so the total is omitted instead.
			const sameUnit = new Set(items.map((item) => item.unit)).size === 1;
			groups.push({
				productId,
				productName: items[0].productName,
				items,
				total: sameUnit ? items.reduce((sum, item) => sum + item.quantity, 0) : null,
				totalUnit: sameUnit ? items[0].unit : null,
				productInputs: []
			});
		}

		groups.sort((a, b) => a.productName.localeCompare(b.productName, 'es'));

		// AP2: for every product group, resolve the required produced-product
		// inputs of its active recipe and the eligible parent lots (outputs of
		// COMPLETED batches of the source product). The operator selects the
		// actual physical source lot at start; the UI never auto-chooses and
		// the start_production_batch RPC validates the selection again.
		const productIds = [...new Set(groups.map((group) => group.productId))];
		const productInputsByProduct = new Map<string, RequiredSourceInput[]>();
		for (const productId of productIds) {
			const resolved = await resolveActiveRecipeForProduct(supabase, productId);
			if (!resolved.ok) {
				// no_recipe / no_active_version / ambiguous_recipes: the start
				// RPC reports the exact reason; the UI just starts directly.
				continue;
			}
			const inputsResult = await supabase
				.from('recipe_product_inputs')
				.select('id, source_product_id')
				.eq('recipe_version_id', resolved.value.recipeVersionId)
				.eq('required', true);
			if (inputsResult.error) throw inputsResult.error;
			const inputs: RecipeProductInputLite[] = inputsResult.data ?? [];
			if (inputs.length === 0) {
				productInputsByProduct.set(productId, []);
				continue;
			}

			const sourceIds = [...new Set(inputs.map((input) => input.source_product_id))];
			const outputsResult = await supabase
				.from('batch_outputs')
				.select('id, batch_id, product_id, quantity, unit')
				.in('product_id', sourceIds);
			if (outputsResult.error) throw outputsResult.error;
			const outputs: BatchOutputLite[] = outputsResult.data ?? [];

			let batches: ParentBatchLite[] = [];
			const batchIds = [...new Set(outputs.map((output) => output.batch_id))];
			if (batchIds.length > 0) {
				const batchesResult = await supabase
					.from('production_batches')
					.select('id, batch_code, production_day_id')
					.in('id', batchIds)
					.eq('status', 'completed');
				if (batchesResult.error) throw batchesResult.error;
				batches = batchesResult.data ?? [];
			}
			let days: ProductionDayLite[] = [];
			const dayIds = [...new Set(batches.map((batch) => batch.production_day_id))];
			if (dayIds.length > 0) {
				const daysResult = await supabase
					.from('production_days')
					.select('id, production_date')
					.in('id', dayIds);
				if (daysResult.error) throw daysResult.error;
				days = daysResult.data ?? [];
			}
			const dateByDayId = new Map(days.map((day) => [day.id, day.production_date]));
			const batchesById = new Map(batches.map((batch) => [batch.id, batch]));

			const optionsBySource = new Map<string, SourceLotOption[]>();
			for (const output of outputs) {
				const batch = batchesById.get(output.batch_id);
				if (!batch) continue; // parent batch not completed: not eligible
				const date = dateByDayId.get(batch.production_day_id) ?? null;
				const options = optionsBySource.get(output.product_id) ?? [];
				options.push({
					outputId: output.id,
					batchCode: batch.batch_code,
					quantity: output.quantity,
					unit: output.unit,
					dateLabel: date ? formatProductionDate(date) : null
				});
				optionsBySource.set(output.product_id, options);
			}
			// Most recent lot first: the batch code PAN-DDMMYY-X-NNN sorts
			// lexicographically by date and sequence.
			for (const options of optionsBySource.values()) {
				options.sort((a, b) => b.batchCode.localeCompare(a.batchCode));
			}

			productInputsByProduct.set(
				productId,
				inputs.map((input) => ({
					sourceProductId: input.source_product_id,
					sourceProductName: productNames.get(input.source_product_id) ?? '—',
					options: optionsBySource.get(input.source_product_id) ?? []
				}))
			);
		}
		for (const group of groups) {
			group.productInputs = productInputsByProduct.get(group.productId) ?? [];
		}
	}

	// 8. AJ1: shift progress, computed in memory from the requests loaded
	// above and never stored in the DB. "total" counts every request of the
	// selected shift; "completed" counts those with status 'completed'.
	const all = groups.flatMap((group) => group.items);
	const progress = {
		completed: all.filter((item) => item.status === 'completed').length,
		total: all.length
	};

	return { shift, groups, progress };
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

		// AP2: the operator's source-lot selection. Each radio posts as
		// lot_<requestId>_<sourceProductId>; no selections at all means the
		// recipe has no required produced-product inputs (SQL default null).
		const productInputs: { source_product_id: string; parent_batch_output_id: string }[] = [];
		const lotPrefix = `lot_${requestId}_`;
		for (const [key, value] of formData.entries()) {
			if (key.startsWith(lotPrefix) && typeof value === 'string' && value !== '') {
				productInputs.push({
					source_product_id: key.slice(lotPrefix.length),
					parent_batch_output_id: value
				});
			}
		}

		const result = await event.locals.supabase.rpc('start_production_batch', {
			p_production_request_id: requestId,
			...(productInputs.length > 0 ? { p_product_inputs: productInputs } : {})
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

// 'YYYY-MM-DD' (stored) -> 'DD/MM/YYYY' (UI display only).
function formatProductionDate(value: string): string {
	const parts = value.split('-');
	if (parts.length !== 3) return value;
	return `${parts[2]}/${parts[1]}/${parts[0]}`;
}

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
		case 'missing_product_input':
			return 'Elegí el producto de origen para poder iniciar la elaboración.';
		case 'duplicate_product_input':
			return 'Un producto de origen aparece más de una vez.';
		case 'input_not_in_recipe':
			return 'El producto de origen no pertenece a la receta del producto.';
		case 'invalid_product_input':
			return 'El lote de producto de origen no es válido.';
		case 'not_authenticated':
			return 'No hay sesión iniciada.';
		case 'no_active_profile':
			return 'Tu perfil no está activo.';
		default:
			return 'No se puede iniciar la elaboración.';
	}
}

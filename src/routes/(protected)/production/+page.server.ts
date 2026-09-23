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
type RawMaterialLite = Pick<Database['public']['Tables']['raw_materials']['Row'], 'id' | 'name'>;
type BrandLite = Pick<Database['public']['Tables']['brands']['Row'], 'id' | 'name'>;
type MaterialBrandLink = Pick<
	Database['public']['Tables']['raw_material_brands']['Row'],
	'raw_material_id' | 'brand_id'
>;

// V5.3: an active raw material with the active brands permitted for it
// (raw_material_brands), for the "AGREGAR MATERIA PRIMA" form.
export type MaterialOption = {
	id: string;
	name: string;
	brands: BrandLite[];
};

// V5.4: a raw material reported as missing an open lot by
// start_production_batch. materialId is null when the name is ambiguous
// (raw material names are not unique) or could not be resolved; the
// operator then picks the material in the form.
export type MissingLot = {
	name: string;
	materialId: string | null;
};

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
	// The in-progress batch covering this request (batch_requests join), or
	// null when the request has no associated batch.
	batchId: string | null;
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

	// 2. Base requests: the legacy weekly-plan generator was DEACTIVATED in
	// V6.12 (spec §61) — the function is a no-op that keeps its signature and
	// gates. Base production comes only from the confirmed daily suggestion
	// (confirm_daily_production, V6.11). The call stays so the page load
	// keeps the original lock order against the external-order generator.
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

	// 5. V5.3: stored business date of today's production day, used to prefill
	// the "Fecha de incorporación" field (never recalculated in the UI).
	const dayRowResult = await supabase
		.from('production_days')
		.select('production_date')
		.eq('id', productionDayId)
		.maybeSingle();
	if (dayRowResult.error) throw dayRowResult.error;
	const dayRow: ProductionDayLite | null = dayRowResult.data ?? null;
	const businessDate = dayRow?.production_date ?? '';

	// 6. V6.12 (spec §61): today's suggestion banner state. A selection row
	// exists once a suggestion was chosen (choose_daily_production_suggestion)
	// and only counts as confirmed after confirm_daily_production ran; the
	// banner shows the confirmed suggestion's code (e.g. "Producción
	// sugerida: B") or the "choose production" call to action otherwise.
	const selectionResult = await supabase
		.from('daily_production_selections')
		.select('status, suggestion_id')
		.eq('production_day_id', productionDayId)
		.maybeSingle();
	if (selectionResult.error) throw selectionResult.error;
	const selectionRow: Pick<
		Database['public']['Tables']['daily_production_selections']['Row'],
		'status' | 'suggestion_id'
	> | null = selectionResult.data ?? null;

	let suggestionConfirmed = false;
	let suggestionCode: string | null = null;
	if (selectionRow && selectionRow.status === 'confirmed') {
		const suggestionResult = await supabase
			.from('production_suggestions')
			.select('code')
			.eq('id', selectionRow.suggestion_id)
			.maybeSingle();
		if (suggestionResult.error) throw suggestionResult.error;
		const suggestionRowData: Pick<
			Database['public']['Tables']['production_suggestions']['Row'],
			'code'
		> | null = suggestionResult.data ?? null;
		suggestionConfirmed = true;
		suggestionCode = suggestionRowData?.code ?? null;
	}

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

		// Resolve the covering in-progress batch for each in-progress request
		// through the batch_requests join table (batch_id -> production_batches,
		// production_request_id -> production_requests), keeping only batches
		// that are actually in progress. Requests without a batch stay null.
		const batchByRequest = new Map<string, string>();
		const inProgressRequestIds = requests
			.filter((request) => request.status === 'in_progress')
			.map((request) => request.id);
		if (inProgressRequestIds.length > 0) {
			const linksResult = await supabase
				.from('batch_requests')
				.select('production_request_id, batch_id')
				.in('production_request_id', inProgressRequestIds);
			if (linksResult.error) throw linksResult.error;
			const links: Pick<
				Database['public']['Tables']['batch_requests']['Row'],
				'production_request_id' | 'batch_id'
			>[] = linksResult.data ?? [];
			const linkedBatchIds = [...new Set(links.map((link) => link.batch_id))];
			if (linkedBatchIds.length > 0) {
				const batchRowsResult = await supabase
					.from('production_batches')
					.select('id, status')
					.in('id', linkedBatchIds);
				if (batchRowsResult.error) throw batchRowsResult.error;
				const batchRows: Pick<
					Database['public']['Tables']['production_batches']['Row'],
					'id' | 'status'
				>[] = batchRowsResult.data ?? [];
				const inProgressBatchIds = new Set(
					batchRows.filter((batch) => batch.status === 'in_progress').map((batch) => batch.id)
				);
				for (const link of links) {
					if (inProgressBatchIds.has(link.batch_id)) {
						batchByRequest.set(link.production_request_id, link.batch_id);
					}
				}
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
				status: request.status,
				batchId: batchByRequest.get(request.id) ?? null
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

	// 9. V5.3: active raw materials with their permitted active brands, for
	// the "AGREGAR MATERIA PRIMA" form on this page.
	// Sequential awaits: Promise.all loses the result types in this
	// supabase-js version (see AGENTS.md).
	const materialsResult = await supabase
		.from('raw_materials')
		.select('id, name')
		.eq('active', true)
		.order('name', { ascending: true });
	if (materialsResult.error) throw materialsResult.error;
	const linksResult = await supabase
		.from('raw_material_brands')
		.select('raw_material_id, brand_id')
		.eq('active', true);
	if (linksResult.error) throw linksResult.error;
	const brandsResult = await supabase.from('brands').select('id, name').eq('active', true);
	if (brandsResult.error) throw brandsResult.error;

	const materials: RawMaterialLite[] = materialsResult.data ?? [];
	const links: MaterialBrandLink[] = linksResult.data ?? [];
	const brands: BrandLite[] = brandsResult.data ?? [];

	const allowedBrandIds = new Map<string, Set<string>>();
	for (const link of links) {
		let ids = allowedBrandIds.get(link.raw_material_id);
		if (!ids) {
			ids = new Set();
			allowedBrandIds.set(link.raw_material_id, ids);
		}
		ids.add(link.brand_id);
	}

	const materialOptions: MaterialOption[] = materials.map((material) => {
		const allowed = allowedBrandIds.get(material.id) ?? new Set<string>();
		return {
			id: material.id,
			name: material.name,
			brands: brands.filter((brand) => allowed.has(brand.id))
		};
	});

	return {
		shift,
		groups,
		progress,
		businessDate,
		materials: materialOptions,
		suggestionConfirmed,
		suggestionCode,
		// V6.14 (spec §63): role for the back-to-Admin link (supervisor+ only).
		role: event.locals.profileRole ?? null
	};
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

	// V5.3: open the "AGREGAR MATERIA PRIMA" form. A material_id may be
	// submitted to preselect it (used by the missing-lot recovery, V5.4).
	openLot: async (event) => {
		const formData = await event.request.formData();
		const materialId =
			typeof formData.get('material_id') === 'string'
				? (formData.get('material_id') as string)
				: '';
		return {
			error: null,
			message: null,
			addLotOpen: true,
			prefillMaterialId: materialId || null
		};
	},

	// V5.3: add a new material lot from /production. All business rules
	// (active material/brand, permitted link, non-empty lot, idempotency)
	// live in the add_material_lot RPC; this action only maps its error
	// tokens to Spanish user messages.
	addLot: async (event) => {
		const formData = await event.request.formData();
		const materialId = toText(formData.get('material_id'));
		const brandId = toText(formData.get('brand_id'));
		const supplierLot = toText(formData.get('supplier_lot'));
		const openedAt = toText(formData.get('opened_at'));

		const submitted = {
			material_id: materialId,
			brand_id: brandId,
			supplier_lot: supplierLot,
			opened_at: openedAt
		};

		if (!materialId || !brandId || !supplierLot) {
			return fail(400, {
				error: 'Completa los datos del lote.',
				message: null,
				addLotOpen: true,
				...submitted
			});
		}

		const rpcArgs: Database['public']['Functions']['add_material_lot']['Args'] = {
			p_raw_material_id: materialId,
			p_brand_id: brandId,
			p_supplier_lot: supplierLot
		};
		// Optional date: omitting the key lets the RPC use the business date.
		if (openedAt) rpcArgs.p_opened_at = openedAt;

		const { error } = await event.locals.supabase.rpc('add_material_lot', rpcArgs);
		if (error) {
			return fail(400, {
				error: addLotErrorMessages(error.message),
				message: null,
				addLotOpen: true,
				...submitted
			});
		}

		return {
			error: null,
			message: `Lote ${supplierLot} agregado.`,
			addLotOpen: false,
			...submitted
		};
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
				// Explicit annotation: supabase-js 2.116 under TS 6 types
				// result.error.message as any, so the chain below must be
				// annotated to stay string[] (see AGENTS.md).
				const names: string[] = message
					.slice('missing_material_lot:'.length)
					.split(',')
					.map((name: string) => name.trim())
					.filter((name: string) => name !== '');
				// V5.4: resolve each missing material name to its id so the
				// "AGREGAR LOTE" button can preselect it. Names are not unique,
				// so a name matching more than one active material (or none, if
				// it became inactive in the meantime) yields a null materialId
				// and the operator picks the material in the form.
				const materialsResult = await event.locals.supabase
					.from('raw_materials')
					.select('id, name')
					.eq('active', true);
				if (materialsResult.error) throw materialsResult.error;
				const materials: RawMaterialLite[] = materialsResult.data ?? [];
				const idByName = new Map<string, string[]>();
				for (const material of materials) {
					const ids = idByName.get(material.name) ?? [];
					ids.push(material.id);
					idByName.set(material.name, ids);
				}
				const missing: MissingLot[] = names.map((name) => {
					const ids = idByName.get(name) ?? [];
					return { name, materialId: ids.length === 1 ? ids[0] : null };
				});
				return fail(400, {
					error: 'No se puede iniciar la elaboración.',
					missingLots: missing
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
		case 'invalid_shift':
			// V5: historical afternoon (TARDE) requests can no longer be
			// started; no 'T' batch code is ever generated.
			return 'El turno de esta producción ya no está disponible.';
		default:
			return 'No se puede iniciar la elaboración.';
	}
}

const toText = (value: string | File | null): string | null =>
	typeof value === 'string' ? value : null;

// V5.3: add_material_lot error tokens (English, developer-facing) to
// user-facing Spanish messages.
function addLotErrorMessages(message: string): string {
	switch (message) {
		case 'not_authenticated':
			return 'No hay sesión iniciada.';
		case 'no_active_profile':
			return 'Tu perfil no está activo.';
		case 'raw_material_not_found':
			return 'La materia prima seleccionada no existe o no está activa.';
		case 'brand_not_found':
			return 'La marca seleccionada no existe o no está activa.';
		case 'brand_not_permitted_for_material':
			return 'La marca seleccionada no es válida para esa materia prima.';
		case 'supplier_lot_required':
			return 'Ingresa el lote del proveedor.';
		default:
			return 'No se pudo agregar el lote.';
	}
}

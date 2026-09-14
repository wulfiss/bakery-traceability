import { error, fail, redirect } from '@sveltejs/kit';
import type { SupabaseClient } from '@supabase/supabase-js';
import type { Actions, PageServerLoad } from './$types';
import type { Database } from '$lib/types/database.types';

// Explicit row annotations: supabase-js 2.116 under TS 6 does not resolve the
// inferred select type in this toolchain (see AGENTS.md).
type BatchLite = Pick<
	Database['public']['Tables']['production_batches']['Row'],
	'batch_code' | 'status' | 'shift_code'
>;
type LinkLite = Pick<
	Database['public']['Tables']['batch_requests']['Row'],
	'production_request_id'
>;
type RequestLite = Pick<
	Database['public']['Tables']['production_requests']['Row'],
	'id' | 'product_id' | 'requested_quantity' | 'unit'
>;
type ProductLite = Pick<Database['public']['Tables']['products']['Row'], 'id' | 'name'>;
type RawMaterialLite = Pick<Database['public']['Tables']['raw_materials']['Row'], 'id' | 'name'>;
type BrandLite = Pick<Database['public']['Tables']['brands']['Row'], 'id' | 'name'>;
type MaterialBrandLink = Pick<
	Database['public']['Tables']['raw_material_brands']['Row'],
	'raw_material_id' | 'brand_id'
>;
// V5.5: one batch_materials row with its embedded lot. The snapshot is
// append-mostly: the initial lots at batch start plus every additional lot
// linked while the batch is in progress via "USAR OTRO LOTE".
type BatchMaterialLotRow = Pick<
	Database['public']['Tables']['batch_materials']['Row'],
	'raw_material_id' | 'material_lot_id'
> & {
	material_lots: Pick<Database['public']['Tables']['material_lots']['Row'], 'supplier_lot'> | null;
};
// V5.5: a raw material the batch uses, with the supplier lots linked to the
// batch (in incorporation order: the snapshot row first, additions after).
type BatchMaterial = {
	id: string;
	name: string;
	lots: string[];
};
// V5.5: a material the batch already uses, with its permitted active brands,
// for the "USAR OTRO LOTE" form (the form must not offer materials the batch
// does not already use).
type BatchLotOption = {
	id: string;
	name: string;
	brands: BrandLite[];
};
type RecipeVersionRef = Pick<
	Database['public']['Tables']['recipe_versions']['Row'],
	'id' | 'recipe_id'
>;
type RecipeLite = Pick<Database['public']['Tables']['recipes']['Row'], 'id' | 'name'>;
type RecipeProductRef = Pick<
	Database['public']['Tables']['recipe_products']['Row'],
	'product_id' | 'sort_order'
>;
type OutputProduct = {
	id: string;
	name: string;
	unit: string;
};
type BatchOutputRef = Pick<
	Database['public']['Tables']['batch_outputs']['Row'],
	'quantity' | 'unit'
> & {
	products: Pick<Database['public']['Tables']['products']['Row'], 'id' | 'name'> | null;
};
type BatchOutput = {
	name: string;
	quantity: number;
	unit: string;
};

// AO2: resolve the products the batch's recipe produces, in recipe sort
// order. Used by load (to decide which completion form to show) and by the
// finalizeMulti action (the form must never be trusted with the output list;
// the recipe is the single source of truth for eligible outputs).
async function resolveRecipeProducts(
	supabase: SupabaseClient,
	batchId: string
): Promise<{ recipeName: string | null; products: OutputProduct[] }> {
	const versionResult = await supabase
		.from('production_batches')
		.select('recipe_version_id')
		.eq('id', batchId);
	if (versionResult.error) throw versionResult.error;
	const batchRows: Pick<
		Database['public']['Tables']['production_batches']['Row'],
		'recipe_version_id'
	>[] = versionResult.data ?? [];
	const versionId = batchRows[0]?.recipe_version_id ?? null;
	if (!versionId) return { recipeName: null, products: [] };

	const versionResult2 = await supabase
		.from('recipe_versions')
		.select('id, recipe_id')
		.eq('id', versionId);
	if (versionResult2.error) throw versionResult2.error;
	const versions: RecipeVersionRef[] = versionResult2.data ?? [];
	const recipeId = versions[0]?.recipe_id ?? null;
	if (!recipeId) return { recipeName: null, products: [] };

	const recipeResult = await supabase.from('recipes').select('id, name').eq('id', recipeId);
	if (recipeResult.error) throw recipeResult.error;
	const recipes: RecipeLite[] = recipeResult.data ?? [];
	const recipeName = recipes[0]?.name ?? null;

	const refsResult = await supabase
		.from('recipe_products')
		.select('product_id, sort_order')
		.eq('recipe_id', recipeId);
	if (refsResult.error) throw refsResult.error;
	const refs: RecipeProductRef[] = refsResult.data ?? [];
	if (refs.length === 0) return { recipeName, products: [] };

	const productsResult = await supabase
		.from('products')
		.select('id, name, default_unit')
		.in(
			'id',
			refs.map((ref) => ref.product_id)
		);
	if (productsResult.error) throw productsResult.error;
	const products: OutputProduct[] = (productsResult.data ?? []).map((product) => ({
		id: product.id,
		name: product.name,
		unit: product.default_unit
	}));

	const productsByName = new Map(products.map((product) => [product.id, product]));
	return {
		recipeName,
		products: refs
			.sort((a, b) => a.sort_order - b.sort_order)
			.map((ref) => productsByName.get(ref.product_id))
			.filter((product): product is OutputProduct => product !== undefined)
	};
}

export const load: PageServerLoad = async ({ params, locals }) => {
	const supabase = locals.supabase;
	const batchId: string | undefined = params.batchId;
	if (!batchId) throw error(404, 'Lote no encontrado');

	// 1. The batch itself (recipe_version_id selects only, not returned).
	const batchResult = await supabase
		.from('production_batches')
		.select('batch_code, status, shift_code, recipe_version_id')
		.eq('id', batchId);
	if (batchResult.error) throw batchResult.error;
	const batchRows: (BatchLite & { recipe_version_id: string })[] = batchResult.data ?? [];
	const batchRow = batchRows[0] ?? null;
	if (!batchRow) throw error(404, 'Lote no encontrado');
	// recipe_version_id stays server-side; the payload keeps the public fields.
	const batch: BatchLite = {
		batch_code: batchRow.batch_code,
		status: batchRow.status,
		shift_code: batchRow.shift_code
	};

	// 2. The request(s) linked to this batch (product, quantity, unit).
	const linksResult = await supabase
		.from('batch_requests')
		.select('production_request_id')
		.eq('batch_id', batchId);
	if (linksResult.error) throw linksResult.error;
	const links: LinkLite[] = linksResult.data ?? [];
	const requestIds = links.map((link) => link.production_request_id);

	let productName = '—';
	let quantity = 0;
	let unit = '';
	if (requestIds.length > 0) {
		const requestsResult = await supabase
			.from('production_requests')
			.select('id, product_id, requested_quantity, unit')
			.in('id', requestIds);
		if (requestsResult.error) throw requestsResult.error;
		const requests: RequestLite[] = requestsResult.data ?? [];
		const firstRequest = requests[0] ?? null;

		if (firstRequest) {
			quantity = firstRequest.requested_quantity;
			unit = firstRequest.unit;

			const productsResult = await supabase
				.from('products')
				.select('id, name')
				.in(
					'id',
					requests.map((request) => request.product_id)
				);
			if (productsResult.error) throw productsResult.error;
			const products: ProductLite[] = productsResult.data ?? [];
			productName = products.find((product) => product.id === firstRequest.product_id)?.name ?? '—';
		}
	}

	// 3. V5.5: the raw materials the batch is using and the exact lots linked
	// to the batch (created_at order: the start snapshot first, then every
	// "USAR OTRO LOTE" addition). For a completed batch the list is final
	// history; the page never shows UUIDs, only names and lot codes.
	const batchMaterialsResult = await supabase
		.from('batch_materials')
		.select('raw_material_id, material_lot_id, material_lots(supplier_lot)')
		.eq('batch_id', batchId)
		.order('created_at', { ascending: true });
	if (batchMaterialsResult.error) throw batchMaterialsResult.error;
	const batchMaterialRows: BatchMaterialLotRow[] = batchMaterialsResult.data ?? [];
	const batchMaterialIds = [...new Set(batchMaterialRows.map((row) => row.raw_material_id))];

	const lotsByMaterial = new Map<string, string[]>();
	for (const row of batchMaterialRows) {
		const lots = lotsByMaterial.get(row.raw_material_id) ?? [];
		lots.push(row.material_lots?.supplier_lot ?? '—');
		lotsByMaterial.set(row.raw_material_id, lots);
	}

	const materialNames = new Map<string, string>();
	if (batchMaterialIds.length > 0) {
		const namesResult = await supabase
			.from('raw_materials')
			.select('id, name')
			.in('id', batchMaterialIds);
		if (namesResult.error) throw namesResult.error;
		const materials: RawMaterialLite[] = namesResult.data ?? [];
		for (const material of materials) materialNames.set(material.id, material.name);
	}

	const batchMaterials: BatchMaterial[] = batchMaterialIds
		.map((id) => ({
			id,
			name: materialNames.get(id) ?? '—',
			lots: lotsByMaterial.get(id) ?? []
		}))
		.sort((a, b) => a.name.localeCompare(b.name));

	// 4. V5.5: "USAR OTRO LOTE" form options for in-progress batches: the
	// materials the batch already uses, each with its permitted active
	// brands. Sequential awaits: Promise.all loses the result types in this
	// supabase-js version (see AGENTS.md).
	let lotOptions: BatchLotOption[] = [];
	if (batch.status === 'in_progress' && batchMaterialIds.length > 0) {
		const linksResult = await supabase
			.from('raw_material_brands')
			.select('raw_material_id, brand_id')
			.eq('active', true)
			.in('raw_material_id', batchMaterialIds);
		if (linksResult.error) throw linksResult.error;
		const links: MaterialBrandLink[] = linksResult.data ?? [];
		const brandsResult = await supabase.from('brands').select('id, name').eq('active', true);
		if (brandsResult.error) throw brandsResult.error;
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

		lotOptions = batchMaterials.map((material) => {
			const allowed = allowedBrandIds.get(material.id) ?? new Set<string>();
			return {
				id: material.id,
				name: material.name,
				brands: brands.filter((brand) => allowed.has(brand.id))
			};
		});
	}

	// 5. V5.5: default for the "USAR OTRO LOTE" incorporation date.
	const businessDateResult = await supabase.rpc('get_business_date');
	if (businessDateResult.error) throw businessDateResult.error;
	const businessDate: string = businessDateResult.data ?? '';

	// 6. AO2: the products the batch's recipe produces. When the recipe yields
	// several products the completion form becomes the multi-output form;
	// single-product recipes keep the simple single-output form.
	const recipe = await resolveRecipeProducts(supabase, batchId);
	const multiOutputs = recipe.products.length > 1 ? recipe.products : null;

	// 7. AO3: what the batch actually produced. Outputs are recorded only at
	// finalization, so they are fetched only for completed batches; the batch
	// detail then lists every recorded output (a single-output batch shows one
	// row, a multi-output batch shows them all).
	let outputs: BatchOutput[] = [];
	if (batch.status === 'completed') {
		const outputsResult = await supabase
			.from('batch_outputs')
			.select('quantity, unit, products(id, name)')
			.eq('batch_id', batchId);
		if (outputsResult.error) throw outputsResult.error;
		const outputRefs: BatchOutputRef[] = outputsResult.data ?? [];
		outputs = outputRefs
			.filter((row) => row.products !== null)
			.map((row) => ({
				name: row.products?.name ?? '—',
				quantity: row.quantity,
				unit: row.unit
			}))
			.sort((a, b) => a.name.localeCompare(b.name));
	}

	return {
		batch,
		productName,
		quantity,
		unit,
		materialsVerified: batchMaterials.length > 0,
		batchMaterials,
		lotOptions,
		businessDate,
		recipeName: multiOutputs ? recipe.recipeName : null,
		multiOutputs,
		outputs
	};
};

// Spanish messages for the completion error tokens (see SECURITY.md audit).
function finalizeErrorMessages(token: string): string {
	switch (token) {
		case 'batch_not_found':
			return 'El lote no existe.';
		case 'batch_not_in_progress':
			return 'El lote ya fue finalizado.';
		case 'batch_request_not_found':
			return 'No se puede finalizar el lote.';
		case 'invalid_quantity':
			return 'La cantidad no es válida.';
		case 'invalid_outputs':
			return 'Ingrese al menos una cantidad.';
		case 'duplicate_output':
			return 'Un producto aparece más de una vez.';
		case 'invalid_output':
			return 'Una de las cantidades no es válida.';
		case 'output_not_in_recipe':
			return 'Uno de los productos no pertenece a la receta del lote.';
		case 'not_authenticated':
			return 'No hay sesión iniciada.';
		case 'no_active_profile':
			return 'Tu perfil no está activo.';
		default:
			return 'No se puede finalizar el lote.';
	}
}

// Spanish messages for the use_other_material_lot error tokens (V5.5).
function useLotErrorMessages(token: string): string {
	switch (token) {
		case 'batch_not_found':
			return 'El lote no existe.';
		case 'batch_not_in_progress':
			return 'El lote ya fue finalizado.';
		case 'material_not_in_batch':
			return 'Esa materia prima no se usa en este lote.';
		case 'raw_material_not_found':
			return 'La materia prima no existe.';
		case 'brand_not_found':
			return 'La marca no existe.';
		case 'brand_not_permitted_for_material':
			return 'La marca no está permitida para esa materia prima.';
		case 'supplier_lot_required':
			return 'Ingresá el lote del proveedor.';
		case 'not_authenticated':
			return 'No hay sesión iniciada.';
		case 'no_active_profile':
			return 'Tu perfil no está activo.';
		default:
			return 'No se puede agregar el lote.';
	}
}

export const actions: Actions = {
	// V5.5: "USAR OTRO LOTE" — link a second lot of a raw material the batch
	// is already using (the final-rule case: opening a second bag of flour
	// mid-dough must be recorded without losing the first lot). The RPC
	// appends a batch_materials row (never rewrites the existing ones) and
	// makes the new lot current for future production. The batch identity
	// comes from the route params (the form is never trusted with it); the
	// material must be one of the batch's materials (the form is generated
	// from them and the RPC re-checks). On success the page redirects to
	// itself so the lot list re-loads.
	useLot: async ({ request, locals, params }) => {
		const formData = await request.formData();
		const batchId: string = params.batchId ?? '';
		const materialId = formData.get('raw_material_id')?.toString().trim() ?? '';
		const brandId = formData.get('brand_id')?.toString().trim() ?? '';
		const supplierLot = formData.get('supplier_lot')?.toString().trim() ?? '';
		const openedAt = formData.get('opened_at')?.toString().trim() ?? '';

		const fieldData = {
			raw_material_id: materialId,
			brand_id: brandId,
			supplier_lot: supplierLot,
			opened_at: openedAt
		};

		if (batchId === '' || materialId === '' || brandId === '' || supplierLot === '') {
			return fail(400, { error: 'Completa los datos del lote.', ...fieldData });
		}

		const args: Database['public']['Functions']['use_other_material_lot']['Args'] = {
			p_batch_id: batchId,
			p_raw_material_id: materialId,
			p_brand_id: brandId,
			p_supplier_lot: supplierLot
		};
		if (openedAt !== '') args.p_opened_at = openedAt;

		const { data, error: rpcError } = await locals.supabase.rpc('use_other_material_lot', args);
		if (rpcError) return fail(400, { error: useLotErrorMessages(rpcError.message), ...fieldData });
		void data;

		redirect(303, `/production/${batchId}`);
	},

	// AI2: finalize the batch with the actual produced quantity. The form
	// posts batch_id, actual_quantity and unit; the RPC performs the whole
	// completion atomically and we simply redirect back to the production
	// page (the selected shift cookie is untouched, so the same shift is
	// still selected there).
	finalize: async ({ request, locals, params }) => {
		const formData = await request.formData();
		const batchId: string = formData.get('batch_id')?.toString() ?? params.batchId ?? '';
		const quantityRaw: string = formData.get('actual_quantity')?.toString() ?? '';
		const unitRaw: string = formData.get('unit')?.toString() ?? '';
		const unit = unitRaw.trim();

		const quantity = Number(quantityRaw);
		if (batchId === '' || !Number.isFinite(quantity) || quantity <= 0 || unit === '') {
			return fail(400, { error: 'La cantidad no es válida.' });
		}

		const { data, error: rpcError } = await locals.supabase.rpc('complete_production_batch', {
			p_batch_id: batchId,
			p_actual_quantity: quantity,
			p_unit: unit
		});
		if (rpcError) return fail(400, { error: finalizeErrorMessages(rpcError.message) });
		void data;

		redirect(303, '/production');
	},

	// AO2: finalize a batch whose recipe produces several products. The form
	// posts one quantity per recipe product (name qty_<productId>); products
	// left empty are not produced and are not recorded. The eligible product
	// list and the units come from the recipe itself (default_unit), never
	// from the form. The RPC performs the whole completion atomically.
	finalizeMulti: async ({ request, locals, params }) => {
		const formData = await request.formData();
		const batchId: string = formData.get('batch_id')?.toString() ?? params.batchId ?? '';

		const recipe = await resolveRecipeProducts(locals.supabase, batchId);
		if (recipe.products.length === 0) {
			return fail(400, { error: 'No se puede finalizar el lote.' });
		}

		const outputs: { product_id: string; quantity: number; unit: string }[] = [];
		for (const product of recipe.products) {
			const raw = formData.get(`qty_${product.id}`)?.toString().trim() ?? '';
			if (raw === '') continue;
			const quantity = Number(raw);
			if (!Number.isFinite(quantity) || quantity <= 0) {
				return fail(400, { error: 'Una de las cantidades no es válida.' });
			}
			outputs.push({ product_id: product.id, quantity, unit: product.unit });
		}

		if (batchId === '' || outputs.length === 0) {
			return fail(400, { error: 'Ingrese al menos una cantidad.' });
		}

		const { data, error: rpcError } = await locals.supabase.rpc('complete_multi_output_batch', {
			p_batch_id: batchId,
			p_outputs: outputs
		});
		if (rpcError) return fail(400, { error: finalizeErrorMessages(rpcError.message) });
		void data;

		redirect(303, '/production');
	}
};

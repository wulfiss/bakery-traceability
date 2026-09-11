import { error } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';
import type { Database } from '$lib/types/database.types';

// Explicit row annotations: supabase-js 2.116 under TS 6 does not resolve the
// inferred select type in this toolchain (see AGENTS.md).
type BatchLite = Pick<
	Database['public']['Tables']['production_batches']['Row'],
	'id' | 'batch_code' | 'status' | 'shift_code'
>;
type LinkLite = Pick<
	Database['public']['Tables']['batch_requests']['Row'],
	'production_request_id' | 'allocated_quantity'
>;
type RequestLite = Pick<
	Database['public']['Tables']['production_requests']['Row'],
	'id' | 'product_id' | 'requested_quantity' | 'unit'
>;
type ProductLite = Pick<Database['public']['Tables']['products']['Row'], 'id' | 'name'>;
type MaterialRow = Pick<
	Database['public']['Tables']['batch_materials']['Row'],
	'raw_material_id' | 'material_lot_id' | 'recipe_quantity' | 'recipe_unit'
>;
type LotLite = Pick<Database['public']['Tables']['material_lots']['Row'], 'id' | 'supplier_lot'>;
type MaterialLite = Pick<Database['public']['Tables']['raw_materials']['Row'], 'id' | 'name'>;

export const load: PageServerLoad = async ({ params, locals }) => {
	const supabase = locals.supabase;
	const batchId: string | undefined = params.batchId;
	if (!batchId) throw error(404, 'Lote no encontrado');

	// 1. The batch itself.
	const batchResult = await supabase
		.from('production_batches')
		.select('id, batch_code, status, shift_code')
		.eq('id', batchId);
	if (batchResult.error) throw batchResult.error;
	const batches: BatchLite[] = batchResult.data ?? [];
	const batch = batches[0] ?? null;
	if (!batch) throw error(404, 'Lote no encontrado');

	// 2. The request(s) linked to this batch (product, quantity, unit).
	const linksResult = await supabase
		.from('batch_requests')
		.select('production_request_id, allocated_quantity')
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

	// 3. The exact material-lot snapshot taken at batch start.
	const materialsResult = await supabase
		.from('batch_materials')
		.select('raw_material_id, material_lot_id, recipe_quantity, recipe_unit')
		.eq('batch_id', batchId);
	if (materialsResult.error) throw materialsResult.error;
	const materialRows: MaterialRow[] = materialsResult.data ?? [];
	const lotIds = materialRows.map((row) => row.material_lot_id);

	let lotLots: LotLite[] = [];
	if (lotIds.length > 0) {
		const lotLotsResult = await supabase
			.from('material_lots')
			.select('id, supplier_lot')
			.in('id', lotIds);
		if (lotLotsResult.error) throw lotLotsResult.error;
		lotLots = lotLotsResult.data ?? [];
	}

	const materialIds = materialRows.map((row) => row.raw_material_id);
	let materialNames: MaterialLite[] = [];
	if (materialIds.length > 0) {
		const materialNamesResult = await supabase
			.from('raw_materials')
			.select('id, name')
			.in('id', materialIds);
		if (materialNamesResult.error) throw materialNamesResult.error;
		materialNames = materialNamesResult.data ?? [];
	}

	const lotByMaterial = new Map<string, string>(lotLots.map((lot) => [lot.id, lot.supplier_lot]));
	const nameByMaterial = new Map<string, string>(
		materialNames.map((material) => [material.id, material.name])
	);

	const materials = materialRows.map((row) => ({
		name: nameByMaterial.get(row.raw_material_id) ?? '—',
		lot: lotByMaterial.get(row.material_lot_id) ?? '—',
		quantity: row.recipe_quantity,
		unit: row.recipe_unit
	}));

	return { batch, productName, quantity, unit, materials };
};

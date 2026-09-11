import { error } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';
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
type MaterialRef = Pick<Database['public']['Tables']['batch_materials']['Row'], 'raw_material_id'>;

export const load: PageServerLoad = async ({ params, locals }) => {
	const supabase = locals.supabase;
	const batchId: string | undefined = params.batchId;
	if (!batchId) throw error(404, 'Lote no encontrado');

	// 1. The batch itself.
	const batchResult = await supabase
		.from('production_batches')
		.select('batch_code, status, shift_code')
		.eq('id', batchId);
	if (batchResult.error) throw batchResult.error;
	const batches: BatchLite[] = batchResult.data ?? [];
	const batch = batches[0] ?? null;
	if (!batch) throw error(404, 'Lote no encontrado');

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

	// 3. Whether the material-lot snapshot taken at batch start exists.
	// The page shows the simple "Materias primas ✓ verificadas" indication
	// (AH1) and never the per-material list or any UUID.
	const materialsResult = await supabase
		.from('batch_materials')
		.select('raw_material_id')
		.eq('batch_id', batchId);
	if (materialsResult.error) throw materialsResult.error;
	const materialRefs: MaterialRef[] = materialsResult.data ?? [];

	return { batch, productName, quantity, unit, materialsVerified: materialRefs.length > 0 };
};

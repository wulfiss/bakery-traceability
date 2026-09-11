import { error, fail, redirect } from '@sveltejs/kit';
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
		case 'not_authenticated':
			return 'No hay sesión iniciada.';
		case 'no_active_profile':
			return 'Tu perfil no está activo.';
		default:
			return 'No se puede finalizar el lote.';
	}
}

export const actions: Actions = {
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
	}
};

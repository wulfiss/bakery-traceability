import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import type { Database } from '$lib/types/database.types';

// Explicit row annotations: supabase-js 2.116 under TS 6 does not resolve the
// inferred select type in this toolchain (see AGENTS.md).
type ProductionDayLite = Pick<
	Database['public']['Tables']['production_days']['Row'],
	'production_date'
>;
type RawMaterialLite = Pick<Database['public']['Tables']['raw_materials']['Row'], 'id' | 'name'>;
type BrandLite = Pick<Database['public']['Tables']['brands']['Row'], 'id' | 'name'>;
type MaterialBrandLink = Pick<
	Database['public']['Tables']['raw_material_brands']['Row'],
	'raw_material_id' | 'brand_id'
>;

// V6.17: an active raw material with the active brands permitted for it
// (raw_material_brands), for this page's material/brand selection.
type MaterialOption = {
	id: string;
	name: string;
	brands: BrandLite[];
};

export const load: PageServerLoad = async (event) => {
	const supabase = event.locals.supabase;

	// 1. Ensure today's production day exists (idempotent; Cordoba business
	// date) and read its stored business date to prefill "Fecha de
	// incorporación" (never recalculated in the UI).
	const dayResult = await supabase.rpc('ensure_production_day');
	if (dayResult.error) throw dayResult.error;
	const productionDayId: string | null = dayResult.data;
	if (!productionDayId) throw dayResult.error ?? new Error('ensure_production_day returned no id');

	const dayRowResult = await supabase
		.from('production_days')
		.select('production_date')
		.eq('id', productionDayId)
		.maybeSingle();
	if (dayRowResult.error) throw dayRowResult.error;
	const dayRow: ProductionDayLite | null = dayRowResult.data ?? null;
	const businessDate = dayRow?.production_date ?? '';

	// 2. Active raw materials with their permitted active brands (the same
	// data the old inline "AGREGAR MATERIA PRIMA" form on /production used).
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

	// 3. Optional material preselection (?material=<id>), sent by the
	// missing-lot recovery on /production. An unknown or inactive id is
	// ignored and the operator picks the material in the form.
	const queryMaterialId = event.url.searchParams.get('material');
	const prefillMaterialId =
		queryMaterialId && materialOptions.some((material) => material.id === queryMaterialId)
			? queryMaterialId
			: null;

	return { businessDate, materials: materialOptions, prefillMaterialId };
};

export const actions: Actions = {
	// V6.17: add a new material lot from its own page (moved out of
	// /production, which only links here). All business rules (active
	// material/brand, permitted link, non-empty lot, idempotency) live in the
	// add_material_lot RPC; this action only maps its error tokens to Spanish
	// user messages. On success the operator goes back to /production
	// (CONFIRMAR and CANCELAR both return there).
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
			return fail(400, { error: 'Completa los datos del lote.', ...submitted });
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
			return fail(400, { error: addLotErrorMessages(error.message), ...submitted });
		}

		redirect(303, '/production');
	}
};

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

const toText = (value: string | File | null): string | null =>
	typeof value === 'string' ? value : null;

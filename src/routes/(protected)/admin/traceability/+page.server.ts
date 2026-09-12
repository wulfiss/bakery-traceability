import type { PageServerLoad } from './$types';
import type { Database } from '$lib/types/database.types';

// Explicit row annotations: supabase-js 2.116 under TS 6 does not resolve the
// inferred select type in this toolchain (see AGENTS.md).
type BatchLite = Pick<
	Database['public']['Tables']['production_batches']['Row'],
	'id' | 'batch_code' | 'shift_code' | 'production_day_id'
>;
type DayLite = Pick<
	Database['public']['Tables']['production_days']['Row'],
	'id' | 'production_date'
>;
type OutputLite = Pick<
	Database['public']['Tables']['batch_outputs']['Row'],
	'id' | 'product_id' | 'quantity' | 'unit'
>;
type ProductLite = Pick<Database['public']['Tables']['products']['Row'], 'id' | 'name'>;
type BatchMaterialLite = Pick<
	Database['public']['Tables']['batch_materials']['Row'],
	'id' | 'raw_material_id' | 'material_lot_id'
>;
type MaterialLotLite = Pick<
	Database['public']['Tables']['material_lots']['Row'],
	'id' | 'raw_material_id' | 'brand_id' | 'supplier_lot'
>;
type RawMaterialLite = Pick<Database['public']['Tables']['raw_materials']['Row'], 'id' | 'name'>;
type BrandLite = Pick<Database['public']['Tables']['brands']['Row'], 'id' | 'name'>;

// AQ: one historical material lot consumed by the searched batch.
export type TraceMaterial = {
	rawMaterialName: string;
	brandName: string;
	supplierLot: string;
};

// AQ: one product produced by the searched batch.
export type TraceProduct = {
	productId: string;
	productName: string;
	quantity: number;
	unit: string;
};

export type TraceBatch = {
	batchCode: string;
	dateLabel: string;
	shiftLabel: string;
	products: TraceProduct[];
	materials: TraceMaterial[];
};

const shiftLabels: Record<string, string> = {
	morning: 'MAÑANA',
	afternoon: 'TARDE',
	night: 'NOCHE'
};

// AQ: backward traceability. The search reads ONLY batch_materials (the
// immutable snapshot taken when the batch started) joined to the stored
// material_lot rows. material_lots.is_current is never consulted: a lot
// looked up by id is the exact historical lot the batch consumed.
export const load: PageServerLoad = async ({ url, locals }) => {
	const supabase = locals.supabase;

	const code = (url.searchParams.get('code') ?? '').trim().toUpperCase();
	if (code === '') {
		return { batch: null, error: null, searchedCode: '' };
	}

	const batchResult = await supabase
		.from('production_batches')
		.select('id, batch_code, shift_code, production_day_id')
		.eq('batch_code', code)
		.limit(1);
	if (batchResult.error) throw batchResult.error;
	const batches: BatchLite[] = batchResult.data ?? [];
	if (batches.length === 0) {
		return { batch: null, error: 'No se encontró un lote con ese código.', searchedCode: code };
	}
	const batch = batches[0];

	// Date comes from the stored production day (business date), never
	// recalculated from "today".
	const dayResult = await supabase
		.from('production_days')
		.select('id, production_date')
		.eq('id', batch.production_day_id);
	if (dayResult.error) throw dayResult.error;
	const days: DayLite[] = dayResult.data ?? [];
	const day = days[0];

	// Produced products (one or more, for multi-output batches).
	const outputsResult = await supabase
		.from('batch_outputs')
		.select('id, product_id, quantity, unit')
		.eq('batch_id', batch.id);
	if (outputsResult.error) throw outputsResult.error;
	const outputs: OutputLite[] = outputsResult.data ?? [];
	const productNames = new Map<string, string>();
	if (outputs.length > 0) {
		const productsResult = await supabase
			.from('products')
			.select('id, name')
			.in('id', [...new Set(outputs.map((output) => output.product_id))]);
		if (productsResult.error) throw productsResult.error;
		const products: ProductLite[] = productsResult.data ?? [];
		for (const product of products) productNames.set(product.id, product.name);
	}
	const products: TraceProduct[] = outputs.map((output) => ({
		productId: output.product_id,
		productName: productNames.get(output.product_id) ?? '—',
		quantity: output.quantity,
		unit: output.unit
	}));

	// Historical material lots via batch_materials only.
	const materialsResult = await supabase
		.from('batch_materials')
		.select('id, raw_material_id, material_lot_id')
		.eq('batch_id', batch.id);
	if (materialsResult.error) throw materialsResult.error;
	const materials: BatchMaterialLite[] = materialsResult.data ?? [];

	const lotById = new Map<string, MaterialLotLite>();
	const rawNames = new Map<string, string>();
	const brandNames = new Map<string, string>();
	if (materials.length > 0) {
		const lotsResult = await supabase
			.from('material_lots')
			.select('id, raw_material_id, brand_id, supplier_lot')
			.in('id', [...new Set(materials.map((material) => material.material_lot_id))]);
		if (lotsResult.error) throw lotsResult.error;
		const lots: MaterialLotLite[] = lotsResult.data ?? [];
		for (const lot of lots) lotById.set(lot.id, lot);

		const rawIds = [...new Set(lots.map((lot) => lot.raw_material_id))];
		if (rawIds.length > 0) {
			const rawsResult = await supabase.from('raw_materials').select('id, name').in('id', rawIds);
			if (rawsResult.error) throw rawsResult.error;
			const raws: RawMaterialLite[] = rawsResult.data ?? [];
			for (const raw of raws) rawNames.set(raw.id, raw.name);
		}
		const brandIds = [...new Set(lots.map((lot) => lot.brand_id))];
		if (brandIds.length > 0) {
			const brandsResult = await supabase.from('brands').select('id, name').in('id', brandIds);
			if (brandsResult.error) throw brandsResult.error;
			const brands: BrandLite[] = brandsResult.data ?? [];
			for (const brand of brands) brandNames.set(brand.id, brand.name);
		}
	}

	const traceMaterials: TraceMaterial[] = materials
		.map((material) => {
			const lot = lotById.get(material.material_lot_id);
			if (!lot) return null;
			return {
				rawMaterialName: rawNames.get(lot.raw_material_id) ?? '—',
				brandName: brandNames.get(lot.brand_id) ?? '—',
				supplierLot: lot.supplier_lot
			};
		})
		.filter((material): material is TraceMaterial => material !== null)
		.sort((a, b) => a.rawMaterialName.localeCompare(b.rawMaterialName, 'es'));

	return {
		batch: {
			batchCode: batch.batch_code,
			dateLabel: day ? formatDate(day.production_date) : '—',
			shiftLabel: shiftLabels[batch.shift_code] ?? batch.shift_code,
			products,
			materials: traceMaterials
		},
		error: null,
		searchedCode: code
	};
};

// 'YYYY-MM-DD' (stored) -> 'DD/MM/YYYY' (UI display only).
function formatDate(value: string): string {
	const parts = value.split('-');
	if (parts.length !== 3) return value;
	return `${parts[2]}/${parts[1]}/${parts[0]}`;
}

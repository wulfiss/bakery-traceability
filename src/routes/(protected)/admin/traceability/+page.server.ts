import type { PageServerLoad } from './$types';
import type { Database } from '$lib/types/database.types';

// Explicit row annotations: supabase-js 2.116 under TS 6 does not resolve the
// inferred select type in this toolchain (see AGENTS.md).
type Supabase = Parameters<PageServerLoad>[0]['locals']['supabase'];
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
	'id' | 'batch_id' | 'product_id' | 'quantity' | 'unit'
>;
type ProductLite = Pick<Database['public']['Tables']['products']['Row'], 'id' | 'name'>;
type BatchMaterialLite = Pick<
	Database['public']['Tables']['batch_materials']['Row'],
	'id' | 'batch_id' | 'raw_material_id' | 'material_lot_id'
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

// AQ: backward result for a production batch code.
export type TraceBatch = {
	batchCode: string;
	dateLabel: string;
	shiftLabel: string;
	products: TraceProduct[];
	materials: TraceMaterial[];
};

// AR: one production batch that consumed the searched supplier lot.
export type ForwardBatch = {
	batchCode: string;
	dateLabel: string;
	shiftLabel: string;
	products: TraceProduct[];
};

// AR: forward result for a material supplier lot.
export type TraceLot = {
	rawMaterialName: string;
	brandName: string;
	supplierLot: string;
	batches: ForwardBatch[];
};

export type SearchResult = { kind: 'batch'; batch: TraceBatch } | { kind: 'lot'; lot: TraceLot };

const shiftLabels: Record<string, string> = {
	morning: 'MAÑANA',
	afternoon: 'TARDE',
	night: 'NOCHE'
};

// AQ + AR: traceability search. A query is first tried as a production batch
// code (backward); otherwise as a material supplier lot (forward). Both
// directions read ONLY batch_materials (the immutable snapshot taken when a
// batch started) joined to stored rows. material_lots.is_current is never
// consulted: lots are looked up by id, so the exact historical lot is shown.
export const load: PageServerLoad = async ({ url, locals }) => {
	const supabase = locals.supabase;

	const raw = (url.searchParams.get('code') ?? '').trim();
	if (raw === '') {
		return { result: null, error: null, searchedCode: '' };
	}

	const batch = await findBatchByCode(supabase, raw.toUpperCase());
	if (batch) {
		return {
			result: { kind: 'batch', batch: await buildBatchTrace(supabase, batch) },
			error: null,
			searchedCode: raw
		};
	}

	const lot = await buildLotTrace(supabase, raw);
	if (lot) {
		return { result: { kind: 'lot', lot }, error: null, searchedCode: raw };
	}

	return {
		result: null,
		error: 'No se encontró un lote de producción ni un lote de materia prima con ese código.',
		searchedCode: raw
	};
};

// AQ: backward traceability for one production batch.
async function buildBatchTrace(supabase: Supabase, batch: BatchLite): Promise<TraceBatch> {
	// Date comes from the stored production day (business date), never
	// recalculated from "today".
	const days = await fetchDays(supabase, [batch.production_day_id]);
	const day = days.get(batch.production_day_id);

	// Produced products (one or more, for multi-output batches).
	const outputs = await fetchOutputs(supabase, [batch.id]);
	const productNames = await fetchProductNames(supabase, outputs);
	const traceProducts: TraceProduct[] = outputs.map((output) => ({
		productId: output.product_id,
		productName: productNames.get(output.product_id) ?? '—',
		quantity: output.quantity,
		unit: output.unit
	}));

	// Historical material lots via batch_materials only.
	const materials = await fetchBatchMaterials(supabase, [batch.id]);
	const lotById = await fetchLotsByIds(
		supabase,
		materials.map((material) => material.material_lot_id)
	);
	const lots = [...lotById.values()];
	const rawNames = await fetchRawNames(supabase, lots);
	const brandNames = await fetchBrandNames(supabase, lots);

	const traceMaterials: TraceMaterial[] = materials
		.map((material) => {
			const materialLot = lotById.get(material.material_lot_id);
			if (!materialLot) return null;
			return {
				rawMaterialName: rawNames.get(materialLot.raw_material_id) ?? '—',
				brandName: brandNames.get(materialLot.brand_id) ?? '—',
				supplierLot: materialLot.supplier_lot
			};
		})
		.filter((material): material is TraceMaterial => material !== null)
		.sort((a, b) => a.rawMaterialName.localeCompare(b.rawMaterialName, 'es'));

	return {
		batchCode: batch.batch_code,
		dateLabel: day ? formatDate(day.production_date) : '—',
		shiftLabel: shiftLabels[batch.shift_code] ?? batch.shift_code,
		products: traceProducts,
		materials: traceMaterials
	};
}

// AR: forward traceability for a material supplier lot.
async function buildLotTrace(supabase: Supabase, supplierLot: string): Promise<TraceLot | null> {
	const lotsResult = await supabase
		.from('material_lots')
		.select('id, raw_material_id, brand_id, supplier_lot')
		.eq('supplier_lot', supplierLot);
	if (lotsResult.error) throw lotsResult.error;
	const lots: MaterialLotLite[] = lotsResult.data ?? [];
	if (lots.length === 0) return null;

	const rawNames = await fetchRawNames(supabase, lots);
	const brandNames = await fetchBrandNames(supabase, lots);
	const first = lots[0];

	// Batches that consumed any row of this supplier lot, via batch_materials.
	const materials = await fetchMaterialsByLots(
		supabase,
		lots.map((materialLot) => materialLot.id)
	);
	const batchIds = [...new Set(materials.map((material) => material.batch_id))];
	const batches: ForwardBatch[] = [];
	if (batchIds.length > 0) {
		const productionBatches = await fetchBatches(supabase, batchIds);
		const batchList = [...productionBatches.values()];
		const days = await fetchDays(
			supabase,
			batchList.map((batch) => batch.production_day_id)
		);
		const outputs = await fetchOutputs(supabase, batchIds);
		const productNames = await fetchProductNames(supabase, outputs);

		for (const productionBatch of batchList) {
			const batchOutputs = outputs.filter((output) => output.batch_id === productionBatch.id);
			const batchProducts: TraceProduct[] = batchOutputs.map((output) => ({
				productId: output.product_id,
				productName: productNames.get(output.product_id) ?? '—',
				quantity: output.quantity,
				unit: output.unit
			}));
			const day = days.get(productionBatch.production_day_id);
			batches.push({
				batchCode: productionBatch.batch_code,
				dateLabel: day ? formatDate(day.production_date) : '—',
				shiftLabel: shiftLabels[productionBatch.shift_code] ?? productionBatch.shift_code,
				products: batchProducts
			});
		}
		batches.sort((a, b) => b.batchCode.localeCompare(a.batchCode));
	}

	return {
		rawMaterialName: rawNames.get(first.raw_material_id) ?? '—',
		brandName: brandNames.get(first.brand_id) ?? '—',
		supplierLot: first.supplier_lot,
		batches
	};
}

// --- Query helpers (each awaited sequentially; see AGENTS.md) ---

async function findBatchByCode(supabase: Supabase, code: string): Promise<BatchLite | null> {
	const result = await supabase
		.from('production_batches')
		.select('id, batch_code, shift_code, production_day_id')
		.eq('batch_code', code)
		.limit(1);
	if (result.error) throw result.error;
	const rows: BatchLite[] = result.data ?? [];
	return rows[0] ?? null;
}

async function fetchDays(supabase: Supabase, ids: string[]): Promise<Map<string, DayLite>> {
	const map = new Map<string, DayLite>();
	if (ids.length === 0) return map;
	const result = await supabase.from('production_days').select('id, production_date').in('id', ids);
	if (result.error) throw result.error;
	const rows: DayLite[] = result.data ?? [];
	for (const row of rows) map.set(row.id, row);
	return map;
}

async function fetchBatches(supabase: Supabase, ids: string[]): Promise<Map<string, BatchLite>> {
	const map = new Map<string, BatchLite>();
	if (ids.length === 0) return map;
	const result = await supabase
		.from('production_batches')
		.select('id, batch_code, shift_code, production_day_id')
		.in('id', ids);
	if (result.error) throw result.error;
	const rows: BatchLite[] = result.data ?? [];
	for (const row of rows) map.set(row.id, row);
	return map;
}

async function fetchOutputs(supabase: Supabase, batchIds: string[]): Promise<OutputLite[]> {
	if (batchIds.length === 0) return [];
	const result = await supabase
		.from('batch_outputs')
		.select('id, batch_id, product_id, quantity, unit')
		.in('batch_id', batchIds);
	if (result.error) throw result.error;
	const rows: OutputLite[] = result.data ?? [];
	return rows.sort((a, b) => a.batch_id.localeCompare(b.batch_id));
}

async function fetchProductNames(
	supabase: Supabase,
	outputs: OutputLite[]
): Promise<Map<string, string>> {
	const map = new Map<string, string>();
	const productIds = [...new Set(outputs.map((output) => output.product_id))];
	if (productIds.length === 0) return map;
	const result = await supabase.from('products').select('id, name').in('id', productIds);
	if (result.error) throw result.error;
	const rows: ProductLite[] = result.data ?? [];
	for (const row of rows) map.set(row.id, row.name);
	return map;
}

async function fetchBatchMaterials(
	supabase: Supabase,
	batchIds: string[]
): Promise<BatchMaterialLite[]> {
	if (batchIds.length === 0) return [];
	const result = await supabase
		.from('batch_materials')
		.select('id, batch_id, raw_material_id, material_lot_id')
		.in('batch_id', batchIds);
	if (result.error) throw result.error;
	const rows: BatchMaterialLite[] = result.data ?? [];
	return rows.sort((a, b) => a.batch_id.localeCompare(b.batch_id));
}

async function fetchMaterialsByLots(
	supabase: Supabase,
	materialLotIds: string[]
): Promise<BatchMaterialLite[]> {
	if (materialLotIds.length === 0) return [];
	const result = await supabase
		.from('batch_materials')
		.select('id, batch_id, raw_material_id, material_lot_id')
		.in('material_lot_id', materialLotIds);
	if (result.error) throw result.error;
	const rows: BatchMaterialLite[] = result.data ?? [];
	return rows.sort((a, b) => a.batch_id.localeCompare(b.batch_id));
}

async function fetchLotsByIds(
	supabase: Supabase,
	ids: string[]
): Promise<Map<string, MaterialLotLite>> {
	const map = new Map<string, MaterialLotLite>();
	if (ids.length === 0) return map;
	const result = await supabase
		.from('material_lots')
		.select('id, raw_material_id, brand_id, supplier_lot')
		.in('id', ids);
	if (result.error) throw result.error;
	const rows: MaterialLotLite[] = result.data ?? [];
	for (const row of rows) map.set(row.id, row);
	return map;
}

async function fetchRawNames(
	supabase: Supabase,
	lots: MaterialLotLite[]
): Promise<Map<string, string>> {
	const map = new Map<string, string>();
	const ids = [...new Set(lots.map((lot) => lot.raw_material_id))];
	if (ids.length === 0) return map;
	const result = await supabase.from('raw_materials').select('id, name').in('id', ids);
	if (result.error) throw result.error;
	const rows: RawMaterialLite[] = result.data ?? [];
	for (const row of rows) map.set(row.id, row.name);
	return map;
}

async function fetchBrandNames(
	supabase: Supabase,
	lots: MaterialLotLite[]
): Promise<Map<string, string>> {
	const map = new Map<string, string>();
	const ids = [...new Set(lots.map((lot) => lot.brand_id))];
	if (ids.length === 0) return map;
	const result = await supabase.from('brands').select('id, name').in('id', ids);
	if (result.error) throw result.error;
	const rows: BrandLite[] = result.data ?? [];
	for (const row of rows) map.set(row.id, row.name);
	return map;
}

// 'YYYY-MM-DD' (stored) -> 'DD/MM/YYYY' (UI display only).
function formatDate(value: string): string {
	const parts = value.split('-');
	if (parts.length !== 3) return value;
	return `${parts[2]}/${parts[1]}/${parts[0]}`;
}

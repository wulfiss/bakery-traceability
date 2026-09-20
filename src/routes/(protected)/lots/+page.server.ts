import type { PageServerLoad } from './$types';
import type { Database } from '$lib/types/database.types';

// Row shapes for the columns selected below. The Supabase client in this
// environment (supabase-js 2.116 under TS 6) leaves the inferred select
// result as an unresolved conditional type, so the `data` field is annotated
// explicitly from the generated Row types to keep the rest of the function
// fully type-checked.
type RawMaterialLite = Pick<Database['public']['Tables']['raw_materials']['Row'], 'id' | 'name'>;
type BrandLite = Pick<Database['public']['Tables']['brands']['Row'], 'id' | 'name'>;
type MaterialLotCurrent = Pick<
	Database['public']['Tables']['material_lots']['Row'],
	'raw_material_id' | 'brand_id' | 'supplier_lot' | 'expiry_date'
>;

export type CurrentLot = {
	brandName: string;
	supplierLot: string;
	expiryDate: string | null;
};

export type RawMaterialRow = {
	id: string;
	name: string;
	lot: CurrentLot | null;
};

export const load: PageServerLoad = async (event) => {
	const supabase = event.locals.supabase;

	// Sequential awaits: Promise.all also loses the (already weak) result
	// types in this supabase-js version.
	const materialsResult = await supabase
		.from('raw_materials')
		.select('id, name')
		.eq('active', true)
		.order('name', { ascending: true });
	const lotsResult = await supabase
		.from('material_lots')
		.select('raw_material_id, brand_id, supplier_lot, expiry_date')
		.eq('is_current', true);
	const brandsResult = await supabase.from('brands').select('id, name').eq('active', true);

	if (materialsResult.error) throw materialsResult.error;
	if (lotsResult.error) throw lotsResult.error;
	if (brandsResult.error) throw brandsResult.error;

	const materials: RawMaterialLite[] = materialsResult.data ?? [];
	const lots: MaterialLotCurrent[] = lotsResult.data ?? [];
	const brands: BrandLite[] = brandsResult.data ?? [];

	const brandNames = new Map(brands.map((brand) => [brand.id, brand.name] as const));
	const lotsByMaterial = new Map(lots.map((lot) => [lot.raw_material_id, lot] as const));

	const items: RawMaterialRow[] = materials.map((material) => {
		const lot = lotsByMaterial.get(material.id);
		return {
			id: material.id,
			name: material.name,
			lot: lot
				? {
						brandName: brandNames.get(lot.brand_id) ?? '—',
						supplierLot: lot.supplier_lot,
						expiryDate: lot.expiry_date
					}
				: null
		};
	});

	return {
		items,
		// V6.14 (spec §63): role for the back-to-Admin link (supervisor+ only).
		role: event.locals.profileRole ?? null
	};
};

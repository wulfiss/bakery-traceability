import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import type { Database } from '$lib/types/database.types';

// Explicit row annotations: supabase-js 2.116 under TS 6 does not resolve the
// inferred select type in this toolchain (see AGENTS.md).
type RawMaterialLite = Pick<Database['public']['Tables']['raw_materials']['Row'], 'id' | 'name'>;
type BrandLite = Pick<Database['public']['Tables']['brands']['Row'], 'id' | 'name'>;
type MaterialBrandLink = Pick<
	Database['public']['Tables']['raw_material_brands']['Row'],
	'raw_material_id' | 'brand_id'
>;

export type MaterialOption = {
	id: string;
	name: string;
	brands: BrandLite[];
};

export const load: PageServerLoad = async (event) => {
	const supabase = event.locals.supabase;

	// Sequential awaits: Promise.all loses the result types in this
	// supabase-js version (see AGENTS.md).
	const materialsResult = await supabase
		.from('raw_materials')
		.select('id, name')
		.eq('active', true)
		.order('name', { ascending: true });
	const linksResult = await supabase
		.from('raw_material_brands')
		.select('raw_material_id, brand_id')
		.eq('active', true);
	const brandsResult = await supabase.from('brands').select('id, name').eq('active', true);

	if (materialsResult.error) throw materialsResult.error;
	if (linksResult.error) throw linksResult.error;
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

	const items: MaterialOption[] = materials.map((material) => {
		const allowed = allowedBrandIds.get(material.id) ?? new Set<string>();
		return {
			id: material.id,
			name: material.name,
			brands: brands.filter((brand) => allowed.has(brand.id))
		};
	});

	return { items };
};

// RPC error tokens (English, developer-facing) to user-facing Spanish messages.
const rpcErrors: Record<string, string> = {
	not_authenticated: 'Tu sesión no es válida. Inicia sesión de nuevo.',
	no_active_profile: 'Tu perfil no está activo. Contacta a una persona con administración.',
	raw_material_not_found: 'La materia prima seleccionada no existe o no está activa.',
	brand_not_found: 'La marca seleccionada no existe o no está activa.',
	brand_not_permitted_for_material: 'La marca seleccionada no es válida para esa materia prima.',
	supplier_lot_required: 'Ingresa el lote del proveedor.'
};

type Submitted = {
	material_id: string | null;
	brand_id: string | null;
	supplier_lot: string | null;
	expiry_date: string | null;
};

const toText = (value: string | File | null): string | null =>
	typeof value === 'string' ? value : null;

export const actions: Actions = {
	default: async (event) => {
		const formData = await event.request.formData();

		const submitted: Submitted = {
			material_id: toText(formData.get('material_id')),
			brand_id: toText(formData.get('brand_id')),
			supplier_lot: toText(formData.get('supplier_lot')),
			expiry_date: toText(formData.get('expiry_date'))
		};

		if (!submitted.material_id || !submitted.brand_id || !submitted.supplier_lot) {
			return fail(400, { error: 'Completa los datos del nuevo lote.', ...submitted });
		}

		const rpcArgs: Database['public']['Functions']['change_current_material_lot']['Args'] = {
			p_raw_material_id: submitted.material_id,
			p_brand_id: submitted.brand_id,
			p_supplier_lot: submitted.supplier_lot
		};
		// Optional date: omitting the key lets the RPC use its SQL default (null).
		if (submitted.expiry_date) rpcArgs.p_expiry_date = submitted.expiry_date;

		const { error } = await event.locals.supabase.rpc('change_current_material_lot', rpcArgs);

		if (error) {
			return fail(400, { error: rpcErrors[error.message] ?? error.message, ...submitted });
		}

		redirect(303, '/lots');
	}
};

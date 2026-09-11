// Business helper: validate that the current raw-material lots required by one
// recipe_version exist.
//
// Resolution path: recipe_version -> recipe_ingredients (required + optional)
// -> material_lots where is_current = true (the database guarantees at most one
// current lot per raw material via the partial unique index
// material_lots_one_current_per_raw_material).
//
// Rules (per AE1):
// - Only is_current = true lots are considered; no substitute brands or other
//   lots are inferred (an ingredient points at one raw material, and that
//   material must have its own current lot).
// - Optional recipe ingredients may be absent: they never invalidate the
//   version, they are simply not resolved.
// - Read-only: no database writes.

import type { SupabaseClient } from '@supabase/supabase-js';
import type { Database } from '$lib/types/database.types';

// Explicit row annotations: supabase-js 2.116 under TS 6 does not resolve the
// inferred select type in this toolchain (see AGENTS.md).
export type RecipeIngredientRow = Pick<
	Database['public']['Tables']['recipe_ingredients']['Row'],
	'id' | 'raw_material_id' | 'quantity' | 'unit' | 'optional'
>;
export type CurrentLotRow = Pick<
	Database['public']['Tables']['material_lots']['Row'],
	'id' | 'raw_material_id' | 'brand_id' | 'supplier_lot' | 'is_current' | 'status'
>;
export type RawMaterialName = Pick<
	Database['public']['Tables']['raw_materials']['Row'],
	'id' | 'name'
>;

export type MissingRequiredMaterial = {
	rawMaterialId: string;
	name: string;
};

export type ValidateCurrentLotsResult = {
	valid: boolean;
	resolvedLots: CurrentLotRow[];
	missingRequired: MissingRequiredMaterial[];
};

// Pure decision logic, free of data access so it can be unit tested.
// `missingRequiredRawMaterialIds` is enriched with names by the server-side
// wrapper below (the pure result has no way to know names).
export function validateCurrentLots(
	ingredients: readonly RecipeIngredientRow[],
	currentLots: readonly CurrentLotRow[]
): {
	valid: boolean;
	resolvedLots: CurrentLotRow[];
	missingRequiredRawMaterialIds: string[];
} {
	// At most one current lot per raw material (DB partial unique index), so a
	// plain assignment cannot hide a duplicate.
	// The caller (server wrapper) pre-filters with is_current = true; the
	// check here makes the pure function safe on its own ("exactly use current
	// material lots").
	const lotByMaterial = new Map<string, CurrentLotRow>();
	for (const lot of currentLots) {
		if (lot.is_current) {
			lotByMaterial.set(lot.raw_material_id, lot);
		}
	}

	const resolvedLots: CurrentLotRow[] = [];
	const missingRequiredRawMaterialIds: string[] = [];

	for (const ingredient of ingredients) {
		const lot = lotByMaterial.get(ingredient.raw_material_id);
		if (lot) {
			resolvedLots.push(lot);
		} else if (!ingredient.optional) {
			missingRequiredRawMaterialIds.push(ingredient.raw_material_id);
		}
		// Optional ingredient without a current lot: allowed, simply absent.
	}

	return {
		valid: missingRequiredRawMaterialIds.length === 0,
		resolvedLots,
		missingRequiredRawMaterialIds
	};
}

// Server-side validation through the Supabase client (server context only,
// read-only). Data-access errors are thrown for the caller to handle; the
// business outcome is always returned as a typed result.
export async function validateCurrentLotsForRecipeVersion(
	supabase: SupabaseClient<Database>,
	recipeVersionId: string
): Promise<ValidateCurrentLotsResult> {
	const ingredientsResult = await supabase
		.from('recipe_ingredients')
		.select('id, raw_material_id, quantity, unit, optional')
		.eq('recipe_version_id', recipeVersionId)
		.order('sort_order');
	if (ingredientsResult.error) throw ingredientsResult.error;
	const ingredients: RecipeIngredientRow[] = ingredientsResult.data ?? [];

	let currentLots: CurrentLotRow[] = [];
	const materialIds = [...new Set(ingredients.map((ingredient) => ingredient.raw_material_id))];
	if (materialIds.length > 0) {
		const lotsResult = await supabase
			.from('material_lots')
			.select('id, raw_material_id, brand_id, supplier_lot, is_current, status')
			.in('raw_material_id', materialIds)
			.eq('is_current', true);
		if (lotsResult.error) throw lotsResult.error;
		currentLots = lotsResult.data ?? [];
	}

	const pure = validateCurrentLots(ingredients, currentLots);

	let missingRequired: MissingRequiredMaterial[] = [];
	if (pure.missingRequiredRawMaterialIds.length > 0) {
		const namesResult = await supabase
			.from('raw_materials')
			.select('id, name')
			.in('id', pure.missingRequiredRawMaterialIds);
		if (namesResult.error) throw namesResult.error;
		const names: RawMaterialName[] = namesResult.data ?? [];
		const nameById = new Map(
			names.map((rawMaterial) => [rawMaterial.id, rawMaterial.name] as const)
		);
		missingRequired = pure.missingRequiredRawMaterialIds.map((rawMaterialId) => ({
			rawMaterialId,
			name: nameById.get(rawMaterialId) ?? ''
		}));
	}

	return {
		valid: pure.valid,
		resolvedLots: pure.resolvedLots,
		missingRequired
	};
}

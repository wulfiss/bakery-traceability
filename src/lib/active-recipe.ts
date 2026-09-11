// Business helper: resolve the active recipe_version for one product.
//
// Resolution path: product -> recipe_products (links) -> recipes ->
// recipe_versions (status = 'active').
//
// The database guarantees at most one active version per individual recipe
// (partial unique index recipe_versions_one_active_per_recipe), but a product
// could still be incorrectly linked to multiple recipes that each have an
// active version. This helper fails safely in both "none exists" and
// "ambiguous configuration" cases instead of guessing.

import type { SupabaseClient } from '@supabase/supabase-js';
import type { Database } from '$lib/types/database.types';

// Explicit row annotations: supabase-js 2.116 under TS 6 does not resolve the
// inferred select type in this toolchain (see AGENTS.md).
export type RecipeProductLink = Pick<
	Database['public']['Tables']['recipe_products']['Row'],
	'recipe_id'
>;
export type RecipeVersionLite = Pick<
	Database['public']['Tables']['recipe_versions']['Row'],
	'id' | 'recipe_id' | 'status'
>;

export type ActiveRecipe = {
	recipeId: string;
	recipeVersionId: string;
};

export type ActiveRecipeFailure =
	{ code: 'no_recipe' } | { code: 'no_active_version' } | { code: 'ambiguous_recipes' };

export type ActiveRecipeResult =
	{ ok: true; value: ActiveRecipe } | { ok: false; error: ActiveRecipeFailure };

// Pure resolver: keeps this decision logic free of data access so it can be
// unit tested. Input rows are exactly the shapes the Supabase selects return.
export function resolveActiveRecipe(
	links: readonly RecipeProductLink[],
	versions: readonly RecipeVersionLite[]
): ActiveRecipeResult {
	const recipeIds = [...new Set(links.map((link) => link.recipe_id))];
	if (recipeIds.length === 0) {
		return { ok: false, error: { code: 'no_recipe' } };
	}

	// Map recipe_id -> active version_id. The DB index guarantees at most one
	// active version per recipe, so a plain assignment is safe here.
	const activeVersionByRecipe = new Map<string, string>();
	for (const version of versions) {
		if (version.status === 'active' && recipeIds.includes(version.recipe_id)) {
			activeVersionByRecipe.set(version.recipe_id, version.id);
		}
	}

	const activeRecipeIds = recipeIds.filter((id) => activeVersionByRecipe.has(id));
	if (activeRecipeIds.length === 0) {
		return { ok: false, error: { code: 'no_active_version' } };
	}
	if (activeRecipeIds.length > 1) {
		return { ok: false, error: { code: 'ambiguous_recipes' } };
	}

	const recipeId = activeRecipeIds[0];
	const recipeVersionId = activeVersionByRecipe.get(recipeId);
	if (!recipeVersionId) {
		// Unreachable: recipeId came from the map above.
		return { ok: false, error: { code: 'no_active_version' } };
	}

	return { ok: true, value: { recipeId, recipeVersionId } };
}

// Server-side resolution through the Supabase client (server context only).
// Data-access errors are thrown for the caller to handle; business outcomes
// (missing recipe, missing active version, ambiguity) are returned as a
// typed result.
export async function resolveActiveRecipeForProduct(
	supabase: SupabaseClient<Database>,
	productId: string
): Promise<ActiveRecipeResult> {
	const linksResult = await supabase
		.from('recipe_products')
		.select('recipe_id')
		.eq('product_id', productId);
	if (linksResult.error) throw linksResult.error;
	const links: RecipeProductLink[] = linksResult.data ?? [];
	if (links.length === 0) {
		return { ok: false, error: { code: 'no_recipe' } };
	}

	const recipeIds = [...new Set(links.map((link) => link.recipe_id))];

	const versionsResult = await supabase
		.from('recipe_versions')
		.select('id, recipe_id, status')
		.in('recipe_id', recipeIds);
	if (versionsResult.error) throw versionsResult.error;
	const versions: RecipeVersionLite[] = versionsResult.data ?? [];

	return resolveActiveRecipe(links, versions);
}

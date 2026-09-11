import { describe, expect, it } from 'vitest';
import {
	resolveActiveRecipe,
	type RecipeProductLink,
	type RecipeVersionLite
} from './active-recipe';

const R1 = '11111111-1111-1111-1111-111111111111';
const R2 = '22222222-2222-2222-2222-222222222222';
const R3 = '33333333-3333-3333-3333-333333333333';

const link = (recipe_id: string): RecipeProductLink => ({ recipe_id });

const version = (
	id: string,
	recipe_id: string,
	status: RecipeVersionLite['status']
): RecipeVersionLite => ({
	id,
	recipe_id,
	status
});

describe('resolveActiveRecipe', () => {
	it('fails with no_recipe when the product has no recipe links', () => {
		expect(resolveActiveRecipe([], [])).toEqual({ ok: false, error: { code: 'no_recipe' } });
	});

	it('resolves the single active version of a linked recipe', () => {
		const result = resolveActiveRecipe(
			[link(R1)],
			[version('v1-1', R1, 'draft'), version('v1-2', R1, 'active'), version('v1-3', R1, 'retired')]
		);
		expect(result).toEqual({ ok: true, value: { recipeId: R1, recipeVersionId: 'v1-2' } });
	});

	it('fails with no_active_version when linked recipes have no active version', () => {
		const result = resolveActiveRecipe(
			[link(R1), link(R2)],
			[version('v1-1', R1, 'draft'), version('v2-1', R2, 'retired')]
		);
		expect(result).toEqual({ ok: false, error: { code: 'no_active_version' } });
	});

	it('fails with no_active_version when a linked recipe has no versions at all', () => {
		expect(resolveActiveRecipe([link(R1)], [])).toEqual({
			ok: false,
			error: { code: 'no_active_version' }
		});
	});

	it('fails with ambiguous_recipes when multiple linked recipes each have an active version', () => {
		const result = resolveActiveRecipe(
			[link(R1), link(R2)],
			[version('v1-1', R1, 'active'), version('v2-1', R2, 'active')]
		);
		expect(result).toEqual({ ok: false, error: { code: 'ambiguous_recipes' } });
	});

	it('resolves the single recipe with an active version among several links', () => {
		const result = resolveActiveRecipe(
			[link(R1), link(R2), link(R3)],
			[version('v1-1', R1, 'draft'), version('v2-1', R2, 'active'), version('v3-1', R3, 'retired')]
		);
		expect(result).toEqual({ ok: true, value: { recipeId: R2, recipeVersionId: 'v2-1' } });
	});

	it('treats duplicate links to the same recipe as one link (not ambiguity)', () => {
		const result = resolveActiveRecipe([link(R1), link(R1)], [version('v1-1', R1, 'active')]);
		expect(result).toEqual({ ok: true, value: { recipeId: R1, recipeVersionId: 'v1-1' } });
	});

	it('ignores active versions of recipes not linked to the product', () => {
		const result = resolveActiveRecipe(
			[link(R1)],
			[version('v1-1', R1, 'active'), version('v3-1', R3, 'active')]
		);
		expect(result).toEqual({ ok: true, value: { recipeId: R1, recipeVersionId: 'v1-1' } });
	});
});

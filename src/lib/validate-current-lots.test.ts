import { describe, expect, it } from 'vitest';
import {
	validateCurrentLots,
	type CurrentLotRow,
	type RecipeIngredientRow
} from './validate-current-lots';

const M_FLOUR = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const M_YEAST = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
const M_SALT = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
const M_OTHER = 'dddddddd-dddd-dddd-dddd-ddddddddddddd';

const ingredient = (raw_material_id: string, optional = false): RecipeIngredientRow => ({
	id: `ing-${raw_material_id}`,
	raw_material_id,
	quantity: 1,
	unit: 'kg',
	optional
});

const lot = (raw_material_id: string): CurrentLotRow => ({
	id: `lot-${raw_material_id}`,
	raw_material_id,
	brand_id: 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
	supplier_lot: 'S-1',
	is_current: true,
	status: 'in_use'
});

describe('validateCurrentLots', () => {
	it('is valid when every required ingredient has a current lot', () => {
		const result = validateCurrentLots(
			[ingredient(M_FLOUR), ingredient(M_YEAST)],
			[lot(M_FLOUR), lot(M_YEAST)]
		);
		expect(result.valid).toBe(true);
		expect(result.missingRequiredRawMaterialIds).toEqual([]);
		expect(result.resolvedLots.map((l) => l.raw_material_id)).toEqual([M_FLOUR, M_YEAST]);
	});

	it('is invalid and reports required materials without a current lot', () => {
		const result = validateCurrentLots(
			[ingredient(M_FLOUR), ingredient(M_YEAST), ingredient(M_SALT)],
			[lot(M_FLOUR)]
		);
		expect(result.valid).toBe(false);
		expect(result.missingRequiredRawMaterialIds).toEqual([M_YEAST, M_SALT]);
		expect(result.resolvedLots.map((l) => l.raw_material_id)).toEqual([M_FLOUR]);
	});

	it('allows optional ingredients to be absent (does not invalidate)', () => {
		const result = validateCurrentLots(
			[ingredient(M_FLOUR), ingredient(M_SALT, true)],
			[lot(M_FLOUR)]
		);
		expect(result.valid).toBe(true);
		expect(result.missingRequiredRawMaterialIds).toEqual([]);
		expect(result.resolvedLots.map((l) => l.raw_material_id)).toEqual([M_FLOUR]);
	});

	it('resolves present optional ingredients as well', () => {
		const result = validateCurrentLots(
			[ingredient(M_FLOUR), ingredient(M_SALT, true)],
			[lot(M_FLOUR), lot(M_SALT)]
		);
		expect(result.valid).toBe(true);
		expect(result.resolvedLots.map((l) => l.raw_material_id)).toEqual([M_FLOUR, M_SALT]);
	});

	it('is vacuously valid for a version without ingredients', () => {
		const result = validateCurrentLots([], []);
		expect(result).toEqual({ valid: true, resolvedLots: [], missingRequiredRawMaterialIds: [] });
	});

	it('ignores current lots of materials not used by the version', () => {
		const result = validateCurrentLots([ingredient(M_FLOUR)], [lot(M_FLOUR), lot(M_OTHER)]);
		expect(result.valid).toBe(true);
		expect(result.resolvedLots.map((l) => l.raw_material_id)).toEqual([M_FLOUR]);
	});

	it('keeps the ingredient (sort) order in resolved lots', () => {
		const result = validateCurrentLots(
			[ingredient(M_YEAST), ingredient(M_FLOUR)],
			[lot(M_FLOUR), lot(M_YEAST)]
		);
		expect(result.resolvedLots.map((l) => l.raw_material_id)).toEqual([M_YEAST, M_FLOUR]);
	});

	it('does not invent a lot when only a non-current lot exists (only is_current counts)', () => {
		const stale: CurrentLotRow = {
			...lot(M_FLOUR),
			id: 'lot-stale',
			is_current: false,
			status: 'closed'
		};
		const result = validateCurrentLots([ingredient(M_FLOUR)], [stale]);
		expect(result.valid).toBe(false);
		expect(result.missingRequiredRawMaterialIds).toEqual([M_FLOUR]);
	});
});

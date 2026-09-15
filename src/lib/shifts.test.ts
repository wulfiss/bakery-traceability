import { describe, expect, it } from 'vitest';
import { SHIFTS, SHIFT_COOKIE, type Shift } from './shifts';

// V5 invariant: new production operations use MAÑANA (morning) or NOCHE
// (night) only. 'afternoon' is historical — it can no longer be selected
// (runtime, below) and is no longer part of the Shift type (compile time).
type _afternoonExcludedFromShift = [Extract<'afternoon', Shift>] extends [never] ? true : never;
const afternoonExcludedFromShift: _afternoonExcludedFromShift = true;

describe('shifts (V5 invariant)', () => {
	it('offers exactly morning and night, and nothing else', () => {
		expect([...SHIFTS].sort()).toEqual(['morning', 'night']);
		expect(SHIFTS).toHaveLength(2);
	});

	it('does not offer the historical afternoon shift for new production', () => {
		expect(SHIFTS).not.toContain('afternoon' as Shift);
	});

	it('keeps the shift preference cookie name', () => {
		expect(SHIFT_COOKIE).toBe('bakery_shift');
	});

	it('keeps afternoon out of the Shift type at compile time', () => {
		// Only reachable if the type-level guard above compiled; the value
		// documents the intent for readers of the runtime assertions.
		expect(afternoonExcludedFromShift).toBe(true);
	});
});

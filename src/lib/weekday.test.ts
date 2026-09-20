import { describe, expect, it } from 'vitest';
import { isodowFromDateIso, spanishWeekdayLabel } from './weekday';

describe('isodowFromDateIso', () => {
	it('maps a stored Monday to 1', () => {
		expect(isodowFromDateIso('2026-09-14')).toBe(1);
		expect(isodowFromDateIso('2026-10-05')).toBe(1);
	});

	it('maps a stored Tuesday to 2', () => {
		expect(isodowFromDateIso('2026-09-15')).toBe(2);
	});

	it('maps a stored Sunday to 7', () => {
		expect(isodowFromDateIso('2026-09-20')).toBe(7);
	});

	it('returns 0 for an unusable date', () => {
		expect(isodowFromDateIso('nope')).toBe(0);
		expect(isodowFromDateIso('')).toBe(0);
	});
});

describe('spanishWeekdayLabel', () => {
	it('labels Monday', () => {
		expect(spanishWeekdayLabel('2026-09-14')).toBe('LUNES');
	});

	it('labels Wednesday with the accent', () => {
		expect(spanishWeekdayLabel('2026-09-16')).toBe('MIÉRCOLES');
	});

	it('labels Saturday', () => {
		expect(spanishWeekdayLabel('2026-09-19')).toBe('SÁBADO');
	});

	it('labels Sunday', () => {
		expect(spanishWeekdayLabel('2026-09-20')).toBe('DOMINGO');
	});

	it('returns empty for an unusable date', () => {
		expect(spanishWeekdayLabel('x')).toBe('');
	});
});

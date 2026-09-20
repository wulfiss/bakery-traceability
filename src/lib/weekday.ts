// Spanish weekday labels derived from the STORED production date
// (production_days.production_date), never from a recalculated "today"
// (AGENTS.md business-timezone rule: downstream weekday math uses the stored
// date). The input is a 'YYYY-MM-DD' string; the arithmetic below is pure
// date math on that stored value (no session/browser/process timezone).

// ISO day of week for a stored 'YYYY-MM-DD' date: 1 = Monday ... 7 = Sunday,
// the same convention as production_suggestions.weekday and
// extract(isodow from date). Returns 0 when the date is unusable.
export function isodowFromDateIso(dateIso: string): number {
	const [year, month, day] = dateIso.split('-').map(Number);
	if (!year || !month || !day) return 0;
	const jsDay = new Date(Date.UTC(year, month - 1, day)).getUTCDay();
	return jsDay === 0 ? 7 : jsDay;
}

const WEEKDAY_LABELS: Record<number, string> = {
	1: 'LUNES',
	2: 'MARTES',
	3: 'MIÉRCOLES',
	4: 'JUEVES',
	5: 'VIERNES',
	6: 'SÁBADO',
	7: 'DOMINGO'
};

// Spanish uppercase weekday label for a stored 'YYYY-MM-DD' date
// (e.g. '2026-09-14' -> 'LUNES'). Empty string when the date is unusable.
export function spanishWeekdayLabel(dateIso: string): string {
	return WEEKDAY_LABELS[isodowFromDateIso(dateIso)] ?? '';
}

// Shared shift constants.
// The selected shift is a UI preference only (cookie `bakery_shift`).
// It is never authorization and never inferred from the current time.
export type Shift = 'morning' | 'afternoon' | 'night';

export const SHIFTS: Shift[] = ['morning', 'afternoon', 'night'];

export const SHIFT_COOKIE = 'bakery_shift';

// Shared shift constants.
// The selected shift is a UI preference only (cookie `bakery_shift`).
// It is never authorization and never inferred from the current time.
//
// V5: new production operations use MAÑANA (morning) or NOCHE (night) only.
// 'afternoon' is historical: existing rows keep the code and remain readable
// (display label maps keep the TARDE entry), but it can no longer be selected
// and no new rows or 'T' batch codes are created with it.
export type Shift = 'morning' | 'night';

export const SHIFTS: Shift[] = ['morning', 'night'];

export const SHIFT_COOKIE = 'bakery_shift';

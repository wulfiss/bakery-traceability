// Role hierarchy for authorization (Phase AT).
// The database is the source of truth (profiles.role, RPC role checks);
// this module only centralizes the level comparison so server logic and
// UI convenience checks share one definition.
export type Role = 'operator' | 'supervisor' | 'admin';

const level: Record<Role, number> = {
	operator: 0,
	supervisor: 1,
	admin: 2
};

// True when `role` is at least the requested minimum level.
// A missing or unknown role never satisfies a minimum (defense in depth).
export function isAtLeastRole(role: Role | null | undefined, minimum: Role): boolean {
	if (role === null || role === undefined || !(role in level)) return false;
	return level[role] >= level[minimum];
}

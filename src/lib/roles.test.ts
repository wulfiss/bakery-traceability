import { describe, expect, it } from 'vitest';
import { isAtLeastRole } from './roles';

describe('isAtLeastRole', () => {
	it('treats operator as the minimum level', () => {
		expect(isAtLeastRole('operator', 'operator')).toBe(true);
		expect(isAtLeastRole('supervisor', 'operator')).toBe(true);
		expect(isAtLeastRole('admin', 'operator')).toBe(true);
	});

	it('keeps supervisor and admin above operator', () => {
		expect(isAtLeastRole('operator', 'supervisor')).toBe(false);
		expect(isAtLeastRole('supervisor', 'supervisor')).toBe(true);
		expect(isAtLeastRole('admin', 'supervisor')).toBe(true);
	});

	it('keeps admin at the top', () => {
		expect(isAtLeastRole('operator', 'admin')).toBe(false);
		expect(isAtLeastRole('supervisor', 'admin')).toBe(false);
		expect(isAtLeastRole('admin', 'admin')).toBe(true);
	});

	it('never satisfies a minimum when the role is missing or unknown', () => {
		expect(isAtLeastRole(null, 'operator')).toBe(false);
		expect(isAtLeastRole(undefined, 'operator')).toBe(false);
		expect(isAtLeastRole('manager' as never, 'operator')).toBe(false);
	});
});

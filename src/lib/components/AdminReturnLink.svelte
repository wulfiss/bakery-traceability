<script lang="ts">
	import { resolve } from '$app/paths';
	import { isAtLeastRole } from '$lib/roles';
	import type { Role } from '$lib/roles';

	// V6.14 (spec §63): the shared operational pages linked from the Admin
	// hub (Producción sugerida, Producción, Materias primas) are also used
	// by operators, who have no /admin area at all (admin layout guard).
	// This link gives the roles that DO have an admin hub (supervisor+) a
	// quick way back to /admin; for operators it renders nothing.
	// Authorization is untouched: the /admin layout guard and the RPC role
	// checks remain the real gates — this is a navigation affordance only.
	let { role }: { role: Role | null } = $props();
</script>

{#if isAtLeastRole(role, 'supervisor')}
	<p class="admin-return">
		<a href={resolve('/admin')}>Volver a Administración</a>
	</p>
{/if}

<style>
	.admin-return {
		margin: 0 0 16px;
	}

	.admin-return a {
		font-size: 0.9rem;
		font-weight: 700;
	}
</style>

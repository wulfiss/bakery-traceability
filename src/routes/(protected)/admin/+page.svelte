<script lang="ts">
	import { resolve } from '$app/paths';
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();

	// AT: convenience only — admin-only links are hidden for supervisors;
	// the real gate is the admin layout guard + RPC role checks.
	const isAdmin = data.role === 'admin';

	const links = [
		// V6.3: direct access to operational functions (spec §8/§52).
		// All three of these are shared operational routes, not admin-only
		// areas, so they stay visible to supervisors too; the hub itself is
		// already restricted to supervisor+ by the admin layout guard, and
		// the target routes re-authorize their own role needs.
		{ label: 'Producción sugerida', href: '/production/suggestions', adminOnly: false },
		{ label: 'Producción', href: '/production', adminOnly: false },
		{ label: 'Materias primas', href: '/lots', adminOnly: false },
		{ label: 'Pedidos externos', href: '/admin/external-orders', adminOnly: false },
		{ label: 'Materiales', href: '/admin/raw-materials', adminOnly: true },
		{ label: 'Marcas', href: '/admin/brands', adminOnly: true },
		{ label: 'Productos', href: '/admin/products', adminOnly: true },
		{ label: 'Recetas', href: '/admin/recipes', adminOnly: true },
		{ label: 'Planificación', href: '/admin/planning', adminOnly: true },
		{ label: 'Trazabilidad', href: '/admin/traceability', adminOnly: true }
	] as const;
</script>

<main class="page">
	<h1>Administración</h1>

	<ul class="links">
		{#each links.filter((link) => !link.adminOnly || isAdmin) as link (link.href)}
			<li>
				<a href={resolve(link.href)}>{link.label}</a>
			</li>
		{/each}
	</ul>
</main>

<style>
	.page {
		padding: 16px;
		width: 100%;
		max-width: var(--content-max);
		margin: 0 auto;
	}

	.links {
		list-style: none;
		margin: 0;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.links a {
		display: block;
		min-height: var(--touch-min);
		line-height: calc(var(--touch-min) - 2px);
		padding: 10px 14px;
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		background: var(--color-surface);
		text-decoration: none;
		font-weight: 700;
	}
</style>

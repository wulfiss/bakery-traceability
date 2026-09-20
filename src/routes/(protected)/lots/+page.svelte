<script lang="ts">
	import { resolve } from '$app/paths';
	import AdminReturnLink from '$lib/components/AdminReturnLink.svelte';
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();

	// Formats a YYYY-MM-DD date as DD/MM/YYYY for the Spanish UI.
	const formatDate = (iso: string | null): string | null => {
		if (!iso) return null;
		const parts = iso.slice(0, 10).split('-');
		if (parts.length !== 3) return null;
		return `${parts[2]}/${parts[1]}/${parts[0]}`;
	};
</script>

<main class="page">
	<h1>Materias primas en uso</h1>
	<AdminReturnLink role={data.role} />

	{#if data.items.length > 0}
		<a class="change-lot" href={resolve('/lots/change')}>Cambiar lote actual</a>
	{/if}

	{#if data.items.length === 0}
		<p class="empty">No hay materias primas activas.</p>
	{:else}
		<ul class="cards">
			{#each data.items as item (item.id)}
				<li class="card">
					<h2 class="card-name">{item.name}</h2>
					{#if item.lot}
						<p class="lot">{item.lot.brandName} · {item.lot.supplierLot}</p>
						{#if item.lot.expiryDate}
							<p class="expiry">Vence: {formatDate(item.lot.expiryDate)}</p>
						{/if}
					{:else}
						<p class="no-lot">Sin lote activo</p>
					{/if}
				</li>
			{/each}
		</ul>
	{/if}
</main>

<style>
	.page {
		max-width: var(--content-max);
		margin: 0 auto;
		padding: 16px;
	}

	h1 {
		font-size: 1.375rem;
		margin-bottom: 16px;
	}

	.change-lot {
		display: block;
		width: 100%;
		min-height: var(--touch-min);
		margin-bottom: 16px;
		padding: 10px 16px;
		font-size: 1rem;
		font-weight: 700;
		text-align: center;
		text-decoration: none;
		color: var(--color-on-primary);
		background: var(--color-primary);
		border-radius: var(--radius);
	}

	.cards {
		list-style: none;
		margin: 0;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.card {
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		padding: 14px 16px;
	}

	.card-name {
		font-size: 1.0625rem;
		margin: 0 0 6px;
	}

	.lot {
		margin: 0;
		font-size: 0.9375rem;
	}

	.expiry {
		margin: 4px 0 0;
		font-size: 0.8125rem;
		color: var(--color-text-muted);
	}

	.no-lot {
		margin: 0;
		font-size: 0.9375rem;
		color: var(--color-text-muted);
	}

	.empty {
		color: var(--color-text-muted);
	}
</style>

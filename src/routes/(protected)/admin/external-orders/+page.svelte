<script lang="ts">
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();

	const statusLabels: Record<string, string> = {
		pending: 'PENDIENTE',
		in_production: 'EN PRODUCCIÓN',
		completed: 'COMPLETADO',
		cancelled: 'CANCELADO'
	};
</script>

<main class="page">
	<h1>Pedidos externos</h1>

	{#if data.orders.length === 0}
		<p class="empty">Sin pedidos externos.</p>
	{:else}
		<ul class="items">
			{#each data.orders as order (order.id)}
				<li class="item">
					<span class="item-info">
						<span class="order-number">N° {order.orderNumber}</span>
						<span class="customer">{order.customerName}</span>
						<span class="date">{order.requestedDate}</span>
					</span>
					<span class="status">{statusLabels[order.status]}</span>
				</li>
			{/each}
		</ul>
	{/if}
</main>

<style>
	.page {
		display: block;
		width: 100%;
		max-width: var(--content-max);
		margin: 0 auto;
	}

	.empty {
		color: var(--color-text-muted);
	}

	.items {
		list-style: none;
		margin: 0;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.item {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 8px;
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		padding: 12px 14px;
	}

	.item-info {
		display: flex;
		flex-direction: column;
		gap: 2px;
		flex: 1;
		min-width: 0;
	}

	.order-number {
		font-weight: 700;
	}

	.customer {
		font-size: 0.9rem;
	}

	.date {
		font-size: 0.85rem;
		color: var(--color-text-muted);
	}

	.status {
		flex-shrink: 0;
		font-size: 0.75rem;
		font-weight: 700;
		color: var(--color-primary);
	}
</style>

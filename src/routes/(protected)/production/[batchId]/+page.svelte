<script lang="ts">
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();

	const shiftLabels: Record<string, string> = {
		morning: 'MAÑANA',
		afternoon: 'TARDE',
		night: 'NOCHE'
	};

	const statusLabels: Record<string, string> = {
		in_progress: 'EN PRODUCCIÓN',
		completed: 'COMPLETADO',
		cancelled: 'CANCELADO'
	};
</script>

<main class="page">
	<h1>{data.productName}</h1>

	<div class="detail">
		<span class="detail-label">Lote</span>
		<span class="detail-value">{data.batch.batch_code}</span>
	</div>

	<div class="detail">
		<span class="detail-label">Turno</span>
		<span class="detail-value">{shiftLabels[data.batch.shift_code] ?? data.batch.shift_code}</span>
	</div>

	<div class="detail">
		<span class="detail-label">Estado</span>
		<span class="detail-value">{statusLabels[data.batch.status] ?? data.batch.status}</span>
	</div>

	<div class="detail">
		<span class="detail-label">Cantidad prevista</span>
		<span class="detail-value">{data.quantity} {data.unit}</span>
	</div>

	<section class="section">
		<h2>Materias primas</h2>
		{#if data.materials.length === 0}
			<p class="empty">Sin materias primas registradas.</p>
		{:else}
			<ul class="materials">
				{#each data.materials as material (material.name)}
					<li class="material">
						<span class="material-name">
							{material.name} — {material.quantity}
							{material.unit}
						</span>
						<span class="material-lot">Lote {material.lot}</span>
					</li>
				{/each}
			</ul>
		{/if}
	</section>
</main>

<style>
	.page {
		display: block;
		width: 100%;
		max-width: var(--content-max);
		margin: 0 auto;
		padding: 16px 16px 32px;
		box-sizing: border-box;
	}

	h1 {
		font-size: 1.4rem;
		margin: 8px 0 16px;
	}

	.detail {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 8px;
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		padding: 12px 14px;
		margin-bottom: 8px;
	}

	.detail-label {
		font-size: 0.9375rem;
		color: var(--color-text-muted);
	}

	.detail-value {
		font-size: 0.95rem;
		font-weight: 700;
		text-align: right;
	}

	.section {
		margin-top: 20px;
	}

	h2 {
		font-size: 1.0625rem;
		margin: 0 0 8px;
	}

	.materials {
		list-style: none;
		margin: 0;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.material {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 8px;
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		padding: 12px 14px;
	}

	.material-name {
		font-size: 0.95rem;
	}

	.material-lot {
		font-size: 0.9375rem;
		color: var(--color-text-muted);
		white-space: nowrap;
	}

	.empty {
		margin: 0;
		color: var(--color-text-muted);
		font-size: 0.9375rem;
	}
</style>

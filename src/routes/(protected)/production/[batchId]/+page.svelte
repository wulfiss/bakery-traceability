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

	<div class="detail">
		<span class="detail-label">Materias primas</span>
		<span class="detail-value {data.materialsVerified ? '' : 'muted'}">
			{data.materialsVerified ? '✓ verificadas' : '—'}
		</span>
	</div>

	{#if data.batch.status === 'in_progress'}
		<!-- AH1: the button is shown but the completion flow (quantity form +
			complete_production_batch) arrives in phases AI1/AI2. -->
		<button type="button" class="finalize-btn" disabled>FINALIZAR</button>
	{/if}
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

	.muted {
		color: var(--color-text-muted);
	}

	.finalize-btn {
		display: block;
		width: 100%;
		min-height: var(--touch-min);
		margin-top: 20px;
		padding: 12px 16px;
		font-size: 1rem;
		font-weight: 700;
		text-align: center;
		color: var(--color-on-primary);
		background: var(--color-primary);
		border: none;
		border-radius: var(--radius);
	}
</style>

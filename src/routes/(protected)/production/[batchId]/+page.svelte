<script lang="ts">
	import { enhance } from '$app/forms';
	import { preventDoubleSubmit } from '$lib/forms';
	import type { ActionData, PageData } from './$types';

	let { data, form }: { data: PageData; form: ActionData } = $props();

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

	// AI2: the actual quantity starts prefilled with the requested quantity
	// (guide §54). Kept as a string so typed values survive untouched and the
	// server action does the final numeric validation.
	let quantity = $state(String(data.quantity));

	// AO2: per-product quantities for the multi-output form (empty = that
	// product is not produced and is not recorded).
	let multiQuantities = $state<Record<string, string>>(
		Object.fromEntries((data.multiOutputs ?? []).map((product) => [product.id, '']))
	);

	function stepQuantity(delta: number) {
		const current = Number.parseFloat(quantity);
		const base = Number.isFinite(current) ? current : 0;
		const next = base + delta;
		quantity = next > 0 ? String(next) : '0';
	}
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

	{#if data.recipeName}
		<div class="detail">
			<span class="detail-label">Preparación</span>
			<span class="detail-value">{data.recipeName}</span>
		</div>
	{/if}

	<div class="detail">
		<span class="detail-label">Materias primas</span>
		<span class="detail-value {data.materialsVerified ? '' : 'muted'}">
			{data.materialsVerified ? '✓ verificadas' : '—'}
		</span>
	</div>

	{#if data.batch.status === 'in_progress'}
		{#if data.multiOutputs}
			<!-- AO2: multi-output completion form. One quantity per product of
				the batch's recipe; the units come from the products (read-only)
				and products left empty are not recorded. -->
			<form
				method="POST"
				action="?/finalizeMulti"
				use:enhance={preventDoubleSubmit}
				class="finalize-form"
			>
				<p class="qty-label">Cantidad realizada por producto</p>
				{#each data.multiOutputs as product (product.id)}
					<div class="output">
						<p class="output-name">{product.name}</p>
						<input
							type="number"
							name="qty_{product.id}"
							class="output-input"
							bind:value={multiQuantities[product.id]}
							step="any"
							min="0"
							inputmode="decimal"
						/>
						<p class="qty-unit">{product.unit}</p>
					</div>
				{/each}

				{#if form?.error}
					<p class="error" role="alert">{form.error}</p>
				{/if}

				<button type="submit" class="finalize-btn">CONFIRMAR FINALIZACIÓN</button>
			</form>
		{:else}
			<!-- AI2: completion form. Posts to this page's own finalize action
			(params.batchId is authoritative, so no UUID travels in the form).
			The unit is shown read-only and sent hidden; only the quantity is
			operator-controlled. -->
			<form
				method="POST"
				action="?/finalize"
				use:enhance={preventDoubleSubmit}
				class="finalize-form"
			>
				<p class="qty-label">Cantidad realizada</p>
				<div class="qty-row">
					<button
						type="button"
						class="qty-btn"
						onclick={() => stepQuantity(-1)}
						aria-label="Disminuir"
					>
						−
					</button>
					<input
						type="number"
						name="actual_quantity"
						id="actual_quantity"
						class="qty-input"
						bind:value={quantity}
						step="any"
						min="0"
						inputmode="decimal"
					/>
					<button
						type="button"
						class="qty-btn"
						onclick={() => stepQuantity(1)}
						aria-label="Aumentar"
					>
						+
					</button>
				</div>
				<p class="qty-unit">{data.unit}</p>
				<input type="hidden" name="unit" value={data.unit} />

				{#if form?.error}
					<p class="error" role="alert">{form.error}</p>
				{/if}

				<button type="submit" class="finalize-btn">CONFIRMAR FINALIZACIÓN</button>
			</form>
		{/if}
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

	.finalize-form {
		margin-top: 20px;
	}

	.qty-label {
		margin: 0 0 8px;
		font-size: 0.9375rem;
		color: var(--color-text-muted);
	}

	.qty-row {
		display: flex;
		align-items: stretch;
		gap: 8px;
	}

	.qty-btn {
		width: 56px;
		min-height: var(--touch-min);
		font-size: 1.5rem;
		font-weight: 700;
		color: var(--color-text);
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
	}

	.qty-btn:disabled {
		opacity: 0.5;
	}

	.qty-input {
		flex: 1;
		min-width: 0;
		min-height: var(--touch-min);
		font-size: 1.5rem;
		font-weight: 700;
		text-align: center;
		color: var(--color-text);
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		-moz-appearance: textfield;
		appearance: textfield;
	}

	.qty-input::-webkit-outer-spin-button,
	.qty-input::-webkit-inner-spin-button {
		-webkit-appearance: none;
		margin: 0;
	}

	.qty-unit {
		margin: 8px 0 0;
		text-align: center;
		font-size: 0.9375rem;
		color: var(--color-text-muted);
	}

	.output {
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		padding: 12px 14px;
		margin-bottom: 10px;
	}

	.output-name {
		margin: 0 0 8px;
		font-size: 1rem;
		font-weight: 700;
		color: var(--color-text);
	}

	.output-input {
		width: 100%;
		min-height: var(--touch-min);
		font-size: 1.5rem;
		font-weight: 700;
		text-align: center;
		color: var(--color-text);
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		box-sizing: border-box;
		-moz-appearance: textfield;
		appearance: textfield;
	}

	.output-input::-webkit-outer-spin-button,
	.output-input::-webkit-inner-spin-button {
		-webkit-appearance: none;
		margin: 0;
	}

	.output .qty-unit {
		margin: 6px 0 0;
	}

	.error {
		margin: 12px 0 0;
		font-weight: 700;
		color: var(--color-danger);
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

	.finalize-btn:disabled {
		opacity: 0.5;
	}
</style>

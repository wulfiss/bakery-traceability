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

	// V5.5: "USAR OTRO LOTE" form state (in-progress batches only). The
	// operator must pick one of the materials the batch already uses, a
	// permitted brand, the new supplier lot and the incorporation date. The
	// toggle stays client-side; submitted values are re-read from the action
	// data so they survive a failed submit.
	let useLotOpen = $state(false);
	let useLotMaterial = $state<string>(form?.raw_material_id ?? '');
	let useLotBrand = $state<string>(form?.brand_id ?? '');
	let useLotLot = $state<string>(form?.supplier_lot ?? '');
	let useLotOpenedAt = $state<string>(form?.opened_at ?? data.businessDate);

	const useLotMaterialOption = $derived(
		data.lotOptions.find((option) => option.id === useLotMaterial) ?? null
	);
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

	{#if data.batch.status === 'completed' && data.outputs.length > 0}
		<!-- AO3: the outputs actually recorded at finalization. A multi-output
			batch shows one row per produced product. -->
		<div class="outputs">
			<p class="outputs-title">Producción realizada</p>
			{#each data.outputs as output (output.name)}
				<div class="output-row">
					<span class="output-row-name">{output.name}</span>
					<span class="output-row-qty">{output.quantity} {output.unit}</span>
				</div>
			{/each}
		</div>
	{/if}

	{#if data.recipeName}
		<div class="detail">
			<span class="detail-label">Preparación</span>
			<span class="detail-value">{data.recipeName}</span>
		</div>
	{/if}

	<!-- V5.5: the raw materials the batch is using and the exact lots linked
		to the batch (the start snapshot plus every "USAR OTRO LOTE" addition).
		For a completed batch this list is final history; the page never shows
		UUIDs, only names and supplier lot codes. -->
	<div class="materials">
		<p class="materials-title">Materias primas</p>
		{#if data.materialsVerified}
			{#each data.batchMaterials as material (material.id)}
				<div class="material">
					<p class="material-name">{material.name}</p>
					<ul class="material-lots">
						{#each material.lots as lot, i (i + ':' + lot)}
							<li class="material-lot">{lot}</li>
						{/each}
					</ul>
				</div>
			{/each}
		{:else}
			<p class="materials-empty">—</p>
		{/if}
	</div>

	{#if data.batch.status === 'in_progress'}
		<!-- V5.5: mid-dough, the baker can open a second lot of a material the
			batch already uses (e.g. a second bag of flour). The form only offers
			the materials the batch already uses; the new lot is appended to the
			batch's lot list and becomes current for future production. -->
		{#if useLotOpen}
			<form method="POST" class="use-lot-form" action="?/useLot" use:enhance={preventDoubleSubmit}>
				<h2 class="use-lot-title">Usar otro lote</h2>

				<label>
					<span>Materia prima</span>
					<select name="raw_material_id" bind:value={useLotMaterial} required>
						<option value="" disabled>Seleccioná una materia prima</option>
						{#each data.lotOptions as option (option.id)}
							<option value={option.id}>{option.name}</option>
						{/each}
					</select>
				</label>

				<label>
					<span>Marca</span>
					<select name="brand_id" bind:value={useLotBrand} required>
						<option value="" disabled>Seleccioná una marca</option>
						{#each useLotMaterialOption?.brands ?? [] as brand (brand.id)}
							<option value={brand.id}>{brand.name}</option>
						{/each}
					</select>
				</label>

				<label>
					<span>Lote</span>
					<input
						type="text"
						name="supplier_lot"
						bind:value={useLotLot}
						required
						autocomplete="off"
					/>
				</label>

				<label>
					<span>Fecha de incorporación</span>
					<input type="date" name="opened_at" bind:value={useLotOpenedAt} />
				</label>

				{#if form?.error}
					<p class="error" role="alert">{form.error}</p>
				{/if}

				<div class="use-lot-actions">
					<button type="submit" class="submit">CONFIRMAR</button>
					<button type="button" class="secondary" onclick={() => (useLotOpen = false)}>
						CANCELAR
					</button>
				</div>
			</form>
		{:else}
			<button type="button" class="add-lot-button" onclick={() => (useLotOpen = true)}>
				+ USAR OTRO LOTE
			</button>
		{/if}
	{/if}

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

	.outputs {
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		padding: 12px 14px;
		margin-bottom: 8px;
	}

	.outputs-title {
		margin: 0 0 8px;
		font-size: 0.9375rem;
		color: var(--color-text-muted);
	}

	.output-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 8px;
		padding: 6px 0;
		border-top: 1px solid var(--color-border);
	}

	.output-row-name {
		font-size: 0.95rem;
		font-weight: 700;
		color: var(--color-text);
	}

	.output-row-qty {
		font-size: 0.95rem;
		font-weight: 700;
		text-align: right;
		color: var(--color-text);
	}

	.muted {
		color: var(--color-text-muted);
	}

	.materials {
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		padding: 12px 14px;
		margin-bottom: 8px;
	}

	.materials-title {
		margin: 0 0 8px;
		font-size: 0.9375rem;
		color: var(--color-text-muted);
	}

	.materials-empty {
		margin: 0;
		font-weight: 700;
		color: var(--color-text-muted);
	}

	.material + .material {
		border-top: 1px solid var(--color-border);
	}

	.material-name {
		margin: 10px 0 4px;
		font-size: 0.95rem;
		font-weight: 700;
		color: var(--color-text);
	}

	.material-lots {
		list-style: none;
		margin: 0;
		padding: 0;
	}

	.material-lot {
		padding: 2px 0;
		font-size: 0.9375rem;
		color: var(--color-text);
	}

	.material-lot::before {
		content: '- ';
		color: var(--color-text-muted);
	}

	.add-lot-button {
		display: block;
		width: 100%;
		min-height: var(--touch-min);
		margin-top: 10px;
		padding: 10px 12px;
		font-size: 1rem;
		font-weight: 700;
		text-align: center;
		color: var(--color-primary);
		background: var(--color-surface);
		border: 1px dashed var(--color-primary);
		border-radius: var(--radius);
	}

	.use-lot-form {
		display: block;
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		padding: 12px 14px;
		margin-top: 16px;
	}

	.use-lot-title {
		font-size: 1.0625rem;
		margin: 0 0 12px;
	}

	.use-lot-form label {
		display: block;
		margin-bottom: 14px;
	}

	.use-lot-form label span {
		display: block;
		margin-bottom: 6px;
		font-size: 0.9rem;
		font-weight: 700;
		color: var(--color-text-muted);
	}

	.use-lot-form select,
	.use-lot-form input {
		display: block;
		width: 100%;
		min-height: var(--touch-min);
		padding: 10px 12px;
		font-size: 1rem;
		color: var(--color-text);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		background: var(--color-surface);
		box-sizing: border-box;
	}

	.use-lot-actions {
		display: flex;
		gap: 10px;
		margin-top: 6px;
	}

	.use-lot-actions .submit {
		flex: 1;
		display: block;
		min-height: var(--touch-min);
		padding: 12px;
		font-size: 1rem;
		font-weight: 700;
		letter-spacing: 0.02em;
		color: var(--color-on-primary);
		background: var(--color-primary);
		border: none;
		border-radius: var(--radius);
	}

	.use-lot-actions .secondary {
		display: inline-block;
		min-height: var(--touch-min);
		padding: 12px 16px;
		font-size: 1rem;
		font-weight: 700;
		color: var(--color-text-muted);
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
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

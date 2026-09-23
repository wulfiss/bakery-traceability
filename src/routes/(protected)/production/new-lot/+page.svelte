<script lang="ts">
	import { enhance } from '$app/forms';
	import { resolve } from '$app/paths';
	import { preventDoubleSubmit } from '$lib/forms';
	import type { ActionData, PageData } from './$types';

	let { data, form }: { data: PageData; form: ActionData } = $props();

	// V6.17: this is the former inline "AGREGAR MATERIA PRIMA" form on
	// /production, now its own page. Submitted values are re-read from the
	// action data so they survive a failed submit (use:enhance re-renders in
	// place).
	type FormState = {
		error?: string | null;
		material_id?: string | null;
		brand_id?: string | null;
		supplier_lot?: string | null;
		opened_at?: string | null;
	};
	const f: FormState = $derived((form ?? {}) as FormState);

	let materialId = $state<string>(f.material_id ?? data.prefillMaterialId ?? '');
	let brandId = $state<string>(f.brand_id ?? '');
	let supplierLot = $state<string>(f.supplier_lot ?? '');
	let openedAt = $state<string>(f.opened_at ?? data.businessDate);

	const materialOption = $derived(
		data.materials.find((material) => material.id === materialId) ?? null
	);

	// Changing the material invalidates the previously chosen brand (the
	// permitted brands depend on the material).
	function onMaterialChange(): void {
		brandId = '';
	}
</script>

<main class="page">
	<h1>Agregar materia prima</h1>

	<form
		method="POST"
		class="add-lot-form"
		action={resolve('/production/new-lot?/addLot')}
		use:enhance={preventDoubleSubmit}
	>
		<label>
			<span>Materia prima</span>
			<select name="material_id" bind:value={materialId} required onchange={onMaterialChange}>
				<option value="" disabled>Seleccioná una materia prima</option>
				{#each data.materials as material (material.id)}
					<option value={material.id}>{material.name}</option>
				{/each}
			</select>
		</label>

		<label>
			<span>Marca</span>
			<select name="brand_id" bind:value={brandId} required>
				<option value="" disabled>Seleccioná una marca</option>
				{#each materialOption?.brands ?? [] as brand (brand.id)}
					<option value={brand.id}>{brand.name}</option>
				{/each}
			</select>
		</label>

		<label>
			<span>Lote</span>
			<input type="text" name="supplier_lot" bind:value={supplierLot} required autocomplete="off" />
		</label>

		<label>
			<span>Fecha de incorporación</span>
			<input type="date" name="opened_at" bind:value={openedAt} />
		</label>

		{#if f.error}
			<p class="error" role="alert">{f.error}</p>
		{/if}

		<div class="add-lot-actions">
			<button type="submit" class="submit">CONFIRMAR</button>
			<a class="secondary" href={resolve('/production')}>CANCELAR</a>
		</div>
	</form>
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

	.add-lot-form {
		display: block;
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		padding: 12px 14px;
	}

	.add-lot-form label {
		display: block;
		margin-bottom: 14px;
	}

	.add-lot-form label span {
		display: block;
		margin-bottom: 6px;
		font-size: 0.9rem;
		font-weight: 700;
		color: var(--color-text-muted);
	}

	.add-lot-form select,
	.add-lot-form input {
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

	.error {
		color: var(--color-danger);
		background: var(--color-surface);
		border: 1px solid var(--color-danger);
		border-radius: var(--radius);
		padding: 12px 14px;
		margin: 0 0 14px;
		font-size: 0.95rem;
	}

	.add-lot-actions {
		display: flex;
		gap: 10px;
		margin-top: 6px;
	}

	.add-lot-actions .submit {
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
		cursor: pointer;
	}

	.add-lot-actions .secondary {
		display: inline-block;
		min-height: var(--touch-min);
		padding: 12px 16px;
		font-size: 1rem;
		font-weight: 700;
		color: var(--color-text-muted);
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		text-decoration: none;
	}
</style>

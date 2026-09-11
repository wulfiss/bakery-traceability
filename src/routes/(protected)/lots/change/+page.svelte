<script lang="ts">
	import { resolve } from '$app/paths';
	import type { ActionData, PageData } from './$types';

	let { data, form }: { data: PageData; form: ActionData } = $props();

	// Seeded from `form` once; on a failed form action SvelteKit remounts the
	// page with the new `form`, so capturing the initial value is intentional.
	let materialId = $state(form?.material_id ?? '');

	// Only brands permitted for the selected raw material are offered.
	const material = $derived(data.items.find((item) => item.id === materialId) ?? null);
	const brands = $derived(material?.brands ?? []);
</script>

<main class="page">
	<h1>Cambiar lote actual</h1>

	{#if form?.error}
		<p class="error" role="alert">{form.error}</p>
	{/if}

	<form method="POST" class="form">
		<div class="field">
			<label for="material_id">Materia prima</label>
			<select id="material_id" name="material_id" bind:value={materialId} required>
				<option value="" disabled>Selecciona una materia prima</option>
				{#each data.items as item (item.id)}
					<option value={item.id}>{item.name}</option>
				{/each}
			</select>
		</div>

		<div class="field">
			<label for="brand_id">Marca</label>
			<select id="brand_id" name="brand_id" required>
				<option value="" disabled>Selecciona una marca</option>
				{#each brands as brand (brand.id)}
					<option value={brand.id}>{brand.name}</option>
				{/each}
			</select>
		</div>

		<div class="field">
			<label for="supplier_lot">Lote</label>
			<input
				id="supplier_lot"
				name="supplier_lot"
				type="text"
				value={form?.supplier_lot ?? ''}
				autocomplete="off"
				required
			/>
		</div>

		<div class="field">
			<label for="expiry_date">Vencimiento</label>
			<input id="expiry_date" name="expiry_date" type="date" value={form?.expiry_date ?? ''} />
		</div>

		<button type="submit" class="submit">CONFIRMAR CAMBIO</button>
	</form>

	<p class="back"><a href={resolve('/lots')}>Volver a materias primas</a></p>
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

	.error {
		color: var(--color-danger);
		background: var(--color-surface);
		border: 1px solid var(--color-danger);
		border-radius: var(--radius);
		padding: 12px;
		margin: 0 0 16px;
		font-size: 0.95rem;
	}

	.form {
		display: block;
	}

	.field {
		margin-bottom: 16px;
	}

	label {
		display: block;
		margin-bottom: 6px;
		font-size: 0.95rem;
		color: var(--color-text-muted);
	}

	select,
	input {
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

	.submit {
		display: block;
		width: 100%;
		min-height: calc(var(--touch-min) + 4px);
		margin-top: 24px;
		padding: 12px;
		font-size: 1.05rem;
		font-weight: 700;
		letter-spacing: 0.02em;
		color: var(--color-on-primary);
		background: var(--color-primary);
		border: none;
		border-radius: var(--radius);
		cursor: pointer;
	}

	.back {
		margin-top: 24px;
		text-align: center;
	}

	.back a {
		display: inline-block;
		min-height: var(--touch-min);
		line-height: calc(var(--touch-min) - 2px);
		color: var(--color-primary);
	}
</style>

<script lang="ts">
	import { resolve } from '$app/paths';
	import { SHIFTS } from '$lib/shifts';
	import type { ActionData, PageData } from './$types';

	let { data, form }: { data: PageData; form: ActionData } = $props();

	// Seeded from `form` once; on a failed form action SvelteKit remounts the
	// page with the new `form`, so capturing the initial value is intentional.
	let productId = $state(form?.product_id ?? '');
	let unit = $state(form?.unit ?? '');
	let shiftCode = $state(form?.shift_code ?? data.shift ?? '');
	let reasonCode = $state(form?.reason_code ?? '');
	let reasonNote = $state(form?.reason_note ?? '');

	const reasonLabels: Record<string, string> = {
		replenishment: 'Reposición',
		increased_demand: 'Mayor demanda',
		remake: 'Rehacer producción',
		other: 'Otro'
	};

	// MAÑANA and NOCHE only: afternoon is historical (see $lib/shifts).
	const shiftLabels: Record<string, string> = {
		morning: 'MAÑANA',
		night: 'NOCHE'
	};

	// The unit defaults to the product's default unit whenever the product
	// changes; the operator may still edit it afterwards.
	const onProductChange = () => {
		const product = data.products.find((item) => item.id === productId) ?? null;
		unit = product?.defaultUnit ?? '';
	};
</script>

<main class="page">
	<h1>Producción adicional</h1>

	{#if form?.error}
		<p class="error" role="alert">{form.error}</p>
	{/if}

	<form method="POST" class="form">
		<div class="field">
			<label for="product_id">Producto</label>
			<select
				id="product_id"
				name="product_id"
				bind:value={productId}
				onchange={onProductChange}
				required
			>
				<option value="" disabled>Selecciona un producto</option>
				{#each data.products as product (product.id)}
					<option value={product.id}>{product.name}</option>
				{/each}
			</select>
		</div>

		<div class="field">
			<label for="requested_quantity">Cantidad</label>
			<input
				id="requested_quantity"
				name="requested_quantity"
				type="number"
				min="0"
				step="any"
				value={form?.requested_quantity ?? ''}
				required
			/>
		</div>

		<div class="field">
			<label for="unit">Unidad</label>
			<input id="unit" name="unit" type="text" bind:value={unit} autocomplete="off" required />
		</div>

		<div class="field">
			<label for="reason_code">Motivo</label>
			<select id="reason_code" name="reason_code" bind:value={reasonCode} required>
				<option value="" disabled>Selecciona un motivo</option>
				{#each Object.entries(reasonLabels) as [value, label] (value)}
					<option {value}>{label}</option>
				{/each}
			</select>
		</div>

		{#if reasonCode === 'other'}
			<div class="field">
				<label for="reason_note">Detalle</label>
				<input
					id="reason_note"
					name="reason_note"
					type="text"
					bind:value={reasonNote}
					autocomplete="off"
					required
				/>
			</div>
		{/if}

		<div class="field">
			<label for="shift_code">Turno</label>
			<select id="shift_code" name="shift_code" bind:value={shiftCode} required>
				<option value="" disabled>Selecciona un turno</option>
				{#each SHIFTS as value (value)}
					<option {value}>{shiftLabels[value]}</option>
				{/each}
			</select>
		</div>

		<button type="submit" class="submit">AGREGAR PRODUCCIÓN ADICIONAL</button>
	</form>

	<p class="back"><a href={resolve('/production')}>Volver a producción de hoy</a></p>
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

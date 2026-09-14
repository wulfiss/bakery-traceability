<script lang="ts">
	import { resolve } from '$app/paths';
	import type { ActionData, PageData } from './$types';

	let { data, form }: { data: PageData; form: ActionData } = $props();

	const statusLabels: Record<string, string> = {
		pending: 'PENDIENTE',
		in_production: 'EN PRODUCCIÓN',
		completed: 'COMPLETADO',
		cancelled: 'CANCELADO'
	};
	const shiftLabels: Record<string, string> = {
		morning: 'MAÑANA',
		afternoon: 'TARDE',
		night: 'NOCHE'
	};

	const seed = form?.values;
	let productId = $state(seed?.productId ?? '');
	let quantity = $state(seed?.quantity ?? '');
	let unit = $state(seed?.unit ?? '');
	let shiftCode = $state(seed?.shiftCode ?? '');
	let notes = $state(seed?.notes ?? '');

	// AK3 shift behavior: when a product is selected, preselect its current
	// default production shift (and unit). This only affects the empty form;
	// stored items are always rendered from the database and their shift is
	// never recalculated from a later product default. Supervisor/admin may
	// still override the preselected shift before submitting.
	function onProductChange() {
		const product = data.products.find((p) => p.id === productId);
		if (!product) {
			shiftCode = '';
			unit = '';
			return;
		}
		shiftCode = product.defaultShiftCode;
		unit = product.defaultUnit;
	}
</script>

<main class="page">
	{#if data.order === null}
		<p class="empty">El pedido no existe.</p>
		<a class="back" href={resolve('/admin/external-orders')}>Volver a pedidos</a>
	{:else}
		<a class="back" href={resolve('/admin/external-orders')}>Volver a pedidos</a>
		<h1>N° {data.order.orderNumber}</h1>
		<p class="meta">{data.order.customerName}</p>
		<p class="meta muted">
			Fecha requerida: {data.order.requestedDate} · {statusLabels[data.order.status]}
		</p>

		<h2>Productos</h2>
		{#if data.items.length === 0}
			<p class="empty">Sin productos.</p>
		{:else}
			<ul class="items">
				{#each data.items as item (item.id)}
					<li class="item">
						<span class="item-info">
							<span class="product">{item.productName}</span>
							<span class="detail">{item.quantity} {item.unit} · {shiftLabels[item.shiftCode]}</span
							>
							{#if item.notes}
								<span class="detail muted">{item.notes}</span>
							{/if}
						</span>
					</li>
				{/each}
			</ul>
		{/if}

		<h2>Agregar producto</h2>

		{#if form?.error}
			<p class="error" role="alert">{form.error}</p>
		{/if}

		<form
			method="POST"
			action={resolve(`/admin/external-orders/${data.order.id}?/add_item`)}
			class="item-form"
		>
			<label for="product_id">Producto</label>
			<select
				id="product_id"
				name="product_id"
				bind:value={productId}
				onchange={onProductChange}
				required
			>
				<option value="" disabled>Seleccionar…</option>
				{#each data.products as product (product.id)}
					<option value={product.id}>{product.name}</option>
				{/each}
			</select>

			<label for="quantity">Cantidad</label>
			<input
				type="number"
				id="quantity"
				name="quantity"
				bind:value={quantity}
				min="1"
				step="1"
				required
			/>

			<label for="unit">Unidad</label>
			<input type="text" id="unit" name="unit" bind:value={unit} required />

			<label for="shift_code">Turno de producción</label>
			<select id="shift_code" name="shift_code" bind:value={shiftCode} required>
				<option value="" disabled>Seleccionar…</option>
				<option value="morning">MAÑANA</option>
				<option value="night">NOCHE</option>
			</select>

			<label for="notes">Observaciones (opcional)</label>
			<input type="text" id="notes" name="notes" bind:value={notes} />

			<button type="submit" class="submit-btn">AGREGAR PRODUCTO</button>
		</form>
	{/if}
</main>

<style>
	.page {
		display: block;
		width: 100%;
		max-width: var(--content-max);
		margin: 0 auto;
	}

	.back {
		display: inline-block;
		margin-bottom: 12px;
		font-size: 0.9rem;
		font-weight: 700;
		color: var(--color-primary);
		text-decoration: none;
	}

	.meta {
		font-size: 0.95rem;
	}

	.muted {
		color: var(--color-text-muted);
	}

	.empty {
		color: var(--color-text-muted);
	}

	.error {
		color: var(--color-danger);
		font-weight: 700;
	}

	.items {
		list-style: none;
		margin: 0 0 20px;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.item {
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		padding: 12px 14px;
	}

	.item-info {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.product {
		font-weight: 700;
	}

	.detail {
		font-size: 0.9rem;
	}

	.item-form {
		display: flex;
		flex-direction: column;
	}

	.submit-btn {
		margin-top: 8px;
	}
</style>

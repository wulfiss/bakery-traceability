<script lang="ts">
	import { resolve } from '$app/paths';
	import type { ActionData, PageData } from './$types';

	let { data, form }: { data: PageData; form: ActionData } = $props();

	// After a failed action the server passes the submitted values back:
	// - create failures carry { weekday, shift, productId, quantity, unit };
	// - update failures carry those plus { id } and the edit form of that card
	//   reopens with the submitted values.
	const seed = form?.values;
	const editSeed = seed && 'id' in seed ? seed : undefined;
	const createSeed = seed && !('id' in seed) ? seed : undefined;

	// Client-side toggle for the per-card edit form (open by default after a
	// failed update of that card, as shown above).
	let editingId = $state<string | null>(null);

	const WEEKDAYS = [1, 2, 3, 4, 5, 6, 7];
	const weekdayLabels: Record<number, string> = {
		1: 'LUNES',
		2: 'MARTES',
		3: 'MIÉRCOLES',
		4: 'JUEVES',
		5: 'VIERNES',
		6: 'SÁBADO',
		7: 'DOMINGO'
	};
	const shiftLabels: Record<string, string> = {
		morning: 'MAÑANA',
		afternoon: 'TARDE',
		night: 'NOCHE'
	};

	function openEdit(id: string) {
		editingId = id;
	}

	function closeEdit() {
		editingId = null;
	}
</script>

<main class="page">
	<a class="back" href={resolve('/admin')}>Volver a administración</a>
	<h1>Planificación</h1>

	{#if form?.error}
		<p class="error" role="alert">{form.error}</p>
	{/if}

	{#if data.planItems.length === 0}
		<p class="empty">Sin ítems de planificación.</p>
	{:else}
		<ul class="list">
			{#each data.planItems as item (item.id)}
				{@const editFormOpen =
					editingId === item.id || (editSeed !== undefined && editSeed.id === item.id)}
				{@const isEdited = editSeed !== undefined && editSeed.id === item.id}
				{@const editWeekday = isEdited ? editSeed.weekday : String(item.weekday)}
				{@const editShift = isEdited ? editSeed.shift : item.shiftCode}
				{@const editProduct = isEdited ? editSeed.productId : item.productId}
				{@const editQuantity = isEdited ? editSeed.quantity : item.plannedQuantity}
				{@const editUnit = isEdited ? editSeed.unit : item.unit}
				<li class="card">
					<span class="card-info">
						<span class="name">
							{item.productName}
							{#if !item.active}<span class="badge">INACTIVO</span>{/if}
						</span>
						<span class="detail">
							{weekdayLabels[item.weekday]} · {shiftLabels[item.shiftCode]} ·
							{item.plannedQuantity}
							{item.unit}
						</span>
					</span>

					{#if editFormOpen}
						<form method="POST" action={resolve('/admin/planning?/update')} class="edit-form">
							<input type="hidden" name="id" value={item.id} />
							<label for="weekday-{item.id}">Día</label>
							<select name="weekday" id="weekday-{item.id}" value={editWeekday}>
								{#each WEEKDAYS as weekday (weekday)}
									<option value={String(weekday)}>{weekdayLabels[weekday]}</option>
								{/each}
							</select>
							<label for="shift-{item.id}">Turno</label>
							<select name="shift" id="shift-{item.id}" value={editShift}>
								<option value="morning">MAÑANA</option>
								<option value="night">NOCHE</option>
							</select>
							<label for="product-{item.id}">Producto</label>
							<select name="productId" id="product-{item.id}" value={editProduct}>
								{#each data.products as product (product.id)}
									<option value={product.id}>{product.name}</option>
								{/each}
							</select>
							<label for="quantity-{item.id}">Cantidad</label>
							<input
								type="number"
								id="quantity-{item.id}"
								name="quantity"
								value={editQuantity}
								min="0"
								step="any"
								required
							/>
							<label for="unit-{item.id}">Unidad</label>
							<input type="text" id="unit-{item.id}" name="unit" value={editUnit} required />
							<div class="actions">
								<button type="submit">GUARDAR</button>
								<button type="button" class="secondary" onclick={() => closeEdit()}>
									CANCELAR
								</button>
							</div>
						</form>
					{:else}
						<div class="actions">
							<button type="button" class="secondary" onclick={() => openEdit(item.id)}>
								EDITAR
							</button>
							<form
								method="POST"
								action={resolve('/admin/planning?/set_active')}
								class="inline-form"
							>
								<input type="hidden" name="id" value={item.id} />
								<input type="hidden" name="active" value={item.active ? 'false' : 'true'} />
								<button type="submit" class="secondary">
									{item.active ? 'DESACTIVAR' : 'ACTIVAR'}
								</button>
							</form>
						</div>
					{/if}
				</li>
			{/each}
		</ul>
	{/if}

	<h2>Nuevo ítem de planificación</h2>

	<form method="POST" action={resolve('/admin/planning?/create')} class="create-form">
		<label for="new-weekday">Día</label>
		<select name="weekday" id="new-weekday" value={createSeed?.weekday ?? '1'}>
			{#each WEEKDAYS as weekday (weekday)}
				<option value={String(weekday)}>{weekdayLabels[weekday]}</option>
			{/each}
		</select>
		<label for="new-shift">Turno</label>
		<select name="shift" id="new-shift" value={createSeed?.shift ?? 'morning'}>
			<option value="morning">MAÑANA</option>
			<option value="night">NOCHE</option>
		</select>
		<label for="new-product">Producto</label>
		<select
			name="productId"
			id="new-product"
			value={createSeed?.productId ?? data.products[0]?.id ?? ''}
		>
			{#each data.products as product (product.id)}
				<option value={product.id}>{product.name}</option>
			{/each}
		</select>
		<label for="new-quantity">Cantidad</label>
		<input
			type="number"
			id="new-quantity"
			name="quantity"
			value={createSeed?.quantity ?? ''}
			min="0"
			step="any"
			required
		/>
		<label for="new-unit">Unidad</label>
		<input type="text" id="new-unit" name="unit" value={createSeed?.unit ?? ''} required />

		<button type="submit">CREAR</button>
	</form>
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

	.error {
		color: var(--color-danger);
		font-weight: 700;
	}

	.empty {
		color: var(--color-text-muted);
	}

	.list {
		list-style: none;
		margin: 0 0 20px;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.card {
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		padding: 12px 14px;
		display: flex;
		flex-direction: column;
		gap: 10px;
	}

	.card-info {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.name {
		font-weight: 700;
	}

	.detail {
		color: var(--color-text-muted);
		font-size: 0.9rem;
	}

	.badge {
		display: inline-block;
		margin-left: 8px;
		padding: 2px 8px;
		border-radius: 999px;
		background: var(--color-danger);
		color: #fff;
		font-size: 0.75rem;
		font-weight: 700;
		vertical-align: middle;
	}

	.actions {
		display: flex;
		gap: 8px;
	}

	.actions button {
		flex: 1;
		min-height: var(--touch-min);
	}

	.inline-form {
		flex: 1;
		display: flex;
	}

	.edit-form,
	.create-form {
		display: flex;
		flex-direction: column;
	}

	.edit-form select,
	.create-form select,
	.edit-form input,
	.create-form input {
		min-height: var(--touch-min);
		padding: 8px 10px;
		margin-bottom: 8px;
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		background: var(--color-surface);
	}

	.create-form button[type='submit'] {
		margin-top: 8px;
	}
</style>

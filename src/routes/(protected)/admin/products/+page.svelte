<script lang="ts">
	import { resolve } from '$app/paths';
	import type { ActionData, PageData } from './$types';

	let { data, form }: { data: PageData; form: ActionData } = $props();

	const shiftLabels: Record<string, string> = {
		morning: 'MAÑANA',
		afternoon: 'TARDE',
		night: 'NOCHE'
	};

	// After a failed action the server passes the submitted values back:
	// - create failures carry { name, unit, shift };
	// - update failures carry { id, name, unit, shift } and the edit form of
	//   that card reopens with the submitted values.
	const seed = form?.values;
	const editSeed = seed && 'id' in seed ? seed : undefined;
	const createSeed = seed && !('id' in seed) ? seed : undefined;

	// Client-side toggle for the per-card edit form (open by default after a
	// failed update of that card, as shown above).
	let editingId = $state<string | null>(null);

	function openEdit(id: string) {
		editingId = id;
	}

	function closeEdit() {
		editingId = null;
	}
</script>

<main class="page">
	<a class="back" href={resolve('/admin')}>Volver a administración</a>
	<h1>Productos</h1>

	{#if form?.error}
		<p class="error" role="alert">{form.error}</p>
	{/if}

	{#if data.products.length === 0}
		<p class="empty">Sin productos.</p>
	{:else}
		<ul class="list">
			{#each data.products as product (product.id)}
				{@const editFormOpen =
					editingId === product.id || (editSeed !== undefined && editSeed.id === product.id)}
				{@const editName =
					editSeed !== undefined && editSeed.id === product.id ? editSeed.name : product.name}
				{@const editUnit =
					editSeed !== undefined && editSeed.id === product.id
						? editSeed.unit
						: product.defaultUnit}
				{@const editShift =
					editSeed !== undefined && editSeed.id === product.id
						? editSeed.shift
						: product.defaultShiftCode}
				<li class="card">
					<span class="card-info">
						<span class="name">
							{product.name}
							{#if !product.active}<span class="badge">INACTIVO</span>{/if}
						</span>
						<span class="detail">
							{product.defaultUnit} · {shiftLabels[product.defaultShiftCode]}
						</span>
					</span>

					{#if editFormOpen}
						<form method="POST" action={resolve('/admin/products?/update')} class="edit-form">
							<input type="hidden" name="id" value={product.id} />
							<label for="name-{product.id}">Nombre</label>
							<input type="text" id="name-{product.id}" name="name" value={editName} required />
							<label for="unit-{product.id}">Unidad</label>
							<input type="text" id="unit-{product.id}" name="unit" value={editUnit} required />
							<label for="shift-{product.id}">Turno por defecto</label>
							<select id="shift-{product.id}" name="shift" value={editShift}>
								<option value="morning">MAÑANA</option>
								<option value="afternoon">TARDE</option>
								<option value="night">NOCHE</option>
							</select>
							<div class="actions">
								<button type="submit">GUARDAR</button>
								<button type="button" class="secondary" onclick={() => closeEdit()}>
									CANCELAR
								</button>
							</div>
						</form>
					{:else}
						<div class="actions">
							<button type="button" class="secondary" onclick={() => openEdit(product.id)}>
								EDITAR
							</button>
							<form
								method="POST"
								action={resolve('/admin/products?/set_active')}
								class="inline-form"
							>
								<input type="hidden" name="id" value={product.id} />
								<input type="hidden" name="active" value={product.active ? 'false' : 'true'} />
								<button type="submit" class="secondary">
									{product.active ? 'DESACTIVAR' : 'ACTIVAR'}
								</button>
							</form>
						</div>
					{/if}
				</li>
			{/each}
		</ul>
	{/if}

	<h2>Nuevo producto</h2>

	<form method="POST" action={resolve('/admin/products?/create')} class="create-form">
		<label for="new-name">Nombre</label>
		<input type="text" id="new-name" name="name" value={createSeed?.name ?? ''} required />

		<label for="new-unit">Unidad</label>
		<input type="text" id="new-unit" name="unit" value={createSeed?.unit ?? ''} required />

		<label for="new-shift">Turno por defecto</label>
		<select id="new-shift" name="shift" value={createSeed?.shift ?? 'morning'}>
			<option value="morning">MAÑANA</option>
			<option value="afternoon">TARDE</option>
			<option value="night">NOCHE</option>
		</select>

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

	.detail {
		font-size: 0.9rem;
		color: var(--color-text-muted);
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

	.create-form button[type='submit'] {
		margin-top: 8px;
	}
</style>

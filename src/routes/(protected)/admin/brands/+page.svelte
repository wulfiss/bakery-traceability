<script lang="ts">
	import { resolve } from '$app/paths';
	import type { ActionData, PageData } from './$types';

	let { data, form }: { data: PageData; form: ActionData } = $props();

	// After a failed action the server passes the submitted values back:
	// - create failures carry { name };
	// - update failures carry { id, name } and the edit form of that card
	//   reopens with the submitted values.
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
	<h1>Marcas</h1>

	{#if form?.error}
		<p class="error" role="alert">{form.error}</p>
	{/if}

	{#if data.brands.length === 0}
		<p class="empty">Sin marcas.</p>
	{:else}
		<ul class="list">
			{#each data.brands as brand (brand.id)}
				{@const editFormOpen =
					editingId === brand.id || (editSeed !== undefined && editSeed.id === brand.id)}
				{@const editName =
					editSeed !== undefined && editSeed.id === brand.id ? editSeed.name : brand.name}
				<li class="card">
					<span class="card-info">
						<span class="name">
							{brand.name}
							{#if !brand.active}<span class="badge">INACTIVO</span>{/if}
						</span>
					</span>

					{#if editFormOpen}
						<form method="POST" action={resolve('/admin/brands?/update')} class="edit-form">
							<input type="hidden" name="id" value={brand.id} />
							<label for="name-{brand.id}">Nombre</label>
							<input type="text" id="name-{brand.id}" name="name" value={editName} required />
							<div class="actions">
								<button type="submit">GUARDAR</button>
								<button type="button" class="secondary" onclick={() => closeEdit()}>
									CANCELAR
								</button>
							</div>
						</form>
					{:else}
						<div class="actions">
							<button type="button" class="secondary" onclick={() => openEdit(brand.id)}>
								EDITAR
							</button>
							<form method="POST" action={resolve('/admin/brands?/set_active')} class="inline-form">
								<input type="hidden" name="id" value={brand.id} />
								<input type="hidden" name="active" value={brand.active ? 'false' : 'true'} />
								<button type="submit" class="secondary">
									{brand.active ? 'DESACTIVAR' : 'ACTIVAR'}
								</button>
							</form>
						</div>
					{/if}
				</li>
			{/each}
		</ul>
	{/if}

	<h2>Nueva marca</h2>

	<form method="POST" action={resolve('/admin/brands?/create')} class="create-form">
		<label for="new-name">Nombre</label>
		<input type="text" id="new-name" name="name" value={createSeed?.name ?? ''} required />

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

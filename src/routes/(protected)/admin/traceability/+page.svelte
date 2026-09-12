<script lang="ts">
	import { resolve } from '$app/paths';
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();
</script>

<main class="page">
	<h1>Trazabilidad</h1>

	<form method="GET" action={resolve('/admin/traceability')} class="search">
		<input
			type="text"
			name="code"
			class="code-input"
			placeholder="PAN-100926-M-004"
			value={data.searchedCode}
			required
		/>
		<button type="submit" class="search-btn">BUSCAR</button>
	</form>

	{#if data.error}
		<p class="error">{data.error}</p>
	{:else if data.batch}
		<div class="result">
			<ul class="products">
				{#each data.batch.products as product (product.productId)}
					<li class="product">
						<span class="product-name">{product.productName}</span>
						<span class="product-qty">{product.quantity} {product.unit}</span>
					</li>
				{/each}
			</ul>
			<p class="batch-code">{data.batch.batchCode}</p>

			<div class="meta">
				<p class="meta-row">
					<span class="meta-label">Fecha</span>
					<span>{data.batch.dateLabel}</span>
				</p>
				<p class="meta-row">
					<span class="meta-label">Turno</span>
					<span>{data.batch.shiftLabel}</span>
				</p>
			</div>

			<section class="materials">
				<h3>Materias primas</h3>
				{#if data.batch.materials.length === 0}
					<p class="empty">Sin materias primas registradas.</p>
				{:else}
					<ul class="material-list">
						{#each data.batch.materials as material (material.rawMaterialName + material.supplierLot)}
							<li class="material">
								<span class="material-name">{material.rawMaterialName}</span>
								<span class="material-brand">{material.brandName}</span>
								<span class="material-lot">{material.supplierLot}</span>
							</li>
						{/each}
					</ul>
				{/if}
			</section>
		</div>
	{:else}
		<p class="prompt">Ingresá el código del lote para ver sus materias primas.</p>
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

	.search {
		display: flex;
		gap: 8px;
		margin-bottom: 16px;
	}

	.code-input {
		flex: 1;
		min-height: var(--touch-min);
		padding: 8px 12px;
		font-size: 1rem;
		color: var(--color-text);
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
	}

	.search-btn {
		min-height: var(--touch-min);
		padding: 8px 16px;
		font-size: 0.95rem;
		font-weight: 700;
		letter-spacing: 0.03em;
		color: var(--color-on-primary);
		background: var(--color-primary);
		border: none;
		border-radius: var(--radius);
		cursor: pointer;
	}

	.prompt {
		font-size: 1rem;
		color: var(--color-text-muted);
		margin: 0;
	}

	.error {
		font-size: 1rem;
		color: var(--color-danger);
		margin: 0;
	}

	.result {
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		padding: 16px;
	}

	.products {
		list-style: none;
		margin: 0 0 4px;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.product {
		display: flex;
		align-items: baseline;
		gap: 8px;
	}

	.product-name {
		font-size: 1.1rem;
		font-weight: 700;
	}

	.product-qty {
		font-size: 0.9rem;
		color: var(--color-text-muted);
	}

	.batch-code {
		margin: 0 0 12px;
		font-size: 1rem;
		font-weight: 700;
		letter-spacing: 0.02em;
	}

	.meta {
		border-top: 1px solid var(--color-border);
		padding-top: 12px;
		margin-bottom: 16px;
	}

	.meta-row {
		display: flex;
		justify-content: space-between;
		gap: 8px;
		margin: 4px 0;
		font-size: 0.95rem;
	}

	.meta-label {
		color: var(--color-text-muted);
	}

	.materials h3 {
		font-size: 0.95rem;
		margin: 0 0 8px;
	}

	.empty {
		font-size: 0.9rem;
		color: var(--color-text-muted);
		margin: 0;
	}

	.material-list {
		list-style: none;
		margin: 0;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.material {
		display: flex;
		flex-direction: column;
		padding: 10px 12px;
		background: var(--color-bg);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
	}

	.material-name {
		font-size: 1rem;
		font-weight: 700;
	}

	.material-brand {
		font-size: 0.9rem;
		color: var(--color-text-muted);
	}

	.material-lot {
		font-size: 0.9rem;
		font-weight: 700;
	}
</style>

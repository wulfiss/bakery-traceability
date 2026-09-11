<script lang="ts">
	import { enhance } from '$app/forms';
	import { resolve } from '$app/paths';
	import { preventDoubleSubmit } from '$lib/forms';
	import type { ActionData, PageData } from './$types';

	let { data, form }: { data: PageData; form: ActionData } = $props();

	const shiftLabels: Record<string, string> = {
		morning: 'MAÑANA',
		afternoon: 'TARDE',
		night: 'NOCHE'
	};
</script>

<main class="page">
	{#if data.shift === null}
		<h1>Producción</h1>
		<p class="prompt">Seleccioná el turno</p>
		<form method="POST" action={resolve('/production?/select')} class="shifts">
			<button type="submit" name="shift" value="morning" class="shift-btn">MAÑANA</button>
			<button type="submit" name="shift" value="afternoon" class="shift-btn">TARDE</button>
			<button type="submit" name="shift" value="night" class="shift-btn">NOCHE</button>
		</form>
	{:else}
		<h1>Producción de hoy</h1>

		{#if form?.error}
			<div class="error" role="alert">
				<p>{form.error}</p>
				{#if form.missingLots && form.missingLots.length > 0}
					<p class="error-sub">Falta lote activo:</p>
					<ul>
						{#each form.missingLots as name (name)}
							<li>- {name}</li>
						{/each}
					</ul>
				{/if}
			</div>
		{/if}

		<div class="shift-line">
			<span>Turno: {shiftLabels[data.shift]}</span>
			<form method="POST" action={resolve('/production?/change')}>
				<button type="submit" class="change-shift">Cambiar turno</button>
			</form>
		</div>

		<section class="section">
			<h2>Producción base</h2>
			{#if data.base.length === 0}
				<p class="empty">Sin producción base para este turno.</p>
			{:else}
				<ul class="items">
					{#each data.base as item (item.id)}
						<li class="item">
							<span class="item-info">
								<span class="product">{item.productName}</span>
								<span class="qty">{item.quantity} {item.unit}</span>
							</span>
							{#if item.status === 'pending'}
								<form
									method="POST"
									action={resolve('/production?/start')}
									use:enhance={preventDoubleSubmit}
								>
									<input type="hidden" name="request_id" value={item.id} />
									<button type="submit" class="start-btn">INICIAR</button>
								</form>
							{/if}
						</li>
					{/each}
				</ul>
			{/if}
		</section>

		<section class="section">
			<h2>Pedidos externos</h2>
			{#if data.external.length === 0}
				<p class="empty">Sin pedidos externos para este turno.</p>
			{:else}
				<ul class="items">
					{#each data.external as item (item.id)}
						<li class="item">
							<span class="item-info">
								<span class="product">{item.productName}</span>
								<span class="qty">{item.quantity} {item.unit}</span>
							</span>
							{#if item.status === 'pending'}
								<form
									method="POST"
									action={resolve('/production?/start')}
									use:enhance={preventDoubleSubmit}
								>
									<input type="hidden" name="request_id" value={item.id} />
									<button type="submit" class="start-btn">INICIAR</button>
								</form>
							{/if}
						</li>
					{/each}
				</ul>
			{/if}
		</section>

		<section class="section">
			<h2>Producción adicional</h2>
			{#if data.additional.length === 0}
				<p class="empty">Sin producción adicional para este turno.</p>
			{:else}
				<ul class="items">
					{#each data.additional as item (item.id)}
						<li class="item">
							<span class="item-info">
								<span class="product">{item.productName}</span>
								<span class="qty">{item.quantity} {item.unit}</span>
							</span>
							{#if item.status === 'pending'}
								<form
									method="POST"
									action={resolve('/production?/start')}
									use:enhance={preventDoubleSubmit}
								>
									<input type="hidden" name="request_id" value={item.id} />
									<button type="submit" class="start-btn">INICIAR</button>
								</form>
							{/if}
						</li>
					{/each}
				</ul>
			{/if}
			<a class="add-button" href={resolve('/production/additional')}>Agregar producción adicional</a
			>
		</section>
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

	.prompt {
		font-size: 1rem;
		color: var(--color-text-muted);
		margin: 0 0 16px;
	}

	.shifts {
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.shift-btn {
		display: block;
		width: 100%;
		min-height: calc(var(--touch-min) + 20px);
		padding: 16px;
		font-size: 1.15rem;
		font-weight: 700;
		letter-spacing: 0.04em;
		color: var(--color-on-primary);
		background: var(--color-primary);
		border: none;
		border-radius: var(--radius);
		cursor: pointer;
	}

	.shift-line {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 8px;
		margin-bottom: 20px;
	}

	.shift-line span {
		font-weight: 700;
	}

	.change-shift {
		display: inline-block;
		min-height: var(--touch-min);
		padding: 8px 14px;
		font-size: 0.95rem;
		color: var(--color-primary);
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		cursor: pointer;
	}

	.section {
		margin-bottom: 20px;
	}

	h2 {
		font-size: 1.0625rem;
		margin: 0 0 8px;
	}

	.items {
		list-style: none;
		margin: 0;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.item {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 8px;
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		padding: 12px 14px;
	}

	.item-info {
		display: flex;
		flex-direction: column;
		gap: 2px;
		flex: 1;
		min-width: 0;
	}

	.start-btn {
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

	.error {
		color: var(--color-danger);
		background: var(--color-surface);
		border: 1px solid var(--color-danger);
		border-radius: var(--radius);
		padding: 12px 14px;
		margin: 0 0 16px;
		font-size: 0.95rem;
	}

	.error p {
		margin: 0 0 4px;
		font-weight: 700;
	}

	.error-sub {
		font-weight: 700;
		margin-bottom: 2px;
	}

	.error ul {
		margin: 0;
		padding-left: 18px;
	}

	.product {
		font-size: 0.95rem;
	}

	.qty {
		font-size: 0.9375rem;
		color: var(--color-text-muted);
		white-space: nowrap;
	}

	.empty {
		margin: 0;
		color: var(--color-text-muted);
		font-size: 0.9375rem;
	}

	.add-button {
		display: block;
		width: 100%;
		min-height: var(--touch-min);
		margin-top: 10px;
		padding: 10px 12px;
		font-size: 1rem;
		font-weight: 700;
		text-align: center;
		text-decoration: none;
		color: var(--color-on-primary);
		background: var(--color-primary);
		border-radius: var(--radius);
	}
</style>

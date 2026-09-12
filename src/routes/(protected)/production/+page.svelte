<script lang="ts">
	import { enhance } from '$app/forms';
	import { resolve } from '$app/paths';
	import { preventDoubleSubmit } from '$lib/forms';
	import type { ActionData, PageData } from './$types';
	import type { RequestItem } from './+page.server';

	let { data, form }: { data: PageData; form: ActionData } = $props();

	// AP2: selected source lot per (request, source product) pair. The key is
	// "<requestId>:<sourceProductId>" and the value the chosen parent output.
	const selectedLots = $state<Record<string, string>>({});

	const shiftLabels: Record<string, string> = {
		morning: 'MAÑANA',
		afternoon: 'TARDE',
		night: 'NOCHE'
	};

	// AN1: Spanish label for one source contribution inside a product group.
	function contributionLabel(item: RequestItem): string {
		if (item.sourceType === 'base') return 'Producción base';
		if (item.sourceType === 'external_order') {
			return item.orderNumber ? `Pedido ${item.orderNumber}` : 'Pedido externo';
		}
		return 'Producción adicional';
	}
</script>

<main class="page">
	{#if data.shift === null}
		<h1>Producción de hoy</h1>
		<p class="prompt">Elegí el turno que estás trabajando.</p>
		<div class="shifts">
			{#each ['morning', 'afternoon', 'night'] as shift (shift)}
				<form
					method="POST"
					action={resolve('/production?/select')}
					use:enhance={preventDoubleSubmit}
				>
					<input type="hidden" name="shift" value={shift} />
					<button type="submit" class="shift-btn">{shiftLabels[shift]}</button>
				</form>
			{/each}
		</div>
	{:else}
		<h1>Producción de hoy</h1>

		{#if form?.error}
			<div class="error" role="alert">
				<p>{form.error}</p>
				{#if form.missingLots && form.missingLots.length > 0}
					<p class="error-sub">Faltan lotes de materia prima:</p>
					<ul>
						{#each form.missingLots as lot (lot)}
							<li>{lot}</li>
						{/each}
					</ul>
				{/if}
			</div>
		{/if}

		<div class="shift-line">
			<span>Turno: {shiftLabels[data.shift]}</span>
			<form method="POST" action={resolve('/production?/change')} use:enhance={preventDoubleSubmit}>
				<button type="submit" class="change-shift">Cambiar turno</button>
			</form>
		</div>

		<p class="progress">{data.progress.completed} / {data.progress.total} completadas</p>

		{#if data.groups.length === 0}
			<p class="empty">Sin producciones para este turno.</p>
		{:else}
			<ul class="groups">
				{#each data.groups as group (group.productId)}
					<li class="group">
						<h2 class="group-name">{group.productName}</h2>
						<ul class="contributions">
							{#each group.items as item (item.id)}
								<li class="contribution">
									<span class="contribution-label">{contributionLabel(item)}</span>
									<span class="qty">{item.quantity} {item.unit}</span>
									{#if item.status === 'pending'}
										{#if group.productInputs.length === 0}
											<form
												method="POST"
												action={resolve('/production?/start')}
												use:enhance={preventDoubleSubmit}
											>
												<input type="hidden" name="request_id" value={item.id} />
												<button type="submit" class="start-btn">INICIAR</button>
											</form>
										{:else}
											<form
												method="POST"
												class="start-form"
												action={resolve('/production?/start')}
												use:enhance={preventDoubleSubmit}
											>
												<input type="hidden" name="request_id" value={item.id} />
												<div class="source-inputs">
													{#each group.productInputs as input (input.sourceProductId)}
														<div class="source-block">
															<p class="source-title">Producto de origen</p>
															<p class="source-name">{input.sourceProductName}</p>
															{#if input.options.length === 0}
																<p class="source-empty">Sin lotes disponibles.</p>
															{:else}
																<ul class="lots">
																	{#each input.options as option (option.outputId)}
																		<li class="lot">
																			<label class="lot-label">
																				<input
																					type="radio"
																					class="lot-radio"
																					name={`lot_${item.id}_${input.sourceProductId}`}
																					value={option.outputId}
																					bind:group={
																						selectedLots[`${item.id}:${input.sourceProductId}`]
																					}
																					required
																				/>
																				<span class="lot-info">
																					<span class="lot-code">{option.batchCode}</span>
																					<span class="lot-detail"
																						>{option.quantity}
																						{option.unit}{option.dateLabel
																							? ` · ${option.dateLabel}`
																							: ''}</span
																					>
																				</span>
																			</label>
																			{#if selectedLots[`${item.id}:${input.sourceProductId}`] === option.outputId}
																				<span class="lot-badge">USAR ESTE LOTE</span>
																			{/if}
																		</li>
																	{/each}
																</ul>
															{/if}
														</div>
													{/each}
													<button
														type="submit"
														class="start-btn"
														disabled={group.productInputs.some(
															(input) => input.options.length === 0
														)}
													>
														INICIAR
													</button>
												</div>
											</form>
										{/if}
									{/if}
								</li>
							{/each}
						</ul>
						{#if group.total !== null}
							<p class="group-total">
								<span>TOTAL</span>
								<span>{group.total}{group.totalUnit ? ` ${group.totalUnit}` : ''}</span>
							</p>
						{/if}
					</li>
				{/each}
			</ul>
		{/if}

		<a class="add-button" href={resolve('/production/additional')}>Agregar producción adicional</a>
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
		margin-bottom: 8px;
	}

	.shift-line span {
		font-weight: 700;
	}

	.progress {
		margin: 0 0 20px;
		font-size: 0.95rem;
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

	.groups {
		list-style: none;
		margin: 0 0 20px;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.group {
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		padding: 12px 14px;
	}

	.group-name {
		font-size: 1.0625rem;
		margin: 0 0 8px;
	}

	.contributions {
		list-style: none;
		margin: 0;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.contribution {
		display: flex;
		align-items: center;
		flex-wrap: wrap;
		gap: 8px;
	}

	.contribution-label {
		flex: 1;
		min-width: 0;
		font-size: 0.9rem;
		color: var(--color-text-muted);
	}

	.group-total {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 8px;
		margin: 10px 0 0;
		padding-top: 8px;
		border-top: 1px solid var(--color-border);
		font-size: 0.95rem;
		font-weight: 700;
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

	.start-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	/* AP2: source-lot selection form (wraps below the contribution line). */
	.start-form {
		display: flex;
		flex-direction: column;
		flex: 1 0 100%;
		gap: 10px;
		margin-top: 6px;
	}

	.source-inputs {
		display: flex;
		flex-direction: column;
		gap: 10px;
	}

	.source-block {
		background: var(--color-bg);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		padding: 10px 12px;
	}

	.source-title {
		margin: 0 0 2px;
		font-size: 0.85rem;
		font-weight: 700;
		color: var(--color-text-muted);
	}

	.source-name {
		margin: 0 0 8px;
		font-size: 1rem;
		font-weight: 700;
	}

	.source-empty {
		margin: 0;
		font-size: 0.9rem;
		color: var(--color-danger);
	}

	.lots {
		list-style: none;
		margin: 0;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.lot {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.lot-label {
		display: flex;
		align-items: center;
		gap: 10px;
		min-height: var(--touch-min);
		padding: 6px 10px;
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		cursor: pointer;
	}

	.lot-radio {
		flex-shrink: 0;
		width: 20px;
		height: 20px;
		accent-color: var(--color-primary);
	}

	.lot-info {
		display: flex;
		flex-direction: column;
		min-width: 0;
	}

	.lot-code {
		font-size: 0.95rem;
		font-weight: 700;
	}

	.lot-detail {
		font-size: 0.85rem;
		color: var(--color-text-muted);
	}

	.lot-badge {
		align-self: flex-start;
		margin-left: 30px;
		padding: 3px 8px;
		font-size: 0.75rem;
		font-weight: 700;
		letter-spacing: 0.06em;
		color: var(--color-on-primary);
		background: var(--color-primary);
		border-radius: var(--radius);
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

	.qty {
		font-size: 0.9375rem;
		color: var(--color-text-muted);
		white-space: nowrap;
	}

	.empty {
		margin: 0 0 20px;
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

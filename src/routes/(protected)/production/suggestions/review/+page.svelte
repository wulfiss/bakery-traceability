<script lang="ts">
	import { enhance } from '$app/forms';
	import { resolve } from '$app/paths';
	import AdminReturnLink from '$lib/components/AdminReturnLink.svelte';
	import { preventDoubleSubmit } from '$lib/forms';
	import type { ActionData, PageData } from './$types';
	import type { ReviewLine } from './+page.server';

	let { data, form }: { data: PageData; form: ActionData } = $props();

	const f = $derived((form ?? {}) as { error?: string | null });

	function formatDate(value: string): string {
		const parts = value.split('-');
		if (parts.length !== 3) return value;
		return `${parts[2]}/${parts[1]}/${parts[0]}`;
	}

	// Spanish decimal separator for quantities (0.5 -> 0,5).
	function formatQty(quantity: number): string {
		return quantity.toString().replace('.', ',');
	}

	function lineText(line: ReviewLine): string {
		return `${line.productName} — ${formatQty(line.quantity)} ${line.unit}`;
	}

	// V6.10: the checkbox applies the change immediately — a tap submits the
	// row's toggle form (use:enhance: no full reload; on success the page
	// data refreshes, on failure the form resets to the server state).
	function submitToggle(event: Event): void {
		const input = event.currentTarget as HTMLInputElement;
		input.form?.requestSubmit();
	}
</script>

<main class="page">
	<h1>PRODUCCIÓN {data.code}</h1>
	<AdminReturnLink role={data.role} />
	<p class="day-line">
		{data.weekdayLabel} · {formatDate(data.businessDate)}
		{data.status === 'confirmed' ? '· confirmada' : '· borrador'}
	</p>

	{#if f.error}
		<div class="error" role="alert">{f.error}</div>
	{/if}

	{#if data.morning.length === 0 && data.night.length === 0}
		<p class="empty">La selección no tiene productos.</p>
	{/if}

	{#if data.morning.length > 0}
		<section class="shift">
			<h2 class="shift-title">MAÑANA</h2>
			<ul class="lines">
				{#each data.morning as line (line.itemId)}
					<li class="line-item">
						<form
							method="POST"
							action={resolve('/production/suggestions/review?/toggle')}
							use:enhance
						>
							<input type="hidden" name="item_id" value={line.itemId} />
							<label class="line">
								<input
									class="check"
									type="checkbox"
									name="toggle"
									checked={line.isSelected}
									disabled={line.locked}
									onchange={submitToggle}
								/>
								<span class="line-text">{lineText(line)}</span>
								{#if line.locked}<span class="locked">BLOQUEADO</span>{/if}
							</label>
						</form>
					</li>
				{/each}
			</ul>
		</section>
	{/if}

	{#if data.night.length > 0}
		<section class="shift">
			<h2 class="shift-title">NOCHE</h2>
			<ul class="lines">
				{#each data.night as line (line.itemId)}
					<li class="line-item">
						<form
							method="POST"
							action={resolve('/production/suggestions/review?/toggle')}
							use:enhance
						>
							<input type="hidden" name="item_id" value={line.itemId} />
							<label class="line">
								<input
									class="check"
									type="checkbox"
									name="toggle"
									checked={line.isSelected}
									disabled={line.locked}
									onchange={submitToggle}
								/>
								<span class="line-text">{lineText(line)}</span>
								{#if line.locked}<span class="locked">BLOQUEADO</span>{/if}
							</label>
						</form>
					</li>
				{/each}
			</ul>
		</section>
	{/if}

	<form
		method="POST"
		action={resolve('/production/suggestions/review?/confirm')}
		use:enhance={preventDoubleSubmit}
	>
		<button type="submit" class="confirm" disabled={data.status === 'confirmed'}>
			CONFIRMAR PRODUCCIÓN
		</button>
	</form>

	<a class="back" href={resolve('/production/suggestions')}>CAMBIAR SUGERENCIA</a>
	<a class="back" href={resolve('/production')}>IR A PRODUCCIÓN</a>
</main>

<style>
	.page {
		max-width: var(--content-max);
		margin: 0 auto;
		padding: 16px;
	}

	h1 {
		font-size: 1.375rem;
		margin-bottom: 4px;
	}

	.day-line {
		margin: 0 0 16px;
		font-weight: 600;
		letter-spacing: 0.04em;
		color: var(--color-text-muted);
	}

	.error {
		margin: 0 0 16px;
		padding: 10px 12px;
		color: var(--color-danger);
		background: var(--color-surface);
		border: 1px solid var(--color-danger);
		border-radius: var(--radius);
	}

	.empty {
		margin: 8px 0;
		color: var(--color-text-muted);
	}

	.shift {
		margin-bottom: 16px;
		padding: 14px;
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		box-sizing: border-box;
	}

	.shift-title {
		font-size: 0.8125rem;
		font-weight: 700;
		letter-spacing: 0.08em;
		color: var(--color-text-muted);
		margin: 0 0 6px;
	}

	.lines {
		list-style: none;
		margin: 0;
		padding: 0;
	}

	.line-item {
		display: block;
	}

	.line {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 8px 0;
		border-bottom: 1px solid var(--color-border);
		font-size: 0.9375rem;
		cursor: pointer;
	}

	.line-item:last-child .line {
		border-bottom: none;
	}

	.check {
		width: 22px;
		height: 22px;
		flex-shrink: 0;
		margin: 0;
	}

	.check:disabled {
		cursor: not-allowed;
	}

	.line-text {
		flex: 1;
	}

	.locked {
		flex-shrink: 0;
		padding: 2px 6px;
		font-size: 0.6875rem;
		font-weight: 700;
		letter-spacing: 0.08em;
		color: var(--color-text-muted);
		border: 1px solid var(--color-border);
		border-radius: 4px;
		white-space: nowrap;
	}

	.confirm {
		display: block;
		width: 100%;
		margin-top: 8px;
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
		box-sizing: border-box;
	}

	.confirm:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.back {
		display: inline-block;
		margin-right: 16px;
		padding: 10px 0;
		font-size: 0.875rem;
		font-weight: 600;
		letter-spacing: 0.04em;
		color: var(--color-text-muted);
		text-decoration: none;
	}
</style>

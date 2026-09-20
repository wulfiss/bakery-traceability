<script lang="ts">
	import { enhance } from '$app/forms';
	import { resolve } from '$app/paths';
	import AdminReturnLink from '$lib/components/AdminReturnLink.svelte';
	import { preventDoubleSubmit } from '$lib/forms';
	import type { ActionData, PageData } from './$types';
	import type { SuggestionLine, SuggestionView } from './+page.server';

	let { data, form }: { data: PageData; form: ActionData } = $props();

	const f = $derived((form ?? {}) as { error?: string | null });

	// "VER TODOS": per (suggestion, shift) expansion state. The first lines
	// of each group are always visible; the toggle reveals the full contents
	// BEFORE the operator selects (spec §58).
	const COLLAPSED_COUNT = 4;
	let expanded = $state<Record<string, boolean>>({});

	function keyFor(suggestion: SuggestionView, shift: string): string {
		return `${suggestion.id}:${shift}`;
	}

	function formatDate(value: string): string {
		const parts = value.split('-');
		if (parts.length !== 3) return value;
		return `${parts[2]}/${parts[1]}/${parts[0]}`;
	}

	// Spanish decimal separator for quantities (0.5 -> 0,5).
	function formatQty(quantity: number): string {
		return quantity.toString().replace('.', ',');
	}

	function lineText(line: SuggestionLine): string {
		return `${line.productName} — ${formatQty(line.quantity)} ${line.unit}`;
	}
</script>

<main class="page">
	<h1>Producción sugerida</h1>
	<AdminReturnLink role={data.role} />
	<p class="day-line">{data.weekdayLabel} · {formatDate(data.businessDate)}</p>

	{#if data.current}
		<div class="current">
			Seleccionada: OPCIÓN {data.current.code}
			{data.current.status === 'confirmed' ? '(confirmada)' : '(borrador)'}
		</div>
	{/if}

	{#if f.error}
		<div class="error" role="alert">{f.error}</div>
	{/if}

	{#if data.suggestions.length === 0}
		<p class="empty">Sin opciones de producción para este día.</p>
	{:else}
		<ul class="cards">
			{#each data.suggestions as suggestion (suggestion.id)}
				<li class="card">
					<div class="card-head">
						<h2 class="card-title">OPCIÓN {suggestion.code}</h2>
						<span class="card-count">{suggestion.itemCount} productos</span>
					</div>

					{#if suggestion.itemCount === 0}
						<p class="empty">Sin productos.</p>
					{/if}

					{#if suggestion.morning.length > 0}
						<section class="shift">
							<h3 class="shift-title">MAÑANA</h3>
							<ul class="lines">
								{#each expanded[keyFor(suggestion, 'morning')] ? suggestion.morning : suggestion.morning.slice(0, COLLAPSED_COUNT) as line, i (keyFor(suggestion, 'morning') + i)}
									<li class="line">{lineText(line)}</li>
								{/each}
							</ul>
							{#if suggestion.morning.length > COLLAPSED_COUNT}
								<button
									type="button"
									class="more"
									onclick={() =>
										(expanded[keyFor(suggestion, 'morning')] =
											!expanded[keyFor(suggestion, 'morning')])}
								>
									{expanded[keyFor(suggestion, 'morning')]
										? 'VER MENOS'
										: `VER TODOS (${suggestion.morning.length})`}
								</button>
							{/if}
						</section>
					{/if}

					{#if suggestion.night.length > 0}
						<section class="shift">
							<h3 class="shift-title">NOCHE</h3>
							<ul class="lines">
								{#each expanded[keyFor(suggestion, 'night')] ? suggestion.night : suggestion.night.slice(0, COLLAPSED_COUNT) as line, i (keyFor(suggestion, 'night') + i)}
									<li class="line">{lineText(line)}</li>
								{/each}
							</ul>
							{#if suggestion.night.length > COLLAPSED_COUNT}
								<button
									type="button"
									class="more"
									onclick={() =>
										(expanded[keyFor(suggestion, 'night')] =
											!expanded[keyFor(suggestion, 'night')])}
								>
									{expanded[keyFor(suggestion, 'night')]
										? 'VER MENOS'
										: `VER TODOS (${suggestion.night.length})`}
								</button>
							{/if}
						</section>
					{/if}

					<form
						method="POST"
						action={resolve('/production/suggestions?/choose')}
						use:enhance={preventDoubleSubmit}
						class="choose"
					>
						<input type="hidden" name="suggestion_id" value={suggestion.id} />
						<button type="submit" class="choose-btn">ELEGIR {suggestion.code}</button>
					</form>
				</li>
			{/each}
		</ul>
	{/if}

	<a class="back" href={resolve('/production')}>VOLVER A PRODUCCIÓN</a>
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

	.current {
		margin: 0 0 16px;
		padding: 10px 12px;
		font-size: 0.9375rem;
		font-weight: 600;
		color: var(--color-primary);
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
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

	.cards {
		list-style: none;
		margin: 0 0 16px;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	.card {
		padding: 14px;
		background: var(--color-surface);
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		box-sizing: border-box;
	}

	.card-head {
		display: flex;
		align-items: baseline;
		justify-content: space-between;
		gap: 8px;
		margin-bottom: 10px;
	}

	.card-title {
		font-size: 1.125rem;
		margin: 0;
		letter-spacing: 0.02em;
	}

	.card-count {
		font-size: 0.8125rem;
		color: var(--color-text-muted);
		white-space: nowrap;
	}

	.shift {
		margin-bottom: 12px;
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
		margin: 0 0 6px;
		padding: 0;
	}

	.line {
		display: flex;
		justify-content: space-between;
		gap: 12px;
		padding: 6px 0;
		border-bottom: 1px solid var(--color-border);
		font-size: 0.9375rem;
	}

	.more {
		display: inline-block;
		min-height: var(--touch-min);
		padding: 8px 12px;
		font-size: 0.875rem;
		font-weight: 700;
		letter-spacing: 0.04em;
		color: var(--color-primary);
		background: none;
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		cursor: pointer;
	}

	.choose {
		margin-top: 4px;
	}

	.choose-btn {
		display: block;
		width: 100%;
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
	}

	.back {
		display: inline-block;
		padding: 10px 0;
		font-size: 0.875rem;
		font-weight: 600;
		letter-spacing: 0.04em;
		color: var(--color-text-muted);
		text-decoration: none;
	}
</style>

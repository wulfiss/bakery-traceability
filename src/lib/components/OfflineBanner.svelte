<script lang="ts">
	import { browser } from '$app/environment';
	import { onMount } from 'svelte';

	// AS: visible while the browser is offline. Traceability mutations are
	// never queued: with no connection they fail visibly instead of being
	// "confirmed" later.
	let offline = $state(false);

	if (browser) offline = !navigator.onLine;

	onMount(() => {
		if (!browser) return;
		const handleOffline = () => {
			offline = true;
		};
		const handleOnline = () => {
			offline = false;
		};
		window.addEventListener('offline', handleOffline);
		window.addEventListener('online', handleOnline);
		return () => {
			window.removeEventListener('offline', handleOffline);
			window.removeEventListener('online', handleOnline);
		};
	});
</script>

{#if offline}
	<div class="offline-banner" role="alert">
		Sin conexión.<br />
		No se pueden confirmar registros de trazabilidad.
	</div>
{/if}

<style>
	.offline-banner {
		position: sticky;
		top: 0;
		z-index: 50;
		padding: 10px 16px;
		font-size: 0.9rem;
		line-height: 1.4;
		text-align: center;
		color: #ffffff;
		background: var(--color-danger);
	}
</style>

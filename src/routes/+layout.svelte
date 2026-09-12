<script lang="ts">
	import { browser } from '$app/environment';
	import { onMount } from 'svelte';
	import favicon from '$lib/assets/favicon.svg';
	import OfflineBanner from '$lib/components/OfflineBanner.svelte';
	import '../app.css';

	let { children } = $props();

	// AS: register the PWA service worker (production only — in dev the
	// cached /assets/ would shadow the unhashed dev modules).
	onMount(() => {
		if (browser && import.meta.env.PROD && 'serviceWorker' in navigator) {
			navigator.serviceWorker.register('/sw.js').catch(() => {
				// Best effort: the app works fully without the PWA layer.
			});
		}
	});
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
</svelte:head>

<OfflineBanner />

{@render children()}

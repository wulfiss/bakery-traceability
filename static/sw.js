/* PWA service worker (Phase AS).
 * Caches only immutable hashed static assets and successful HTML
 * navigations. It NEVER intercepts non-GET requests and never touches
 * cross-origin requests (Supabase), so critical traceability mutations
 * always go straight to the network and are never queued for offline
 * sync. When offline, page loads fall back to the last cached shell and
 * the app shows "Sin conexión". */

const ASSET_CACHE = 'bakery-assets-v1';
const PAGE_CACHE = 'bakery-pages-v1';

self.addEventListener('install', () => {
	// No precache list: hashed assets are cached on first use.
	self.skipWaiting();
});

self.addEventListener('activate', (event) => {
	event.waitUntil(
		caches
			.keys()
			.then((keys) =>
				Promise.all(
					keys
						.filter((key) => key !== ASSET_CACHE && key !== PAGE_CACHE)
						.map((key) => caches.delete(key))
				)
			)
			.then(() => self.clients.claim())
	);
});

self.addEventListener('fetch', (event) => {
	const { request } = event;

	// Never cache mutations (POST/PUT/PATCH/DELETE) or API traffic.
	if (request.method !== 'GET') return;
	const url = new URL(request.url);
	if (url.origin !== self.location.origin) return;

	// Hashed static assets: cache-first (immutable by content hash).
	if (url.pathname.startsWith('/assets/')) {
		event.respondWith(
			caches.match(request).then(
				(cached) =>
					cached ||
					fetch(request).then((response) => {
						if (!response.ok) return response;
						const copy = response.clone();
						caches.open(ASSET_CACHE).then((cache) => cache.put(request, copy));
						return response;
					})
			)
		);
		return;
	}

	// HTML navigations: network-first, fall back to the last cached shell.
	if (request.mode === 'navigate') {
		event.respondWith(
			fetch(request)
				.then((response) => {
					if (response.ok) {
						const copy = response.clone();
						caches.open(PAGE_CACHE).then((cache) => cache.put(request, copy));
					}
					return response;
				})
				.catch(() => caches.match(request).then((cached) => cached || caches.match('/')))
		);
	}
});

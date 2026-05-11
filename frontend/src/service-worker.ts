/// <reference types="@sveltejs/kit" />
/// <reference no-default-lib="true"/>
/// <reference lib="esnext" />
/// <reference lib="webworker" />

declare let self: ServiceWorkerGlobalScope;

import { build, files, version } from '$service-worker';

const CACHE_NAME = `forgenexus-${version}`;

// App shell: built JS/CSS bundles + static files (icons, manifest)
const APP_SHELL = [...build, ...files];

// API routes to cache for offline reading
const CACHEABLE_API_PATTERNS = [
  /\/api\/settings\/public$/,
  /\/api\/forums$/,
  /\/api\/stats\/cached$/,
  /\/api\/stats\/welcome$/,
  /\/api\/featured-threads$/
];

// API routes that should NEVER be cached
const NEVER_CACHE_PATTERNS = [
  /\/api\/auth\//,
  /\/api\/setup\//,
  /\/api\/admin\//,
  /\/api\/health$/
];

// --- Install: cache the app shell ---
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL))
  );
  // Activate immediately, don't wait for old tabs to close
  self.skipWaiting();
});

// --- Activate: clean up old caches ---
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key !== CACHE_NAME)
          .map((key) => caches.delete(key))
      )
    )
  );
  // Take control of all open tabs immediately
  self.clients.claim();
});

// --- Fetch: serve from cache, update in background ---
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Only handle GET requests
  if (request.method !== 'GET') return;

  // Skip cross-origin requests
  if (url.origin !== self.location.origin) return;

  // --- App shell: cache-first ---
  if (APP_SHELL.includes(url.pathname)) {
    event.respondWith(
      caches.match(request).then((cached) => cached || fetch(request))
    );
    return;
  }

  // --- API requests ---
  if (url.pathname.startsWith('/api/')) {
    // Never cache sensitive routes
    if (NEVER_CACHE_PATTERNS.some((p) => p.test(url.pathname))) return;

    // Cacheable API: stale-while-revalidate
    if (CACHEABLE_API_PATTERNS.some((p) => p.test(url.pathname))) {
      event.respondWith(staleWhileRevalidate(request));
      return;
    }

    // Other API: network-first with cache fallback
    event.respondWith(networkFirst(request));
    return;
  }

  // --- Built JS/CSS chunks: try network → cache → if both miss with 404,
  //     tell every open client to reload. Catches the stale-bundle trap
  //     where an old SPA references chunk hashes from a previous build.
  if (url.pathname.startsWith('/_app/immutable/')) {
    event.respondWith(handleImmutableChunk(request));
    return;
  }

  // --- Pages: network-first, fall back to cached shell ---
  event.respondWith(
    fetch(request).catch(() =>
      caches.match(request).then((cached) => cached || caches.match('/'))
    )
  );
});

async function handleImmutableChunk(request: Request): Promise<Response> {
  const cache = await caches.open(CACHE_NAME);
  const cached = await cache.match(request);
  if (cached) return cached;

  try {
    const response = await fetch(request);
    if (response.ok) {
      cache.put(request, response.clone());
      return response;
    }

    // 404 on an immutable asset = the SPA references a chunk from a previous
    // build. Force a hard reload of every controlled tab so it picks up the
    // current build's hashes. This makes deploy mistakes self-recover.
    if (response.status === 404) {
      const clients = await self.clients.matchAll({ type: 'window' });
      for (const client of clients) {
        (client as WindowClient).postMessage({ type: 'sw-stale-bundle-reload' });
      }
    }
    return response;
  } catch {
    return new Response('', { status: 503 });
  }
}

// --- Strategies ---

async function staleWhileRevalidate(request: Request): Promise<Response> {
  const cache = await caches.open(CACHE_NAME);
  const cached = await cache.match(request);

  // Fetch fresh in background
  const fetchPromise = fetch(request)
    .then((response) => {
      if (response.ok) {
        cache.put(request, response.clone());
      }
      return response;
    })
    .catch(() => cached || new Response('{"error":"offline"}', {
      status: 503,
      headers: { 'Content-Type': 'application/json' }
    }));

  // Return cached immediately if available, otherwise wait for network
  return cached || fetchPromise;
}

async function networkFirst(request: Request): Promise<Response> {
  const cache = await caches.open(CACHE_NAME);

  try {
    const response = await fetch(request);
    if (response.ok) {
      cache.put(request, response.clone());
    }
    return response;
  } catch {
    const cached = await cache.match(request);
    return cached || new Response('{"error":"offline"}', {
      status: 503,
      headers: { 'Content-Type': 'application/json' }
    });
  }
}

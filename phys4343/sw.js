
const CACHE = "amo-textbook-v2";
const START = "/index.html";

self.addEventListener("install", event => {
  event.waitUntil(
    caches.open(CACHE).then(cache =>
      cache.add(new Request(START, { cache: "reload" }))
    )
  );
  self.skipWaiting();
});

self.addEventListener("activate", event => {
  event.waitUntil(
    Promise.all([
      caches.keys().then(keys =>
        Promise.all(
          keys
            .filter(key =>
              key.startsWith("amo-textbook-") &&
              key !== CACHE
            )
            .map(key => caches.delete(key))
        )
      ),
      self.clients.claim()
    ])
  );
});

self.addEventListener("fetch", event => {
  if (event.request.method !== "GET") return;

  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;

  // Request fresh HTML, CSS and JavaScript from the server.
  // Retain cached versions for offline access.
  const isDocument = event.request.mode === "navigate";
  const isAsset = /\.(css|js|mjs)$/i.test(url.pathname);

  const request = (isDocument || isAsset)
    ? new Request(event.request, { cache: "no-cache" })
    : event.request;

  event.respondWith(
    fetch(request).then(response => {
      if (response.ok) {
        const copy = response.clone();

        event.waitUntil(
          caches.open(CACHE).then(cache =>
            cache.put(event.request, copy)
          )
        );
      }

      return response;
    }).catch(() => caches.match(event.request))
  );
});

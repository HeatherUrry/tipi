// The Shinylive version of this page was retired. Browsers that registered its
// service worker download this replacement, which removes itself.
self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys()
      .then(function (keys) { return Promise.all(keys.filter(function (k) {
        return k.indexOf('shinylive') !== -1; }).map(function (k) { return caches.delete(k); })); })
      .then(function () { return self.registration.unregister(); }));
});

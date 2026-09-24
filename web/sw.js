// Service worker di Vaultly: fa funzionare l'app anche senza internet.
// Tiene una copia dei file dell'app (codice, font, icone) e la usa subito all'apertura;
// intanto, se c'è connessione, scarica la versione nuova, che si vedrà alla prossima apertura.
// Riguarda SOLO i file dell'app: i dati dell'utente sono in IndexedDB e non passano da qui.
const CACHE = 'vaultly-app';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

// Dopo l'avvio la pagina manda l'elenco dei file che ha usato: si salvano tutti, insieme
// alla pagina principale, così la prossima apertura funziona anche offline.
self.addEventListener('message', (event) => {
  if (!event.data || event.data.type !== 'cache-app') return;
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    const urls = [self.registration.scope, ...event.data.urls]
      .filter((u) => new URL(u).origin === self.location.origin);
    await Promise.all(urls.map(async (u) => {
      try {
        const response = await fetch(u);
        if (response.ok) await cache.put(u, response);
      } catch (_) {
        // offline: si riproverà alla prossima apertura
      }
    }));
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== self.location.origin) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    // Le pagine si cercano senza "?query", così l'app si apre anche offline.
    const key = request.mode === 'navigate' ? new URL('./', self.registration.scope).href : request;
    const cached = await cache.match(key, { ignoreSearch: request.mode === 'navigate' });
    const network = fetch(request)
      .then((response) => {
        if (response.ok && response.type === 'basic') cache.put(key, response.clone());
        return response;
      })
      .catch(() => undefined);
    if (cached) {
      event.waitUntil(network);
      return cached;
    }
    return (await network) || new Response('Vaultly: apri l\'app una volta con internet.', { status: 503 });
  })());
});

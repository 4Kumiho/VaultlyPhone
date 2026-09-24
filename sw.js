// Service worker di Vaultly: fa funzionare l'app anche senza internet.
// Con internet si scarica sempre la versione più recente dei file dell'app (chiedendo al server se
// sono cambiati) e se ne tiene una copia; senza internet, o se la rete non risponde entro pochi
// secondi, si usa la copia. Così gli aggiornamenti arrivano subito e l'app si apre anche offline.
// Riguarda SOLO i file dell'app: i dati dell'utente sono in IndexedDB e non passano da qui.
const CACHE = 'vaultly-app';

// I file si salvano per indirizzo senza "?v=..." (che cambia a ogni apertura).
const keyOf = (url) => {
  const u = new URL(url);
  return u.origin + u.pathname;
};
const NETWORK_TIMEOUT_MS = 4000;

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
      if (await cache.match(keyOf(u))) return; // già salvato (e aggiornato dalle richieste normali)
      try {
        const response = await fetch(keyOf(u), { cache: 'no-cache' });
        if (response.ok) await cache.put(keyOf(u), response);
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
    // La pagina si salva sotto l'indirizzo dell'app, senza "?query".
    const key = request.mode === 'navigate' ? new URL('./', self.registration.scope).href : keyOf(request.url);
    // "no-cache": il browser chiede sempre al server se il file è cambiato (risposta minima se no).
    const network = fetch(request.url, { cache: 'no-cache', credentials: 'same-origin' })
      .then(async (response) => {
        if (response.ok && response.type === 'basic') await cache.put(key, response.clone());
        return response;
      });
    const timeout = new Promise((resolve) => setTimeout(() => resolve(null), NETWORK_TIMEOUT_MS));
    try {
      const response = await Promise.race([network, timeout]);
      if (response) return response;
    } catch (_) {
      // offline
    }
    event.waitUntil(network.catch(() => {})); // rete lenta: la copia nuova arriverà per la prossima volta
    const cached = await cache.match(key);
    if (cached) return cached;
    try {
      return await network;
    } catch (_) {
      return new Response('Vaultly: apri l\'app una volta con internet.', { status: 503 });
    }
  })());
});

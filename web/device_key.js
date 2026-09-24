// Chiave del dispositivo per il codice di sicurezza a 6 cifre.
//
// Per ogni utente il browser genera una chiave AES-256 "non estraibile": si può usare per cifrare
// e decifrare, ma nessuno script può leggerla o copiarla, e resta in questo browser su questo
// telefono (Safari la protegge a sua volta con il portachiavi del dispositivo). La chiave dei dati,
// già cifrata con il codice, viene cifrata una seconda volta con questa: senza il telefono non si
// possono nemmeno provare i codici. Niente passa da internet.
window.vaultlyDevice = (() => {
  const DB = "vaultly-device";
  const STORE = "keys";

  function open() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open(DB, 1);
      request.onupgradeneeded = () => request.result.createObjectStore(STORE);
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }

  function run(mode, action) {
    return open().then((db) => new Promise((resolve, reject) => {
      const tx = db.transaction(STORE, mode);
      const request = action(tx.objectStore(STORE));
      tx.oncomplete = () => { db.close(); resolve(request.result); };
      tx.onerror = () => { db.close(); reject(tx.error); };
    }));
  }

  async function key(id, create) {
    let found = await run("readonly", (s) => s.get(id));
    if (!found && create) {
      found = await crypto.subtle.generateKey({ name: "AES-GCM", length: 256 }, false, ["encrypt", "decrypt"]);
      await run("readwrite", (s) => s.put(found, id));
    }
    return found || null;
  }

  return {
    // Cifra con una chiave nuova per `id` (quella vecchia viene sostituita): iv (12) | cifrato.
    async encrypt(id, data) {
      await run("readwrite", (s) => s.delete(id));
      const k = await key(id, true);
      const iv = crypto.getRandomValues(new Uint8Array(12));
      const cipher = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv }, k, data));
      const out = new Uint8Array(12 + cipher.length);
      out.set(iv);
      out.set(cipher, 12);
      return out;
    },
    // null se la chiave non c'è più o il contenuto non torna.
    async decrypt(id, data) {
      try {
        const k = await key(id, false);
        if (!k) return null;
        const plain = await crypto.subtle.decrypt({ name: "AES-GCM", iv: data.slice(0, 12) }, k, data.slice(12));
        return new Uint8Array(plain);
      } catch (_) {
        return null;
      }
    },
    async remove(id) {
      await run("readwrite", (s) => s.delete(id));
    },
  };
})();

{{flutter_js}}
{{flutter_build_config}}

// Niente risorse da internet: CanvasKit è incluso nella build (--no-web-resources-cdn) e i font
// di riserva non vengono scaricati da Google (il percorso è locale e non contiene nulla).
// Anche il codice dell'app si chiede con l'indirizzo di questa apertura (vedi index.html).
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) build.mainJsPath += "?v=" + (window.vaultlyLoadVersion || Date.now());
}

// Chiede al browser di tenere i dati di Vaultly anche quando il telefono ha poco spazio
// (senza, il browser potrebbe cancellarli da solo per liberare memoria).
if (navigator.storage && navigator.storage.persist) {
  navigator.storage.persist().catch(() => {});
}

// Copia locale dei file dell'app, per aprirla anche senza internet (vedi sw.js).
if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("sw.js").catch(() => {});
}

_flutter.loader.load({
  config: {
    fontFallbackBaseUrl: "assets/no-fallback-fonts/",
  },
  onEntrypointLoaded: async (engineInitializer) => {
    const appRunner = await engineInitializer.initializeEngine();
    document.getElementById("splash")?.remove();
    await appRunner.runApp();
    // App avviata: il service worker salva i file appena usati (codice, CanvasKit, font).
    if ("serviceWorker" in navigator) {
      navigator.serviceWorker.ready.then((reg) => {
        const urls = performance.getEntriesByType("resource").map((e) => e.name.split("#")[0]);
        reg.active?.postMessage({ type: "cache-app", urls: [...new Set(urls)] });
      });
    }
  },
});

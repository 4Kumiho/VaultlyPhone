# Vaultly Phone

Versione per telefono di [Vaultly](../Vaultly) (app desktop Qt): conti, movimenti, etichette con tetti di spesa, grafico del saldo e area password. Uso personale del proprietario, su **iPhone**, a **costo zero**.

## Scelte di fondo

- **Web app installabile (PWA)** fatta con **Flutter** (Dart): si apre da Safari e con "Aggiungi a schermata Home" diventa un'icona a schermo intero. Niente App Store, niente Mac, niente account a pagamento. Il codice resta compilabile anche come app Android/iOS vera (cartelle `android/`, `ios/`), se un giorno servirà.
- **Pubblicazione**: build web statica su GitHub Pages (gratis). Il sito serve solo a scaricare l'app.
- **Dati solo sul telefono, mai su internet.** È un requisito del proprietario:
  - l'app **non fa nessuna richiesta di rete** (nessun server, analytics, font o librerie da CDN);
  - la build usa `--no-web-resources-cdn` e i font sono inclusi nell'app;
  - ogni nuova dipendenza va controllata: niente pacchetti che chiamano la rete.
- **Dati separati dal PC**: nessuna sincronizzazione (richiederebbe un server). Eventuale scambio solo con file di backup esportati/importati a mano.

## Archiviazione e sicurezza

- Archiviazione locale nel browser (IndexedDB) tramite `sembast` / `sembast_web`.
- **Tutti i dati di un utente sono cifrati** (più del desktop, dove sono cifrate solo le password salvate): un unico documento JSON con conti, movimenti, etichette e password, cifrato AES-256-GCM.
  - Login: PBKDF2-SHA256 (100.000 iterazioni) con `salt` → hash salvato.
  - Chiave dei dati: PBKDF2-SHA256 con un salt diverso (`dataSalt`) → mai salvata, esiste solo in memoria durante la sessione.
  - Password dimenticata = dati irrecuperabili (come sul desktop).
- Crittografia: pacchetto `cryptography` (sul web usa la Web Crypto API del browser).
- Importi sempre in **unità minime intere** (centesimi), mai `double`, come sul desktop.

## Funzioni (allineate al desktop)

1. Registrazione / accesso (più utenti sullo stesso telefono, ognuno con i suoi dati cifrati). Alla registrazione anche email e telefono (prefisso scelto dall'elenco dei paesi con bandiera: `lib/core/countries.dart` generato da phonenumbers + CLDR, bandiere dal pacchetto `country_flags`, incluse nell'app). Nessun recupero password: non c'è server.
   Area "Il tuo account" (`ui/account_screen.dart`): avatar (foto scelta con un `<input type=file>` letto nel browser, ritagliata a 320 px PNG, salvata **cifrata** nel profilo; oppure iniziale su colore), username, email/telefono, cambio password (dati ricifrati, il codice va rifatto), codice, eliminazione dell'utente.
   Dopo il primo accesso con password si crea un **codice di 6 cifre** (ripetuto); poi all'apertura: scelta dell'utente → codice. La chiave dei dati è cifrata con PBKDF2(codice) e poi con una chiave AES **non estraibile** del browser (`web/device_key.js`, IndexedDB `vaultly-device`): i codici si possono provare solo dal telefono; dopo 5 errori il codice si disattiva e serve la password.
2. Conti con valuta e saldo iniziale modificabile; eliminazione con conferma.
3. Movimenti (entrata/uscita, categoria dalla lista fissa, data e ora, descrizione, etichette).
4. Grafico del saldo con periodi 1G/1S/1M/6M/1A/Tutto.
5. Etichette, **diverse dal desktop**, di due tipi:
   - *una tantum* (es. viaggio a Rimini): durata una settimana, un mese o date libere; si possono mettere **solo** sui movimenti dentro le date;
   - *ricorrenti* (es. autostrada): ogni N giorni / settimane (da lunedì) / mesi (dal 1°) / anni (dal 1° gennaio); il conteggio riparte ogni periodo e la scheda dell'etichetta mostra lo storico dei periodi precedenti.
   Le etichette si creano prima di usarle (scrivendo un nome nuovo in un movimento si apre la scheda di creazione). Tetto di spesa facoltativo (per periodo o per l'intera durata); avvisi all'80% e al superamento.
6. Area password con ricerca, copia e generatore.
7. Backup: esporta/importa un file cifrato.

Categorie, valute e regole di validazione sono le stesse del desktop (vedi `../Vaultly`).

## Interfaccia

- Pensata per il telefono in verticale: navigazione in basso, pannelli che salgono dal basso (bottom sheet), tasti grandi.
- Stesso tema scuro e colori del desktop (accento `#5b8cff`, sfondo `#0f1115`, superfici `#171a21`).
- Testi e formati in italiano (`it_IT`).

## Struttura

```
lib/
├── main.dart
├── core/      # modelli, servizi, calcoli (Dart puro, testabili senza UI)
├── data/      # archiviazione (sembast) e cifratura
└── ui/        # schermate e componenti
test/          # test con `flutter test`
web/           # index.html, manifest (PWA), icone
```

## Comandi

```powershell
flutter pub get
flutter test
flutter run -d edge                      # prova nel browser
flutter build web --release --no-web-resources-cdn
```

Flutter è in `D:\Tools\flutter` (telemetria di Flutter e Dart disattivata).

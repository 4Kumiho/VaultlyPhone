import 'package:flutter/material.dart';

import '../core/auth_service.dart';
import '../data/crypto.dart';
import 'theme.dart';
import 'widgets.dart';

/// "Come sono protetti i tuoi dati": dove sono salvati, come sono cifrati, cosa passa da internet.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PrivacyScreen()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('I tuoi dati'),
        backgroundColor: VColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: const [
          _Summary(),
          SizedBox(height: 18),
          _Topic(
            icon: Icons.phone_iphone,
            title: 'Dove sono salvati',
            body: 'Tutto quello che inserisci (profilo, foto, conti, movimenti, etichette e password) '
                'è salvato nella memoria interna di questo telefono, nello spazio che il browser riserva '
                'a Vaultly (un database chiamato IndexedDB).\n\n'
                'Quello spazio appartiene solo a Vaultly: altri siti e altre app non possono leggerlo.',
          ),
          _Topic(
            icon: Icons.cloud_off_outlined,
            title: 'Cosa passa da internet',
            body: 'Solo l\'app stessa: il codice, i caratteri e le icone, uguali per tutti. Si scaricano la '
                'prima volta e quando esce un aggiornamento.\n\n'
                'I tuoi dati non partono mai: Vaultly non ha un server, non ha account online, non usa '
                'statistiche, pubblicità o cookie. Per questo funziona anche in modalità aereo.',
          ),
          _Topic(
            icon: Icons.lock_outline,
            title: 'Come sono cifrati',
            body: 'Prima di essere salvati, i tuoi dati vengono cifrati con AES-256-GCM, lo standard usato '
                'da banche e governi. La chiave nasce dalla tua password '
                '(PBKDF2-SHA256, ${VaultCrypto.defaultIterations} passaggi) e non viene mai salvata: esiste '
                'solo mentre l\'app è aperta.\n\n'
                'Sul telefono resta leggibile solo il tuo username. Tutto il resto, senza la password, è una '
                'sequenza di byte senza senso. Ogni utente ha la sua chiave e non vede i dati degli altri.',
          ),
          _Topic(
            icon: Icons.dialpad,
            title: 'Il codice di ${AuthService.pinLength} cifre',
            body: 'Il codice apre la chiave dei tuoi dati, ma da solo non basta: la chiave è cifrata una '
                'seconda volta con una chiave del dispositivo, che il browser custodisce e non permette a '
                'nessuno di leggere o copiare. Il codice quindi funziona solo su questo telefono.\n\n'
                'Dopo ${AuthService.maxPinFailures} codici sbagliati il codice si disattiva e serve la password.',
          ),
          _Topic(
            icon: Icons.block,
            title: 'Il blocco verso internet',
            body: 'La pagina di Vaultly contiene una regola di sicurezza del browser (Content-Security-Policy) '
                'che vieta qualsiasi collegamento verso altri siti. Anche se nel codice ci fosse un errore, '
                'il browser bloccherebbe l\'invio.',
          ),
          _Topic(
            icon: Icons.fact_check_outlined,
            title: 'Controllato, e controllabile',
            body: 'Vaultly è stato provato usando tutte le sue funzioni mentre si registrava ogni '
                'richiesta di rete: nessuna richiesta verso altri siti e nessun dato inviato. Nella memoria '
                'del telefono non compare in chiaro nessuno dei dati inseriti.\n\n'
                'Puoi verificarlo anche tu: metti il telefono in modalità aereo e usa Vaultly, funziona '
                'tutto. Il codice dell\'app è pubblico su github.com/4Kumiho/VaultlyPhone.',
          ),
          SizedBox(height: 8),
          _KeepData(),
          SizedBox(height: 10),
          _Limits(),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: VColors.positive.withValues(alpha: 0.08),
          border: Border.all(color: VColors.positive.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.shield_outlined, color: VColors.positive),
            SizedBox(width: 10),
            Expanded(
              child: Text('I tuoi dati restano sul tuo telefono',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ),
          ]),
          SizedBox(height: 12),
          _Point('Sono salvati solo nella memoria di questo telefono.'),
          _Point('Sono cifrati con la tua password: senza, nessuno può leggerli.'),
          _Point('Vaultly non li invia a nessuno: non esiste un server.'),
        ]),
      );
}

class _Point extends StatelessWidget {
  const _Point(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle, size: 17, color: VColors.positive),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
        ]),
      );
}

class _Topic extends StatelessWidget {
  const _Topic({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: VCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: VColors.accentLight, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 8),
            Muted(body),
          ]),
        ),
      );
}

/// Cosa non fare (e cosa si può fare) per non perdere i dati, che esistono solo sul telefono.
class _KeepData extends StatelessWidget {
  const _KeepData();

  static const _dont = [
    ('Non eliminare l\'icona di Vaultly dalla schermata Home.',
        'Insieme all\'icona l\'iPhone cancella tutti i dati di Vaultly. Se la sposti o la metti in una cartella, '
            'invece, non succede niente.'),
    ('Non cancellare i dati dei siti web di Safari.',
        'In Impostazioni → App → Safari evita "Cancella cronologia e dati dei siti web" e, in Avanzate → '
            'Dati dei siti web, "Rimuovi tutti i dati" o la voce 4kumiho.github.io: possono cancellare i dati di Vaultly.'),
    ('Non inizializzare l\'iPhone e non cambiare telefono senza pensarci.',
        'Vaultly non ha un backup online: su un telefono nuovo o inizializzato i dati non ci sono più. Non '
            'contare nemmeno sul backup di iCloud per riaverli.'),
    ('Non usarla in una pagina di navigazione privata.',
        'In una pagina privata di Safari quello che scrivi viene cancellato quando la chiudi.'),
  ];

  static const _ok = [
    'Chiudere Vaultly, spegnere e riaccendere il telefono.',
    'Aggiornare iOS e aggiornare Vaultly (gli aggiornamenti non toccano i dati).',
    'Usarla senza internet o in modalità aereo.',
    'Spostare l\'icona o metterla in una cartella.',
    'Usare Safari normalmente per altri siti.',
  ];

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: VColors.negative.withValues(alpha: 0.07),
          border: Border.all(color: VColors.negative.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.warning_amber_rounded, color: VColors.negative),
            SizedBox(width: 10),
            Expanded(
              child: Text('Per non perdere i dati', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 8),
          const Muted('I dati esistono solo su questo telefono, dentro Vaultly: se vengono cancellati da qui, '
              'non c\'è nessuna copia da cui recuperarli.'),
          const SizedBox(height: 14),
          const Text('Cosa NON fare', style: TextStyle(fontWeight: FontWeight.w700, color: VColors.negative)),
          for (final (title, detail) in _dont)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.close_rounded, size: 18, color: VColors.negative),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.3)),
                    const SizedBox(height: 2),
                    Muted(detail, size: 12.5),
                  ]),
                ),
              ]),
            ),
          const SizedBox(height: 16),
          const Text('Cosa puoi fare tranquillamente', style: TextStyle(fontWeight: FontWeight.w700, color: VColors.positive)),
          for (final text in _ok)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.check_rounded, size: 18, color: VColors.positive),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(text, style: const TextStyle(height: 1.3))),
              ]),
            ),
          const SizedBox(height: 14),
          const Muted(
            'Apri Vaultly sempre dall\'icona sulla schermata Home. Se apri l\'indirizzo in Safari vedi una Vaultly '
            'vuota: non hai perso niente, è solo uno spazio separato. I tuoi dati sono nell\'app dell\'icona.',
            size: 12.5,
          ),
        ]),
      );
}

/// Cosa la sicurezza non può coprire: detto chiaramente.
class _Limits extends StatelessWidget {
  const _Limits();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: VColors.warning.withValues(alpha: 0.07),
          border: Border.all(color: VColors.warning.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.info_outline, color: VColors.warning),
            SizedBox(width: 10),
            Text('Cosa devi sapere', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
          ]),
          SizedBox(height: 10),
          Muted(
            '• La password non si può recuperare e non c\'è un backup online: è il prezzo della sicurezza. '
            'Se la dimentichi, i dati non si possono più aprire.\n'
            '• Alcune operazioni sul telefono cancellano i dati: le trovi qui sopra, in "Per non perdere i dati".\n'
            '• Chi conosce il tuo codice e ha in mano il tuo telefono può entrare: non dirlo a nessuno.\n'
            '• Quando salvi una password, l\'iPhone può proporti di metterla nel Portachiavi iCloud: se vuoi '
            'che non esca dal telefono, rispondi "Non ora".\n'
            '• Una password copiata può comparire negli appunti di un Mac o iPad con lo stesso Apple ID '
            '(Handoff); Vaultly prova a cancellarla dagli appunti dopo 30 secondi.\n'
            '• Se i dati finissero in un backup del telefono, resterebbero comunque cifrati.',
          ),
        ]),
      );
}

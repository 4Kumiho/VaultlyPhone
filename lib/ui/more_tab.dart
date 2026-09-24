import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_data.dart';
import '../main.dart';
import 'lock_screens.dart';
import 'phone_field.dart';
import 'sheets/profile_sheet.dart';
import 'theme.dart';
import 'widgets.dart';

/// Sezione "Altro": utente, privacy, uscita.
class MoreTab extends StatelessWidget {
  const MoreTab({super.key, required this.onLogout});
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('Altro', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),
          VCard(
            child: Row(children: [
              Image.asset('assets/vaultly.png', width: 44, height: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data.username, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const Muted('Vaultly $appVersion', size: 12.5),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          VCard(
            onTap: () => showSheet(context, const ProfileSheet()),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Caption('Contatti'),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.mail_outline, size: 18, color: VColors.muted),
                    const SizedBox(width: 8),
                    Expanded(child: Text(data.email.isEmpty ? '—' : data.email, overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    if (data.phone.isEmpty)
                      const Icon(Icons.phone_outlined, size: 18, color: VColors.muted)
                    else
                      Flag(data.phoneCountry, width: 18),
                    const SizedBox(width: 8),
                    Text(data.phone.isEmpty ? '—' : data.phoneFull),
                  ]),
                ]),
              ),
              const Icon(Icons.chevron_right, color: VColors.faint),
            ]),
          ),
          const SizedBox(height: 12),
          VCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (route) => PinSetupScreen(
                save: data.changePin,
                onCancel: () => Navigator.pop(route),
                onDone: () {
                  Navigator.pop(route);
                  showToast(context, 'Codice di sicurezza cambiato.');
                },
              ),
            )),
            child: const Row(children: [
              Icon(Icons.dialpad, color: VColors.accentLight, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Codice di sicurezza', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 2),
                  Muted('Cambia il codice di 6 cifre con cui entri.', size: 12.5),
                ]),
              ),
              Icon(Icons.chevron_right, color: VColors.faint),
            ]),
          ),
          const SizedBox(height: 12),
          const VCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.shield_outlined, color: VColors.positive, size: 20),
                SizedBox(width: 8),
                Text('I tuoi dati', style: TextStyle(fontWeight: FontWeight.w600)),
              ]),
              SizedBox(height: 8),
              Muted(
                'Profilo, conti, movimenti, etichette e password restano solo su questo telefono, cifrati con la tua '
                'password di accesso. Vaultly non li invia mai su internet.\n\n'
                'Se elimini l\'app dalla schermata Home o cancelli i dati di Safari per questo sito, i dati '
                'vengono cancellati.',
              ),
            ]),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Esci'),
          ),
        ],
      ),
    );
  }
}

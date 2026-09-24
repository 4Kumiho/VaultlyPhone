import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_data.dart';
import '../main.dart';
import 'account_screen.dart';
import 'avatar.dart';
import 'privacy_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Sezione "Altro": il tuo account, privacy, uscita.
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
            onTap: () => AccountScreen.open(context),
            child: Row(children: [
              UserAvatar(name: data.username, photo: data.avatar, color: data.avatarColor, size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data.username, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  const Muted('Il tuo account: foto, dati, password e codice', size: 12.5),
                ]),
              ),
              const Icon(Icons.chevron_right, color: VColors.faint),
            ]),
          ),
          const SizedBox(height: 12),
          VCard(
            onTap: () => PrivacyScreen.open(context),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.shield_outlined, color: VColors.positive, size: 20),
                SizedBox(width: 8),
                Text('I tuoi dati', style: TextStyle(fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 8),
              const Muted(
                'Profilo, foto, conti, movimenti, etichette e password restano solo su questo telefono, cifrati con '
                'la tua password di accesso. Vaultly non li invia mai su internet.\n\n'
                'Se elimini l\'app dalla schermata Home o cancelli i dati di Safari per questo sito, i dati '
                'vengono cancellati.',
              ),
              const SizedBox(height: 12),
              const Row(children: [
                Flexible(
                  child: Text('Maggiori informazioni',
                      style: TextStyle(color: VColors.accentLight, fontWeight: FontWeight.w600)),
                ),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, color: VColors.accentLight, size: 20),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Esci'),
          ),
          const SizedBox(height: 14),
          const Muted('Vaultly $appVersion', size: 11.5, align: TextAlign.center),
        ],
      ),
    );
  }
}

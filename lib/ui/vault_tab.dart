import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_data.dart';
import '../core/models.dart';
import 'sheets/vault_sheet.dart';
import 'theme.dart';
import 'widgets.dart';

/// Sezione "Password": voci cifrate con la password di accesso, ricerca e copia.
class VaultTab extends StatefulWidget {
  const VaultTab({super.key});

  @override
  State<VaultTab> createState() => _VaultTabState();
}

class _VaultTabState extends State<VaultTab> {
  final _search = TextEditingController();
  Timer? _clearTimer;

  @override
  void dispose() {
    _search.dispose();
    _clearTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showToast(context, '$message · gli appunti si svuotano tra 30 secondi');
    // Nel browser svuotare gli appunti senza un tocco dell'utente può non riuscire: si prova.
    _clearTimer?.cancel();
    _clearTimer = Timer(const Duration(seconds: 30), () async {
      try {
        final current = await Clipboard.getData(Clipboard.kTextPlain);
        if (current?.text == text) await Clipboard.setData(const ClipboardData(text: ''));
      } catch (_) {}
    });
  }

  bool _matches(VaultItem v, String q) =>
      q.isEmpty || [v.title, v.username, v.url].any((f) => f.toLowerCase().contains(q));

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final all = data.vault;
    final q = _search.text.trim().toLowerCase();
    final items = all.where((v) => _matches(v, q)).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showSheet(context, const VaultSheet()),
        icon: const Icon(Icons.add),
        label: const Text('Password', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('Le tue password', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 14),
              child: Muted('Cifrate con AES-256 usando la tua password di accesso. Se la dimentichi, non si possono recuperare.'),
            ),
            if (all.isNotEmpty) ...[
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Cerca per nome, utente o sito',
                  prefixIcon: Icon(Icons.search, color: VColors.muted),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (all.isEmpty)
              const VCard(
                padding: EdgeInsets.all(24),
                child: Muted('Nessuna password salvata. Tieni qui login e password dei tuoi account, al sicuro.',
                    align: TextAlign.center),
              )
            else if (items.isEmpty)
              Padding(padding: const EdgeInsets.all(24), child: Muted('Nessun risultato per "$q".', align: TextAlign.center)),
            for (final v in items) ...[
              VCard(
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                onTap: () => showSheet(context, VaultSheet(item: v)),
                child: Row(children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: VColors.accent.withValues(alpha: 0.16),
                    child: Text(v.title.characters.first.toUpperCase(),
                        style: const TextStyle(color: VColors.accentLight, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(v.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Muted(v.username.isEmpty ? '—' : v.username, size: 12.5),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'Copia utente',
                    icon: const Icon(Icons.person_outline, size: 20),
                    color: VColors.muted,
                    onPressed: v.username.isEmpty ? null : () => _copy(v.username, 'Username copiato'),
                  ),
                  IconButton(
                    tooltip: 'Copia password',
                    icon: const Icon(Icons.key_outlined, size: 20),
                    color: VColors.accentLight,
                    onPressed: v.password.isEmpty ? null : () => _copy(v.password, 'Password copiata'),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

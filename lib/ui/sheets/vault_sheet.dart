import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_data.dart';
import '../../core/models.dart';
import '../theme.dart';
import '../widgets.dart';

/// Aggiunge, modifica o elimina una voce dell'area password.
class VaultSheet extends StatefulWidget {
  const VaultSheet({super.key, this.item});
  final VaultItem? item;

  @override
  State<VaultSheet> createState() => _VaultSheetState();
}

class _VaultSheetState extends State<VaultSheet> {
  late final _title = TextEditingController(text: widget.item?.title ?? '');
  late final _url = TextEditingController(text: widget.item?.url ?? '');
  late final _username = TextEditingController(text: widget.item?.username ?? '');
  late final _password = TextEditingController(text: widget.item?.password ?? '');
  late final _notes = TextEditingController(text: widget.item?.notes ?? '');
  bool _show = false;
  String? _error;
  bool _confirmDelete = false;

  bool get _editing => widget.item != null;

  @override
  void dispose() {
    for (final c in [_title, _url, _username, _password, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final error = await context.read<AppData>().saveVaultItem(VaultItem(
          id: widget.item?.id ?? '',
          title: _title.text,
          url: _url.text,
          username: _username.text,
          password: _password.text,
          notes: _notes.text,
          updatedAt: DateTime.now(),
        ));
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _delete() async {
    if (!_confirmDelete) {
      setState(() => _confirmDelete = true);
      return;
    }
    await context.read<AppData>().deleteVaultItem(widget.item!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: _editing ? 'Modifica password' : 'Nuova password',
      subtitle: 'Viene salvata cifrata: solo tu, con la tua password di accesso, puoi leggerla.',
      fields: [
        const FieldLabel('Nome'),
        TextField(
          controller: _title,
          autofocus: !_editing,
          decoration: const InputDecoration(hintText: 'es. Gmail, Netflix, Banca'),
        ),
        const FieldLabel('Sito web'),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(hintText: 'Facoltativo, es. https://mail.google.com'),
        ),
        const FieldLabel('Username o email'),
        TextField(controller: _username, autocorrect: false, decoration: const InputDecoration(hintText: 'Username o email')),
        const FieldLabel('Password'),
        TextField(
          controller: _password,
          obscureText: !_show,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: _show ? 'Nascondi' : 'Mostra',
                icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: VColors.muted),
                onPressed: () => setState(() => _show = !_show),
              ),
              IconButton(
                tooltip: 'Genera una password sicura',
                icon: const Icon(Icons.auto_awesome, color: VColors.accentLight),
                onPressed: () => setState(() {
                  _password.text = context.read<AppData>().generatePassword();
                  _show = true;
                }),
              ),
            ]),
          ),
        ),
        const FieldLabel('Note'),
        TextField(
          controller: _notes,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'Facoltative, es. domande di sicurezza, PIN...'),
        ),
        ErrorBox(_error),
      ],
      actions: [
        FilledButton(onPressed: _save, child: const Text('Salva')),
        if (_editing) ...[
          const SizedBox(height: 6),
          TextButton(
            onPressed: _delete,
            style: TextButton.styleFrom(foregroundColor: VColors.negative),
            child: Text(_confirmDelete ? 'Tocca di nuovo per confermare' : 'Elimina voce'),
          ),
        ],
      ],
    );
  }
}

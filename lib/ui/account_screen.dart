import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/app_data.dart';
import '../core/auth_service.dart';
import '../core/models.dart';
import 'avatar.dart';
import 'lock_screens.dart';
import 'phone_field.dart';
import 'sheets/profile_sheet.dart';
import 'theme.dart';
import 'widgets.dart';

/// "Il tuo account": avatar, username, contatti, password, codice di sicurezza, eliminazione.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  /// Apre la pagina sopra l'app (con i dati dell'utente).
  static Future<void> open(BuildContext context) {
    final data = context.read<AppData>();
    return Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider.value(value: data, child: const AccountScreen()),
    ));
  }

  Future<void> _photo(BuildContext context) async {
    final data = context.read<AppData>();
    // La scelta della foto va aperta nel tocco stesso (Safari la blocca se arriva dopo):
    // il pannello restituisce direttamente la foto in arrivo.
    final result = await showModalBottomSheet<Object>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Scegli una foto'),
            subtitle: const Muted('Dalla galleria, dalla fotocamera o dai file', size: 12),
            onTap: () => Navigator.pop(sheet, (pickPhoto(),)), // in una tupla: un Future verrebbe atteso
          ),
          if (data.avatar != null)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: VColors.negative),
              title: const Text('Togli la foto', style: TextStyle(color: VColors.negative)),
              onTap: () => Navigator.pop(sheet, 'remove'),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!context.mounted || result == null) return;
    if (result == 'remove') {
      await data.saveAvatar(null);
      return;
    }
    final original = await (result as (Future<Uint8List?>,)).$1;
    if (original == null || !context.mounted) return;
    final prepared = await squareAvatar(original);
    if (!context.mounted) return;
    if (prepared == null) {
      showToast(context, 'Non riesco a leggere questa immagine.', tone: 'warning');
      return;
    }
    await showSheet(context, _PhotoSheet(original: original, first: prepared));
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final since = DateFormat('d MMMM yyyy', 'it').format(data.createdAt);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Il tuo account'),
        backgroundColor: VColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Center(
            child: GestureDetector(
              onTap: () => _photo(context),
              child: Stack(clipBehavior: Clip.none, children: [
                UserAvatar(name: data.username, photo: data.avatar, color: data.avatarColor, size: 112),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: VColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: VColors.background, width: 3),
                    ),
                    child: const Icon(Icons.photo_camera, size: 18, color: Colors.white),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Text(data.username, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Muted('Su Vaultly dal $since', align: TextAlign.center, size: 12.5),
          if (data.avatar == null) ...[
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < kAvatarColors.length; i++)
                GestureDetector(
                  onTap: () => data.setAvatarColor(i),
                  child: Container(
                    key: Key('avatar-color-$i'),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Color(kAvatarColors[i]),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: i == data.avatarColorIndex ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 6),
            const Muted('Tocca l\'avatar per mettere una tua foto.', align: TextAlign.center, size: 12),
          ],
          const SizedBox(height: 24),
          const _Section('Profilo'),
          _Group(children: [
            _Row(
              icon: Icons.person_outline,
              label: 'Username',
              value: data.username,
              onTap: () => showSheet(context, const _UsernameSheet()),
            ),
            _Row(
              icon: Icons.mail_outline,
              label: 'Email',
              value: data.email.isEmpty ? '—' : data.email,
              onTap: () => showSheet(context, const ProfileSheet()),
            ),
            _Row(
              leading: data.phone.isEmpty ? null : Flag(data.phoneCountry, width: 20),
              icon: Icons.phone_outlined,
              label: 'Telefono',
              value: data.phone.isEmpty ? '—' : data.phoneFull,
              onTap: () => showSheet(context, const ProfileSheet()),
            ),
          ]),
          const SizedBox(height: 20),
          const _Section('Sicurezza'),
          _Group(children: [
            _Row(
              icon: Icons.password,
              label: 'Password',
              value: 'Cambia',
              onTap: () async {
                final changed = await showSheet<bool>(context, const _PasswordSheet());
                if (changed == true && context.mounted) {
                  // La chiave è cambiata: il codice va creato di nuovo.
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (route) => PopScope(
                      canPop: false,
                      child: PinSetupScreen(
                        save: data.changePin,
                        onDone: () => Navigator.pop(route),
                      ),
                    ),
                  ));
                  if (context.mounted) showToast(context, 'Password e codice aggiornati.');
                }
              },
            ),
            _Row(
              icon: Icons.dialpad,
              label: 'Codice di sicurezza',
              value: data.hasPin ? 'Cambia' : 'Crea',
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (route) => PinSetupScreen(
                  save: data.changePin,
                  onCancel: () => Navigator.pop(route),
                  onDone: () {
                    Navigator.pop(route);
                    showToast(context, 'Codice di sicurezza aggiornato.');
                  },
                ),
              )),
            ),
          ]),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Muted(
              'Tutto quello che vedi qui (anche la foto) è salvato solo su questo telefono, cifrato con la tua password.',
              size: 12,
            ),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () async {
              final deleted = await showSheet<bool>(context, const _DeleteSheet());
              if (deleted == true && context.mounted) {
                Navigator.of(context).pop();
                data.signOut?.call(); // l'utente non esiste più: si torna all'inizio
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: VColors.negative,
              side: BorderSide(color: VColors.negative.withValues(alpha: 0.5)),
            ),
            icon: const Icon(Icons.delete_forever_outlined, size: 19),
            label: const Text('Elimina account'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.fromLTRB(6, 0, 6, 8), child: Caption(text));
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => VCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 52),
            children[i],
          ],
        ]),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value, required this.onTap, this.leading});

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(children: [
            SizedBox(width: 22, child: Center(child: leading ?? Icon(icon, size: 20, color: VColors.muted))),
            const SizedBox(width: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 190),
              child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(value,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: VColors.muted)),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: VColors.faint, size: 20),
          ]),
        ),
      );
}

/// Anteprima della foto, con la possibilità di ruotarla prima di salvarla.
class _PhotoSheet extends StatefulWidget {
  const _PhotoSheet({required this.original, required this.first});
  final Uint8List original;
  final Uint8List first;

  @override
  State<_PhotoSheet> createState() => _PhotoSheetState();
}

class _PhotoSheetState extends State<_PhotoSheet> {
  late Uint8List _photo = widget.first;
  int _turns = 0;
  bool _busy = false;

  Future<void> _rotate() async {
    setState(() => _busy = true);
    final turns = (_turns + 1) % 4;
    final rotated = await squareAvatar(widget.original, quarterTurns: turns);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (rotated != null) {
        _turns = turns;
        _photo = rotated;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = context.read<AppData>();
    return SheetScaffold(
      title: 'La tua foto',
      subtitle: 'Viene ritagliata al centro e salvata solo su questo telefono, cifrata.',
      fields: [
        Center(child: UserAvatar(name: data.username, photo: _photo, size: 180)),
        const SizedBox(height: 14),
        Center(
          child: TextButton.icon(
            onPressed: _busy ? null : _rotate,
            icon: const Icon(Icons.rotate_right),
            label: const Text('Ruota'),
          ),
        ),
      ],
      actions: [
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  final error = await data.saveAvatar(_photo);
                  if (!context.mounted) return;
                  if (error != null) {
                    showToast(context, error, tone: 'warning');
                  } else {
                    Navigator.pop(context);
                  }
                },
          child: const Text('Usa questa foto'),
        ),
      ],
    );
  }
}

class _UsernameSheet extends StatefulWidget {
  const _UsernameSheet();

  @override
  State<_UsernameSheet> createState() => _UsernameSheetState();
}

class _UsernameSheetState extends State<_UsernameSheet> {
  late final _name = TextEditingController(text: context.read<AppData>().username);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = await context.read<AppData>().rename(_name.text);
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
        title: 'Username',
        subtitle: 'È il nome con cui scegli il tuo utente e accedi con la password.',
        fields: [
          TextField(
            controller: _name,
            autofocus: true,
            autocorrect: false,
            maxLength: AuthService.maxUsernameLength,
            decoration: const InputDecoration(hintText: 'Il tuo username', counterText: ''),
            onSubmitted: (_) => _save(),
          ),
          ErrorBox(_error),
        ],
        actions: [FilledButton(onPressed: _save, child: const Text('Salva'))],
      );
}

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet();

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final error = await context.read<AppData>().changePassword(_current.text, _new.text, _confirm.text);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
    } else {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
        title: 'Cambia password',
        subtitle: 'Dopo il cambio crei di nuovo il codice di sicurezza. '
            'Ricorda la nuova password: non si può recuperare.',
        fields: [
          const FieldLabel('Password attuale'),
          TextField(controller: _current, obscureText: true, autofocus: true),
          const FieldLabel('Nuova password'),
          TextField(
            controller: _new,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Almeno ${AuthService.minPasswordLength} caratteri'),
          ),
          const FieldLabel('Ripeti la nuova password'),
          TextField(controller: _confirm, obscureText: true, onSubmitted: (_) => _save()),
          ErrorBox(_error),
        ],
        actions: [
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2))
                : const Text('Cambia password'),
          ),
        ],
      );
}

class _DeleteSheet extends StatefulWidget {
  const _DeleteSheet();

  @override
  State<_DeleteSheet> createState() => _DeleteSheetState();
}

class _DeleteSheetState extends State<_DeleteSheet> {
  final _password = TextEditingController();
  String? _error;
  bool _confirm = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (!_confirm) {
      setState(() => _confirm = true);
      return;
    }
    final error = await context.read<AppData>().deleteUser(_password.text);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _error = error;
        _confirm = false;
      });
    } else {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.read<AppData>();
    return SheetScaffold(
      title: 'Elimina account',
      subtitle: 'Vengono cancellati da questo telefono l\'utente "${data.username}" e tutti i suoi dati: '
          'conti, movimenti, etichette, password salvate e foto. Non si può annullare.',
      fields: [
        const FieldLabel('Scrivi la tua password per confermare'),
        TextField(controller: _password, obscureText: true, autofocus: true),
        ErrorBox(_error),
      ],
      actions: [
        FilledButton(
          onPressed: _delete,
          style: FilledButton.styleFrom(backgroundColor: VColors.negative),
          child: Text(_confirm ? 'Tocca di nuovo per eliminare tutto' : 'Elimina account'),
        ),
      ],
    );
  }
}

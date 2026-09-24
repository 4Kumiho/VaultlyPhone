import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/auth_service.dart';
import '../data/local_store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Sei pallini e tastierino numerico. Alla sesta cifra chiama `onCompleted`: se restituisce
/// false il codice viene scosso e cancellato.
class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.onCompleted, this.enabled = true});

  final Future<bool> Function(String pin) onCompleted;
  final bool enabled;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _busy = false;
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _press(String digit) async {
    if (_busy || !widget.enabled || _pin.length >= AuthService.pinLength) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += digit);
    if (_pin.length < AuthService.pinLength) return;
    setState(() => _busy = true);
    final ok = await widget.onCompleted(_pin);
    if (!mounted) return;
    if (!ok) {
      HapticFeedback.heavyImpact();
      await _shake.forward(from: 0);
    }
    if (mounted) {
      setState(() {
        _pin = '';
        _busy = false;
      });
    }
  }

  void _delete() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedBuilder(
        animation: _shake,
        builder: (_, child) => Transform.translate(
          offset: Offset(sin(_shake.value * pi * 6) * 12 * (1 - _shake.value), 0),
          child: child,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < AuthService.pinLength; i++)
            AnimatedContainer(
              key: Key('pin-dot-$i'),
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(horizontal: 9),
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _pin.length ? VColors.accent : Colors.transparent,
                border: Border.all(color: i < _pin.length ? VColors.accent : VColors.borderStrong, width: 1.6),
              ),
            ),
        ]),
      ),
      SizedBox(
        height: 36,
        child: _busy
            ? const Center(
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
            : null,
      ),
      for (final row in const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
        ['', '0', '<'],
      ])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final key in row)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: key.isEmpty
                    ? const SizedBox(width: 74, height: 74)
                    : _Key(
                        label: key,
                        onTap: key == '<' ? _delete : () => _press(key),
                      ),
              ),
          ]),
        ),
    ]);
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final back = label == '<';
    return SizedBox(
      width: 74,
      height: 74,
      child: Material(
        color: back ? Colors.transparent : VColors.surfaceHigh,
        shape: const CircleBorder(),
        child: InkWell(
          key: Key('pin-key-$label'),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: back
                ? const Icon(Icons.backspace_outlined, color: VColors.muted, semanticLabel: 'Cancella')
                : Text(label, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );
  }
}

/// Cornice comune: logo, titolo, sottotitolo, contenuto, pulsanti in basso.
class _LockFrame extends StatelessWidget {
  const _LockFrame({required this.title, this.subtitle, required this.child, this.footer = const [], this.top});

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> footer;
  final Widget? top;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ?top,
                Center(child: Image.asset('assets/vaultly.png', width: 56, height: 56)),
                const SizedBox(height: 18),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Muted(subtitle!, align: TextAlign.center),
                ],
                const SizedBox(height: 26),
                child,
                const SizedBox(height: 12),
                ...footer,
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Scelta dell'utente all'apertura dell'app.
class UserPickerScreen extends StatelessWidget {
  const UserPickerScreen({
    super.key,
    required this.users,
    required this.onPick,
    required this.onNewUser,
    required this.onPassword,
  });

  final List<UserRecord> users;
  final ValueChanged<UserRecord> onPick;
  final VoidCallback onNewUser;
  final VoidCallback onPassword;

  @override
  Widget build(BuildContext context) {
    return _LockFrame(
      title: 'Chi sei?',
      subtitle: 'Scegli il tuo utente.',
      footer: [
        OutlinedButton.icon(onPressed: onNewUser, icon: const Icon(Icons.person_add_alt, size: 18), label: const Text('Nuovo utente')),
        const SizedBox(height: 4),
        TextButton(onPressed: onPassword, child: const Text('Accedi con username e password')),
      ],
      child: Column(children: [
        for (final u in users) ...[
          VCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            onTap: () => onPick(u),
            child: Row(children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: VColors.accent.withValues(alpha: 0.18),
                child: Text(u.username.characters.first.toUpperCase(),
                    style: const TextStyle(color: VColors.accentLight, fontWeight: FontWeight.w700, fontSize: 17)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.username, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600)),
                  Muted(u.hasPin ? 'Codice di sicurezza' : 'Password', size: 12.5),
                ]),
              ),
              Icon(u.hasPin ? Icons.dialpad : Icons.password, color: VColors.faint, size: 20),
            ]),
          ),
          const SizedBox(height: 10),
        ],
      ]),
    );
  }
}

/// Sblocco con il codice di 6 cifre.
class PinUnlockScreen extends StatefulWidget {
  const PinUnlockScreen({
    super.key,
    required this.auth,
    required this.user,
    required this.onSession,
    required this.onUsePassword,
    this.onOtherUsers,
  });

  final AuthService auth;
  final UserRecord user;
  final ValueChanged<Session> onSession;
  final ValueChanged<String?> onUsePassword; // con un avviso, se il codice è stato disattivato
  final VoidCallback? onOtherUsers;

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  String? _error;

  Future<bool> _check(String pin) async {
    final result = await widget.auth.unlockWithPin(widget.user.username, pin);
    if (!mounted) return false;
    if (result.session != null) {
      widget.onSession(result.session!);
      return true;
    }
    if (result.pinDisabled) {
      widget.onUsePassword(result.error);
      return false;
    }
    setState(() => _error = result.error);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return _LockFrame(
      title: 'Ciao, ${widget.user.username}',
      subtitle: 'Inserisci il tuo codice di sicurezza.',
      top: widget.onOtherUsers == null
          ? null
          : Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.onOtherUsers,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Utenti'),
              ),
            ),
      footer: [
        ErrorBox(_error),
        const SizedBox(height: 4),
        TextButton(onPressed: () => widget.onUsePassword(null), child: const Text('Ho dimenticato il codice · usa la password')),
      ],
      child: PinPad(onCompleted: _check),
    );
  }
}

/// Creazione (o cambio) del codice: lo si scrive due volte.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key, required this.save, required this.onDone, this.onCancel});

  /// Salva il codice (scritto due volte); restituisce un errore o null.
  final Future<String?> Function(String pin, String confirm) save;
  final VoidCallback onDone;
  final VoidCallback? onCancel; // solo quando si cambia un codice già attivo

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String? _first;
  String? _error;

  Future<bool> _entered(String pin) async {
    if (_first == null) {
      final problem = AuthService.pinProblem(pin);
      if (problem != null) {
        setState(() => _error = problem);
        return false;
      }
      setState(() {
        _first = pin;
        _error = null;
      });
      return true;
    }
    final error = await widget.save(_first!, pin);
    if (!mounted) return false;
    if (error == null) {
      widget.onDone();
      return true;
    }
    setState(() {
      _first = null;
      _error = error == 'I due codici non coincidono.' ? 'I due codici non coincidono: ricomincia.' : error;
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final repeat = _first != null;
    return _LockFrame(
      title: repeat ? 'Ripeti il codice' : 'Crea il codice di sicurezza',
      subtitle: repeat
          ? 'Scrivi di nuovo le stesse 6 cifre.'
          : 'D\'ora in poi per entrare ti basterà questo codice di 6 cifre, al posto della password.',
      top: widget.onCancel == null
          ? null
          : Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Annulla'),
              ),
            ),
      footer: [
        ErrorBox(_error),
        const SizedBox(height: 8),
        const Muted(
          'Dopo 5 codici sbagliati il codice si disattiva e serve la password. '
          'Il codice vale solo su questo telefono.',
          size: 12,
          align: TextAlign.center,
        ),
      ],
      child: PinPad(key: ValueKey(repeat), onCompleted: _entered),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_data.dart';
import '../core/auth_service.dart';
import '../data/local_store.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'lock_screens.dart';

enum _Stage { loading, users, pin, password, setupPin, home }

/// Radice dell'app. All'apertura: scelta dell'utente e codice di sicurezza (o password).
/// Dopo un accesso con password, se l'utente non ha ancora il codice, lo si crea.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.auth});
  final AuthService auth;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  _Stage _stage = _Stage.loading;
  List<UserRecord> _users = [];
  UserRecord? _user; // utente scelto per il codice
  Session? _session; // accesso fatto, codice ancora da creare
  AppData? _data;
  String _prefill = '';
  bool _register = false;
  String? _notice;

  AuthService get _auth => widget.auth;

  @override
  void initState() {
    super.initState();
    _start();
  }

  /// Schermata iniziale (anche dopo "Esci"): nessun utente → registrazione; altrimenti scelta dell'utente.
  Future<void> _start() async {
    final users = await _auth.users();
    if (!mounted) return;
    setState(() {
      _users = users;
      _data = null;
      _session = null;
      _notice = null;
      if (users.isEmpty) {
        _showPassword(register: true);
      } else {
        _stage = _Stage.users;
      }
    });
  }

  void _showPassword({String username = '', bool register = false, String? notice}) {
    _prefill = username;
    _register = register;
    _notice = notice;
    _stage = _Stage.password;
  }

  void _pick(UserRecord user) => setState(() {
        if (user.hasPin) {
          _user = user;
          _stage = _Stage.pin;
        } else {
          _showPassword(username: user.username);
        }
      });

  void _signedIn(Session session) => setState(() {
        if (session.user.hasPin) {
          _data = AppData(_auth, session)..signOut = _start;
          _stage = _Stage.home;
        } else {
          _session = session;
          _stage = _Stage.setupPin;
        }
      });

  Widget _screen() {
    switch (_stage) {
      case _Stage.loading:
        return const Scaffold(key: ValueKey('loading'));
      case _Stage.users:
        return UserPickerScreen(
          key: const ValueKey('users'),
          users: _users,
          onPick: _pick,
          onNewUser: () => setState(() => _showPassword(register: true)),
          onPassword: () => setState(() => _showPassword()),
        );
      case _Stage.pin:
        return PinUnlockScreen(
          key: ValueKey('pin-${_user!.id}'),
          auth: _auth,
          user: _user!,
          onSession: _signedIn,
          onUsePassword: (notice) => setState(() => _showPassword(username: _user!.username, notice: notice)),
          onOtherUsers: () => setState(() => _stage = _Stage.users),
        );
      case _Stage.password:
        return AuthScreen(
          key: ValueKey('password-$_prefill-$_register-$_notice'),
          auth: _auth,
          initialUsername: _prefill,
          startRegistering: _register,
          notice: _notice,
          onBack: _users.isEmpty ? null : () => setState(() => _stage = _Stage.users),
          onSession: _signedIn,
        );
      case _Stage.setupPin:
        return PinSetupScreen(
          key: const ValueKey('setup'),
          save: (pin, confirm) => _auth.setPin(_session!, pin, confirm),
          onDone: () => setState(() {
            _data = AppData(_auth, _session!)..signOut = _start;
            _session = null;
            _stage = _Stage.home;
          }),
        );
      case _Stage.home:
        final data = _data!;
        return ChangeNotifierProvider.value(
          key: ValueKey(data),
          value: data,
          child: HomeScreen(onLogout: _start),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      child: _screen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_data.dart';
import '../core/auth_service.dart';
import 'auth_screen.dart';
import 'home_screen.dart';

/// Radice dell'app: schermata di accesso oppure app dell'utente connesso, con una dissolvenza.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.auth});
  final AuthService auth;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppData? _data;

  @override
  Widget build(BuildContext context) {
    final data = _data;
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
      child: data == null
          ? AuthScreen(
              key: const ValueKey('auth'),
              auth: widget.auth,
              onSession: (s) => setState(() => _data = AppData(widget.auth, s)),
            )
          : ChangeNotifierProvider.value(
              key: ValueKey(data),
              value: data,
              child: HomeScreen(onLogout: () => setState(() => _data = null)),
            ),
    );
  }
}

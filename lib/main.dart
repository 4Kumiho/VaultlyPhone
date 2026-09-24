import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/auth_service.dart';
import 'data/crypto.dart';
import 'data/local_store.dart';
import 'demo.dart';
import 'ui/app_shell.dart';
import 'ui/theme.dart';

const appVersion = '1.0.0';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it'); // dati delle date inclusi nell'app, nessun download
  final store = await LocalStore.open();
  final auth = AuthService(store, VaultCrypto());
  if (demoMode) await seedDemo(auth);
  runApp(VaultlyApp(auth: auth));
}

class VaultlyApp extends StatelessWidget {
  const VaultlyApp({super.key, required this.auth});

  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vaultly',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('it', 'IT'),
      supportedLocales: const [Locale('it', 'IT')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: AppShell(auth: auth),
    );
  }
}

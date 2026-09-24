import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:vaultly_phone/core/app_data.dart';
import 'package:vaultly_phone/core/auth_service.dart';
import 'package:vaultly_phone/core/models.dart';
import 'package:vaultly_phone/data/crypto.dart';
import 'package:vaultly_phone/data/local_store.dart';
import 'package:vaultly_phone/ui/account_screen.dart';
import 'package:vaultly_phone/ui/app_shell.dart';
import 'package:vaultly_phone/ui/avatar.dart';
import 'package:vaultly_phone/ui/home_screen.dart';
import 'package:vaultly_phone/ui/privacy_screen.dart';
import 'package:vaultly_phone/ui/sheets/account_sheet.dart';
import 'package:vaultly_phone/ui/sheets/profile_sheet.dart';
import 'package:vaultly_phone/ui/sheets/tag_detail_sheet.dart';
import 'package:vaultly_phone/ui/sheets/tag_sheet.dart';
import 'package:vaultly_phone/ui/sheets/txn_sheet.dart';
import 'package:vaultly_phone/ui/sheets/vault_sheet.dart';
import 'package:vaultly_phone/ui/theme.dart';

/// Ogni schermata e ogni pannello si costruisce senza errori, con e senza dati.
void main() {
  late AppData data;

  setUpAll(() => initializeDateFormatting('it'));
  pinFlow();

  setUp(() async {
    final store = await LocalStore.openInMemory();
    final auth = AuthService(store, VaultCrypto(iterations: 1000));
    data = AppData(auth, (await auth.register(username: 'giulia', email: 'test@example.com', phone: '+39 333 1234567', password: 'segreto1', confirm: 'segreto1')).session!);
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // Come nell'app: il Provider sta dentro MaterialApp, quindi i pannelli (che si aprono sopra) non lo vedono.
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      locale: const Locale('it', 'IT'),
      supportedLocales: const [Locale('it', 'IT')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: ChangeNotifierProvider.value(value: data, child: child),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> withData() async {
    await data.saveAccount(name: 'Conto', currency: 'EUR', initialBalance: 10000);
    final acc = data.accounts.single.id;
    await data.saveTag(Tag(id: '', name: 'auto', unit: TagUnit.month, budget: 5000, currency: 'EUR'));
    await data.saveTag(Tag(id: '', name: 'Rimini', kind: TagKind.oneShot, start: DateTime.now().subtract(const Duration(days: 2)), span: TagSpan.week));
    await data.saveTransaction(Txn(
        id: '',
        accountId: acc,
        type: TxType.expense,
        categoryId: 8,
        amount: 4500,
        occurredAt: DateTime.now().subtract(const Duration(hours: 2)),
        tags: ['auto', 'Rimini']));
    await data.saveTransaction(Txn(
        id: '',
        accountId: acc,
        type: TxType.expense,
        categoryId: 8,
        amount: 3000,
        occurredAt: DateTime.now().subtract(const Duration(days: 40)),
        tags: ['auto']));
    await data.saveVaultItem(VaultItem(id: '', title: 'Gmail', password: 'pw', updatedAt: DateTime.now()));
  }

  testWidgets('home vuota e con dati, tutte le sezioni', (tester) async {
    await pump(tester, HomeScreen(onLogout: () {}));
    Navigator.of(tester.element(find.byType(HomeScreen))).maybePop(); // chiude il pannello del primo conto
    await tester.pumpAndSettle();
    await tester.runAsync(withData); // salvataggi cifrati: tempo reale, non simulato
    await tester.pumpAndSettle();
    for (final tab in ['Etichette', 'Password', 'Altro', 'Conti']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);

    // Ogni pulsante "+" apre il suo pannello, come nell'app.
    for (final (tab, button, title) in [
      ('Conti', 'Movimento', 'Nuovo movimento'),
      ('Etichette', 'Etichetta', 'Nuova etichetta'),
      ('Password', 'Password', 'Nuova password'),
    ]) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FloatingActionButton, button));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: title);
      expect(find.text(title), findsOneWidget);
      Navigator.of(tester.element(find.text(title))).pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('il tuo account, con e senza foto', (tester) async {
    await pump(tester, const AccountScreen());
    expect(find.text('Il tuo account'), findsOneWidget);
    await tester.tap(find.byKey(const Key('avatar-color-2')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(data.avatarColorIndex, 2);

    // Una foto vera (PNG 600x400) ritagliata a quadrato.
    final png = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 600, 400), Paint()..color = const Color(0xFF3366FF));
      final image = await recorder.endRecording().toImage(600, 400);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final square = await squareAvatar(bytes!.buffer.asUint8List());
      final decoded = await (await ui.instantiateImageCodec(square!)).getNextFrame();
      expect((decoded.image.width, decoded.image.height), (avatarPixels, avatarPixels));
      await data.saveAvatar(square);
      return square;
    });
    expect(png, isNotNull);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('avatar-color-2')), findsNothing); // con la foto niente colori
    expect(tester.takeException(), isNull);
  });

  testWidgets('pagina I tuoi dati', (tester) async {
    await pump(tester, const PrivacyScreen());
    expect(find.text('I tuoi dati restano sul tuo telefono'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('Cosa devi sapere'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pannelli', (tester) async {
    await tester.runAsync(withData);
    final account = data.accounts.single;
    final txn = data.transactionsOf(account.id).first;
    final sheets = <Widget>[
      const AccountSheet(),
      AccountSheet(account: account),
      TxnSheet(account: account),
      TxnSheet(account: account, txn: txn),
      const TagSheet(),
      for (final t in data.tags) TagSheet(tag: t),
      for (final t in data.tags) TagDetailSheet(tagId: t.id),
      const TagSheet(initialName: 'autostrada'),
      const VaultSheet(),
      VaultSheet(item: data.vault.single),
      const ProfileSheet(),
    ];
    for (final sheet in sheets) {
      await pump(tester, Scaffold(body: SingleChildScrollView(child: sheet)));
      expect(tester.takeException(), isNull, reason: sheet.runtimeType.toString());
    }
  });
}

/// Percorso completo con il codice di sicurezza, come sul telefono.
void pinFlow() {
  testWidgets('registrazione, codice, uscita, codice sbagliato e giusto', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = (await tester.runAsync(LocalStore.openInMemory))!;
    final auth = AuthService(store, VaultCrypto(iterations: 1000));
    Future<void> settle() async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();
    }

    Future<void> typePin(String pin) async {
      for (final d in pin.split('')) {
        await tester.tap(find.byKey(Key('pin-key-$d')));
        await tester.pump();
      }
      await settle();
    }

    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      locale: const Locale('it', 'IT'),
      supportedLocales: const [Locale('it', 'IT')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: AppShell(auth: auth),
    ));
    await settle();

    // Nessun utente: si parte dalla registrazione.
    expect(find.text('Crea il tuo account'), findsOneWidget);
    final fields = find.byType(TextField);
    for (final (i, text) in ['giulia', 'giulia@esempio.it', '3331234567', 'segreto1', 'segreto1'].indexed) {
      await tester.enterText(fields.at(i), text);
    }
    await tester.tap(find.text('Crea account'));
    await settle();

    // Creazione del codice: troppo facile, poi diverso, poi giusto.
    expect(find.text('Crea il codice di sicurezza'), findsOneWidget);
    await typePin('123456');
    expect(find.textContaining('Troppo facile'), findsOneWidget);
    await typePin('274913');
    expect(find.text('Ripeti il codice'), findsOneWidget);
    await typePin('274910');
    expect(find.textContaining('non coincidono'), findsOneWidget);
    await typePin('274913');
    await typePin('274913');
    expect(find.text('Conti'), findsWidgets); // dentro l'app
    // Chiude il pannello del primo conto ed esce.
    Navigator.of(tester.element(find.byType(HomeScreen))).maybePop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Altro').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Esci'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Esci'));
    await settle();

    // Dopo "Esci": scelta dell'utente, poi il tastierino.
    expect(find.text('Chi sei?'), findsOneWidget);
    await tester.tap(find.text('giulia'));
    await tester.pumpAndSettle();
    expect(find.text('Ciao, giulia'), findsOneWidget);
    await typePin('111222');
    expect(find.textContaining('Restano 4 tentativi'), findsOneWidget);
    await typePin('274913');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

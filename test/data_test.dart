import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly_phone/core/analytics.dart';
import 'package:vaultly_phone/core/app_data.dart';
import 'package:vaultly_phone/core/auth_service.dart';
import 'package:vaultly_phone/core/models.dart';
import 'package:vaultly_phone/data/crypto.dart';
import 'package:vaultly_phone/data/local_store.dart';

void main() {
  late LocalStore store;
  late AuthService auth;
  // Poche iterazioni nei test (l'app usa 100.000).
  final crypto = VaultCrypto(iterations: 1000);

  setUp(() async {
    store = await LocalStore.openInMemory();
    auth = AuthService(store, crypto);
  });
  tearDown(() => store.close());

  Future<AppData> registered([String name = 'mario']) async {
    final r = await auth.register(username: name, email: 'test@example.com', phone: '+39 333 1234567', password: 'segreto1', confirm: 'segreto1');
    expect(r.error, isNull);
    return AppData(auth, r.session!);
  }

  Txn expense(String accountId, int amount, {List<String> tags = const []}) => Txn(
        id: '',
        accountId: accountId,
        type: TxType.expense,
        categoryId: 7,
        amount: amount,
        occurredAt: DateTime(2026, 9, 20, 10),
        tags: List.of(tags),
      );

  group('Cifratura', () {
    test('andata e ritorno, chiave sbagliata, manomissione', () async {
      final key = crypto.randomBytes(32);
      final blob = await crypto.encrypt(key, utf8.encode('segreto àèì'));
      expect(utf8.decode((await crypto.decrypt(key, blob))!), 'segreto àèì');
      expect(await crypto.decrypt(crypto.randomBytes(32), blob), isNull);
      final tampered = List.of(blob)..[14] ^= 1;
      expect(await crypto.decrypt(key, tampered), isNull);
    });
  });

  group('Accesso', () {
    test('registrazione e login', () async {
      final r = await auth.register(username: '  Mario ', email: 'test@example.com', phone: '+39 333 1234567', password: 'segreto1', confirm: 'segreto1');
      expect(r.session!.user.username, 'Mario');
      final l = await auth.login('mario', 'segreto1');
      expect(l.error, isNull);
      expect(l.session!.user.id, r.session!.user.id);
    });
    test('errori', () async {
      expect((await auth.register(username: '', email: 'test@example.com', phone: '+39 333 1234567', password: 'segreto1', confirm: 'segreto1')).error, isNotNull);
      expect((await auth.register(username: 'mario', email: 'test@example.com', phone: '+39 333 1234567', password: 'abc', confirm: 'abc')).error, isNotNull);
      expect((await auth.register(username: 'mario', email: 'test@example.com', phone: '+39 333 1234567', password: 'segreto1', confirm: 'segreto2')).error, isNotNull);
      await auth.register(username: 'mario', email: 'test@example.com', phone: '+39 333 1234567', password: 'segreto1', confirm: 'segreto1');
      expect((await auth.register(username: 'MARIO', email: 'test@example.com', phone: '+39 333 1234567', password: 'altrapass', confirm: 'altrapass')).error, isNotNull);
      expect((await auth.login('mario', 'sbagliata')).error, 'Username o password errati.');
      expect((await auth.login('nessuno', 'segreto1')).error, 'Username o password errati.');
    });
    test('email e telefono: obbligatori, controllati e ripuliti', () async {
      Future<String?> reg(String email, String phone) async => (await auth.register(
              username: 'x\$email\$phone', email: email, phone: phone, password: 'segreto1', confirm: 'segreto1'))
          .error;
      expect(await reg('', '+39 333 1234567'), isNotNull);
      expect(await reg('senza-chiocciola.it', '+39 333 1234567'), isNotNull);
      expect(await reg('a@b', '+39 333 1234567'), isNotNull);
      expect(await reg('mario@example.com', ''), isNotNull);
      expect(await reg('mario@example.com', '123'), isNotNull); // troppo corto
      expect(await reg('mario@example.com', '333-abc-4567'), isNotNull);
      expect(await reg('mario@example.com', '+39 12345678901234'), isNotNull); // oltre 15 cifre col prefisso

      final r = await auth.register(
          username: 'mario', email: '  Mario@Example.COM ', phone: '+39 333-123 45.67', password: 'segreto1', confirm: 'segreto1');
      expect(r.error, isNull);
      final d = AppData(auth, (await auth.login('mario', 'segreto1')).session!);
      expect(d.email, 'mario@example.com');
      expect(d.phoneCountry, 'IT');
      expect(d.phone, '3331234567'); // il +39 scritto a mano viene tolto
      expect(d.phoneFull, '+39 3331234567');
      expect(await d.saveProfile(email: 'nuova@example.com', phoneCountry: 'CH', phone: '0041 79 123 45 67'), isNull);
      expect(await d.saveProfile(email: 'sbagliata', phoneCountry: 'IT', phone: '02 1234567'), isNotNull);
      expect(await d.saveProfile(email: 'nuova@example.com', phoneCountry: 'XX', phone: '02 1234567'), isNotNull);
      final again = AppData(auth, (await auth.login('mario', 'segreto1')).session!);
      expect(again.email, 'nuova@example.com');
      expect(again.phoneCountry, 'CH');
      expect(again.phoneFull, '+41 791234567');
    });

    test('nel archivio non resta nulla in chiaro', () async {
      final data = await registered();
      await data.saveAccount(name: 'Conto segreto', currency: 'EUR', initialBalance: 123456);
      final vaultErr = await data.saveVaultItem(
          VaultItem(id: '', title: 'Gmail', username: 'mario@example.com', password: 'Sup3r!', updatedAt: DateTime.now()));
      expect(vaultErr, isNull);
      final raw = (await store.findUser('mario'))!.toMap().toString();
      for (final secret in ['Conto segreto', 'Gmail', 'Sup3r!', 'mario@example.com', 'segreto1', 'test@example.com', '3331234567']) {
        expect(raw.contains(secret), isFalse, reason: secret);
      }
    });
    test('i dati sopravvivono al nuovo accesso', () async {
      final data = await registered();
      await data.saveAccount(name: 'Conto', currency: 'EUR', initialBalance: 10000);
      final again = AppData(auth, (await auth.login('mario', 'segreto1')).session!);
      expect(again.accounts.single.name, 'Conto');
      expect(again.balanceOf(again.accounts.single), 10000);
    });
    test('utenti separati', () async {
      final mario = await registered('mario');
      await mario.saveAccount(name: 'Conto di Mario', currency: 'EUR', initialBalance: 0);
      final anna = await registered('anna');
      expect(anna.accounts, isEmpty);
      final marioAgain = AppData(auth, (await auth.login('mario', 'segreto1')).session!);
      expect(marioAgain.accounts.single.name, 'Conto di Mario');
    });
  });

  group('Codice di sicurezza', () {
    Future<Session> login(String name) async => (await auth.login(name, 'segreto1')).session!;

    test('regole del codice', () {
      expect(AuthService.pinProblem('12345'), isNotNull); // corto
      expect(AuthService.pinProblem('12a456'), isNotNull);
      expect(AuthService.pinProblem('111111'), isNotNull);
      expect(AuthService.pinProblem('123456'), isNotNull);
      expect(AuthService.pinProblem('987654'), isNotNull);
      expect(AuthService.pinProblem('901234'), isNotNull); // in fila anche passando da 9 a 0
      expect(AuthService.pinProblem('274913'), isNull);
    });

    test('si attiva e apre i dati come la password', () async {
      final d = await registered();
      await d.saveAccount(name: 'Conto', currency: 'EUR', initialBalance: 500);
      final session = await login('mario');
      expect(await auth.setPin(session, '274913', '274910'), 'I due codici non coincidono.');
      expect(await auth.setPin(session, '274913', '274913'), isNull);
      expect((await auth.users()).single.hasPin, isTrue);

      final r = await auth.unlockWithPin('MARIO', '274913');
      expect(r.error, isNull);
      expect(AppData(auth, r.session!).accounts.single.initialBalance, 500);
      // Nel record dell'utente il codice non c'è: solo byte cifrati.
      final user = (await auth.users()).single;
      expect(user.pinBlob!.length, greaterThan(32 + 16));
      expect(String.fromCharCodes(user.pinBlob!).contains('274913'), isFalse);
    });

    test('dopo 5 errori si disattiva e serve la password', () async {
      await registered();
      await auth.setPin(await login('mario'), '274913', '274913');
      for (var i = 1; i < AuthService.maxPinFailures; i++) {
        final r = await auth.unlockWithPin('mario', '000001');
        expect(r.session, isNull);
        expect(r.pinDisabled, isFalse);
        expect(r.error, contains(i == AuthService.maxPinFailures - 1 ? 'Ultimo tentativo' : 'Restano'));
      }
      final last = await auth.unlockWithPin('mario', '274913'.replaceFirst('2', '3'));
      expect(last.pinDisabled, isTrue);
      expect((await auth.users()).single.hasPin, isFalse);
      // Anche il codice giusto ora non basta più.
      expect((await auth.unlockWithPin('mario', '274913')).session, isNull);
      expect((await auth.login('mario', 'segreto1')).session, isNotNull);
    });

    test('un codice giusto o la password azzerano gli errori', () async {
      await registered();
      await auth.setPin(await login('mario'), '274913', '274913');
      await auth.unlockWithPin('mario', '000001');
      await auth.unlockWithPin('mario', '000002');
      expect((await auth.users()).single.pinFailures, 2);
      expect((await auth.unlockWithPin('mario', '274913')).session, isNotNull);
      expect((await auth.users()).single.pinFailures, 0);
      await auth.unlockWithPin('mario', '000003');
      await auth.login('mario', 'segreto1');
      expect((await auth.users()).single.pinFailures, 0);
    });

    test('senza la chiave del dispositivo il codice non serve', () async {
      await registered();
      await auth.setPin(await login('mario'), '274913', '274913');
      // Stesso archivio, altro "dispositivo": la chiave del browser non c'è.
      final other = AuthService(store, crypto);
      final r = await other.unlockWithPin('mario', '274913');
      expect(r.session, isNull);
      expect(r.pinDisabled, isTrue);
    });

    test('utenti separati, ognuno col suo codice', () async {
      await registered('mario');
      await registered('anna');
      await auth.setPin(await login('mario'), '274913', '274913');
      await auth.setPin(await login('anna'), '581736', '581736');
      expect((await auth.users()).map((u) => u.username), ['mario', 'anna']);
      expect((await auth.unlockWithPin('anna', '274913')).session, isNull);
      expect((await auth.unlockWithPin('anna', '581736')).session!.user.username, 'anna');
      expect((await auth.unlockWithPin('mario', '274913')).session!.user.username, 'mario');
    });
  });

  group('Dati', () {
    test('conti', () async {
      final d = await registered();
      expect(await d.saveAccount(name: '  ', initialBalance: 0), isNotNull);
      expect(await d.saveAccount(name: 'Carta', currency: 'EUR', initialBalance: 0), isNull);
      expect(await d.saveAccount(name: 'CARTA', currency: 'EUR', initialBalance: 0), isNotNull);
      final id = d.accounts.single.id;
      expect(await d.saveAccount(id: id, name: 'carta', initialBalance: 500), isNull);
      expect(d.accounts.single.initialBalance, 500);
    });

    test('movimenti, saldo ed eliminazione del conto', () async {
      final d = await registered();
      await d.saveAccount(name: 'Conto', currency: 'EUR', initialBalance: 10000);
      final acc = d.accounts.single;
      expect(await d.saveTransaction(expense(acc.id, 2500)), isNull);
      final income = expense(acc.id, 1000)
        ..type = TxType.income
        ..categoryId = 1;
      expect(await d.saveTransaction(income), isNull);
      expect(d.balanceOf(acc), 8500);
      expect(await d.saveTransaction(expense(acc.id, 0)), isNotNull);
      expect(await d.saveTransaction(expense(acc.id, 10)..categoryId = 1), isNotNull); // categoria di entrata

      final t = d.transactionsOf(acc.id).first..amount = 5000;
      expect(await d.saveTransaction(t), isNull);
      expect(await d.deleteAccount(acc.id), isNull);
      expect(d.accounts, isEmpty);
      expect(d.transactionsOf(acc.id), isEmpty);
    });

    test('etichette: vanno create prima, maiuscole, limiti, rinomina ed eliminazione', () async {
      final d = await registered();
      await d.saveAccount(name: 'Conto', currency: 'EUR', initialBalance: 0);
      final acc = d.accounts.single.id;
      expect(await d.saveTransaction(expense(acc, 1000, tags: ['Vacanza'])), contains('non esiste'));
      expect(await d.saveTag(Tag(id: '', name: '  #Vacanza ')), isNull);
      expect(await d.saveTag(Tag(id: '', name: 'roma')), isNull);
      expect(await d.saveTag(Tag(id: '', name: 'VACANZA')), isNotNull); // stesso nome
      expect(await d.saveTransaction(expense(acc, 1000, tags: ['  #vacanza ', 'roma'])), isNull);
      expect(await d.saveTransaction(expense(acc, 1000, tags: ['VACANZA'])), isNull);
      expect(d.tagNames, ['roma', 'Vacanza']);
      expect(d.transactionsOf(acc).map((t) => t.tags).toList(), [
        ['roma', 'Vacanza'],
        ['Vacanza'],
      ]);
      expect(await d.saveTransaction(expense(acc, 1, tags: ['x' * 31])), isNotNull);
      expect(await d.saveTransaction(expense(acc, 1, tags: [for (var i = 0; i < 11; i++) 'e$i'])), isNotNull);
      expect(await d.saveTag(Tag(id: '', name: 'zero', every: 0)), isNotNull);

      final vacanza = d.tags.firstWhere((t) => t.name == 'Vacanza')..name = 'Viaggio';
      expect(await d.saveTag(vacanza), isNull);
      expect(d.transactionsOf(acc).every((t) => !t.tags.contains('Vacanza')), isTrue);
      expect(d.tagUsage(d.tags.firstWhere((t) => t.name == 'Viaggio')), 2);

      expect(await d.deleteTag(d.tags.firstWhere((t) => t.name == 'Viaggio').id), isNull);
      expect(d.transactionsOf(acc).length, 2); // i movimenti restano
      expect(d.tagNames, ['roma']);
    });

    test('una tantum: solo sui movimenti tra le sue date', () async {
      final d = await registered();
      await d.saveAccount(name: 'Conto', currency: 'EUR', initialBalance: 0);
      final acc = d.accounts.single.id;
      // La spesa di prova è del 20 settembre 2026.
      expect(
          await d.saveTag(Tag(id: '', name: 'Rimini', kind: TagKind.oneShot, start: DateTime(2026, 9, 21), span: TagSpan.week)),
          isNull);
      final rimini = d.tagNamed('rimini')!;
      expect(rimini.end, DateTime(2026, 9, 27)); // una settimana
      expect(d.tagNamesFor(DateTime(2026, 9, 20)), isEmpty);
      expect(d.tagNamesFor(DateTime(2026, 9, 25)), ['Rimini']);
      expect(await d.saveTransaction(expense(acc, 1000, tags: ['Rimini'])), contains('vale solo dal 21/09/2026 al 27/09/2026'));

      rimini
        ..start = DateTime(2026, 9, 18)
        ..span = TagSpan.custom
        ..end = DateTime(2026, 9, 20);
      expect(await d.saveTag(rimini), isNull);
      expect(await d.saveTransaction(expense(acc, 1000, tags: ['Rimini'])), isNull);
      // Le nuove date escluderebbero il movimento già etichettato.
      rimini
        ..start = DateTime(2026, 9, 21)
        ..end = DateTime(2026, 9, 24);
      expect(await d.saveTag(rimini), contains('fuori da queste date'));
      rimini
        ..start = DateTime(2026, 9, 22)
        ..end = DateTime(2026, 9, 21);
      expect(await d.saveTag(rimini), isNotNull); // fine prima dell'inizio
    });

    test('tetto di spesa: validazione e stato', () async {
      final d = await registered();
      await d.saveAccount(name: 'Conto', currency: 'EUR', initialBalance: 0);
      final acc = d.accounts.single.id;
      expect(await d.saveTag(Tag(id: '', name: 'zero', budget: 0)), isNotNull);
      expect(await d.saveTag(Tag(id: '', name: 'valuta', budget: 100, currency: 'XYZ')), isNotNull);
      expect(
          await d.saveTag(Tag(
              id: '',
              name: 'viaggio',
              kind: TagKind.oneShot,
              start: DateTime(2026, 9, 20),
              end: DateTime(2026, 9, 30),
              budget: 3000)),
          isNull);
      await d.saveTransaction(expense(acc, 2500, tags: ['viaggio']));
      final s = d.budgetStatus(d.tags.single, now: DateTime(2026, 9, 23));
      expect(s.spent, 2500);
      expect(s.level, BudgetLevel.warning);

      expect(await d.saveTag(Tag(id: '', name: 'spesa', unit: TagUnit.week, budget: 2000)), isNull);
      await d.saveTransaction(expense(acc, 1500, tags: ['spesa']));
      final h = d.tagHistory(d.tagNamed('spesa')!, now: DateTime(2026, 9, 23));
      expect(h.first.spent, 0); // settimana nuova: si riparte da zero
      expect(h[1].spent, 1500); // 14–20 settembre
      expect(d.tagExpenses(d.tagNamed('spesa')!, h[1].from, h[1].to).single.amount, 1500);
    });

    test('etichette salvate e rilette (anche nel formato vecchio)', () async {
      final tag = Tag(id: '1', name: 'Rimini', kind: TagKind.oneShot, start: DateTime(2026, 9, 21), end: DateTime(2026, 9, 27), budget: 5);
      final back = Tag.fromJson(tag.toJson());
      expect((back.kind, back.start, back.end, back.budget), (TagKind.oneShot, tag.start, tag.end, 5));
      final r = Tag.fromJson({'id': '2', 'name': 'x', 'period': 'weekly'});
      expect((r.kind, r.unit), (TagKind.recurring, TagUnit.week));
      expect(Tag.fromJson({'id': '3', 'name': 'y', 'period': 'range', 'start': '2026-09-01T00:00:00.000'}).kind, TagKind.oneShot);
    });

    test('area password e generatore', () async {
      final d = await registered();
      expect(await d.saveVaultItem(VaultItem(id: '', title: ' ', password: 'x', updatedAt: DateTime.now())), isNotNull);
      expect(await d.saveVaultItem(VaultItem(id: '', title: 'Gmail', updatedAt: DateTime.now())), isNotNull);
      expect(await d.saveVaultItem(VaultItem(id: '', title: 'Gmail', password: 'pw', updatedAt: DateTime.now())), isNull);
      final pw = d.generatePassword();
      expect(pw.length, 20);
      expect(RegExp(r'[a-z]').hasMatch(pw) && RegExp(r'[A-Z]').hasMatch(pw) && RegExp(r'[0-9]').hasMatch(pw), isTrue);
      expect(RegExp(r'^[a-zA-Z0-9]+$').hasMatch(d.generatePassword(length: 12, symbols: false)), isTrue);
    });
  });
}

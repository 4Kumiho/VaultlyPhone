import 'dart:math';

import 'core/app_data.dart';
import 'core/auth_service.dart';
import 'core/models.dart';

/// Dati di esempio, SOLO nelle build di prova: `flutter build web --dart-define=VAULTLY_DEMO=true`.
/// Crea l'utente "giulia" (password "segreto1") se non esiste. Nelle build normali non viene incluso.
const demoMode = bool.fromEnvironment('VAULTLY_DEMO');

Future<void> seedDemo(AuthService auth) async {
  final r = await auth.register(username: 'giulia', email: 'giulia@esempio.it', phone: '+39 333 1234567', password: 'segreto1', confirm: 'segreto1');
  if (r.session == null) return; // esiste già
  final d = AppData(auth, r.session!);
  await d.saveAccount(name: 'Conto corrente', currency: 'EUR', initialBalance: 245075);
  await d.saveAccount(name: 'Carta', currency: 'EUR', initialBalance: 32000);
  final acc = d.accounts.firstWhere((a) => a.name == 'Conto corrente').id;
  final now = DateTime.now();
  final rng = Random(7);

  Future<void> add(int cat, int amount, DateTime when, String desc, [List<String> tags = const []]) async {
    if (when.isAfter(now)) return;
    final c = categoryFor(cat)!;
    await d.saveTransaction(Txn(
      id: '',
      accountId: acc,
      type: c.type,
      categoryId: cat,
      amount: amount,
      occurredAt: when,
      description: desc,
      tags: List.of(tags),
    ));
  }

  final today = DateTime(now.year, now.month, now.day);
  await d.saveTag(Tag(
    id: '',
    name: 'viaggio Roma',
    kind: TagKind.oneShot,
    start: today.subtract(const Duration(days: 3)),
    end: today.add(const Duration(days: 7)),
    budget: 30000,
    currency: 'EUR',
  ));
  await d.saveTag(Tag(id: '', name: 'autostrada', unit: TagUnit.month, budget: 6000, currency: 'EUR'));
  await d.saveTag(Tag(id: '', name: 'auto', unit: TagUnit.month, budget: 25000, currency: 'EUR'));
  await d.saveTag(Tag(id: '', name: 'spesa', unit: TagUnit.month, budget: 20000, currency: 'EUR'));
  await d.saveTag(Tag(id: '', name: 'cene fuori', unit: TagUnit.week, budget: 8000, currency: 'EUR'));
  await d.saveTag(Tag(id: '', name: 'casa', unit: TagUnit.month, currency: 'EUR'));

  for (var m = 5; m >= 0; m--) {
    DateTime at(int day, int hour) => DateTime(now.year, now.month - m, day, hour, 10);
    await add(1, 185000, at(27, 9), 'Stipendio');
    await add(6, 72000, at(2, 10), 'Affitto', ['casa']);
    for (var i = 0; i < 3; i++) {
      await add(7, 2500 + rng.nextInt(6000), at(1 + rng.nextInt(27), 9 + rng.nextInt(10)), 'Supermercato', ['spesa']);
    }
    for (var i = 0; i < 2 + rng.nextInt(4); i++) {
      await add(8, 800 + rng.nextInt(1800), at(1 + rng.nextInt(27), 8 + rng.nextInt(10)), 'Casello', ['autostrada']);
    }
  }
  await add(8, 8900, now.subtract(const Duration(days: 3)), 'Treno per Roma', ['viaggio Roma']);
  await add(12, 6400, now.subtract(const Duration(days: 2)), 'Cena a Trastevere', ['viaggio Roma', 'cene fuori']);
  await add(6, 18000, now.subtract(const Duration(days: 1)), 'Albergo', ['viaggio Roma']);
  await add(8, 15000, now.subtract(const Duration(days: 8)), 'Tagliando', ['auto']);
  await add(8, 5500, now.subtract(const Duration(days: 12)), 'Benzina', ['auto']);

  for (final v in [
    ('Gmail', 'https://mail.google.com', 'giulia@esempio.it'),
    ('Netflix', 'https://netflix.com', 'giulia@esempio.it'),
    ('Banca', 'https://www.banca.it', '40192837'),
  ]) {
    await d.saveVaultItem(
        VaultItem(id: '', title: v.$1, url: v.$2, username: v.$3, password: d.generatePassword(), updatedAt: now));
  }
}

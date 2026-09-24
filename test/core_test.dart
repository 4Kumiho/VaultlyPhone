import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly_phone/core/analytics.dart';
import 'package:vaultly_phone/core/models.dart';
import 'package:vaultly_phone/core/money.dart';

Txn tx(TxType type, int amount, DateTime when, {List<String> tags = const [], String account = 'a'}) => Txn(
      id: '${when.microsecondsSinceEpoch}$amount',
      accountId: account,
      type: type,
      categoryId: type == TxType.income ? 1 : 7,
      amount: amount,
      occurredAt: when,
      tags: List.of(tags),
    );

DateTime sep(int day, [int hour = 12]) => DateTime(2026, 9, day, hour);

void main() {
  group('Money', () {
    const eur = Currency('EUR', '€', 2);
    test('format', () {
      expect(Money.formatNumber(0, 2), '0,00');
      expect(Money.formatNumber(5, 2), '0,05');
      expect(Money.formatNumber(123456, 2), '1.234,56');
      expect(Money.formatNumber(-123456789, 2), '-1.234.567,89');
      expect(Money.formatNumber(15000, 0), '15.000');
      expect(Money.formatNumber(123456, 2, grouping: false), '1234,56');
      expect(Money.format(123456, eur), '1.234,56 €');
    });
    test('parse', () {
      expect(Money.parse('12', 2), 1200);
      expect(Money.parse('12,5', 2), 1250);
      expect(Money.parse('12.50', 2), 1250);
      expect(Money.parse('1.234', 2), 123400);
      expect(Money.parse('1.234,56', 2), 123456);
      expect(Money.parse('1,234.56', 2), 123456);
      expect(Money.parse('-50', 2), -5000);
      expect(Money.parse(' 1 000,00 ', 2), 100000);
      expect(Money.parse(',5', 2), 50);
      expect(Money.parse('1.500', 0), 1500);
      expect(Money.parse(Money.formatNumber(-9876543, 2), 2), -9876543);
    });
    test('parse rejects', () {
      for (final bad in ['', '-', '12a', '12 €', '12345678901234567']) {
        expect(Money.parse(bad, 2), isNull, reason: bad);
      }
    });
  });

  group('Saldo', () {
    final txs = [
      tx(TxType.expense, 300, sep(10)),
      tx(TxType.income, 1000, sep(5)),
      tx(TxType.expense, 200, sep(20)),
    ];
    test('balanceAt', () {
      expect(Analytics.balanceAt(500, txs, sep(1)), 500);
      expect(Analytics.balanceAt(500, txs, sep(5)), 1500);
      expect(Analytics.balanceAt(500, txs, sep(15)), 1200);
      expect(Analytics.balanceAt(500, txs, sep(30)), 1000);
    });
    test('steps', () {
      final p = Analytics.steps(500, txs, sep(8), sep(25));
      expect(p.length, 6);
      expect(p.first.balance, 1500);
      expect(p.map((x) => x.balance).toList(), [1500, 1500, 1200, 1200, 1000, 1000]);
      expect(p.last.time, sep(25));
    });
    test('totals', () {
      final t = Analytics.totals(txs, sep(1), sep(15));
      expect(t.income, 1000);
      expect(t.expense, 300);
    });
    test('periodStart', () {
      final now = sep(30);
      expect(Analytics.periodStart(Period.day, now, txs), sep(29));
      expect(Analytics.periodStart(Period.week, now, txs), sep(23));
      expect(Analytics.periodStart(Period.month, now, txs), DateTime(2026, 8, 30, 12));
      expect(Analytics.periodStart(Period.all, now, txs), sep(5));
    });
  });

  group('Etichette', () {
    test('expensesByTag', () {
      final txs = [
        tx(TxType.expense, 1000, sep(5), tags: ['vacanza', 'Roma']),
        tx(TxType.expense, 3000, sep(6), tags: ['Vacanza']),
        tx(TxType.expense, 700, sep(7)),
        tx(TxType.expense, 9999, sep(25), tags: ['vacanza']),
        tx(TxType.income, 5000, sep(6), tags: ['vacanza']),
      ];
      final r = Analytics.expensesByTag(txs, sep(1), sep(20));
      expect(r.tags.map((t) => t.tag).toList(), ['vacanza', 'Roma']);
      expect(r.tags[0].total, 4000);
      expect(r.tags[0].count, 2);
      expect(r.untagged.total, 700);
    });

    test('periodi delle etichette ricorrenti', () {
      final now = DateTime(2026, 9, 23, 15); // mercoledì
      (DateTime, DateTime) period(TagUnit unit, {int every = 1, DateTime? start, DateTime? at}) {
        final (from, to) = Analytics.periodAt(Tag(id: 'x', name: 'x', unit: unit, every: every, start: start ?? now), at ?? now);
        return (from, DateTime(to.year, to.month, to.day));
      }

      expect(period(TagUnit.day), (DateTime(2026, 9, 23), DateTime(2026, 9, 23)));
      expect(period(TagUnit.week), (DateTime(2026, 9, 21), DateTime(2026, 9, 27))); // da lunedì
      expect(period(TagUnit.month), (DateTime(2026, 9, 1), DateTime(2026, 9, 30)));
      expect(period(TagUnit.year), (DateTime(2026, 1, 1), DateTime(2026, 12, 31)));
      // Ogni N: si conta dal primo periodo scelto, anche all'indietro.
      final s = DateTime(2026, 9, 10);
      expect(period(TagUnit.day, every: 10, start: s), (DateTime(2026, 9, 20), DateTime(2026, 9, 29)));
      expect(period(TagUnit.day, every: 10, start: s, at: DateTime(2026, 9, 9)), (DateTime(2026, 8, 31), DateTime(2026, 9, 9)));
      expect(period(TagUnit.week, every: 2, start: s), (DateTime(2026, 9, 21), DateTime(2026, 10, 4)));
      expect(period(TagUnit.month, every: 3, start: DateTime(2026, 8, 15)), (DateTime(2026, 8, 1), DateTime(2026, 10, 31)));
      expect(period(TagUnit.month, every: 3, start: DateTime(2026, 8, 15), at: DateTime(2027, 1, 5)),
          (DateTime(2026, 11, 1), DateTime(2027, 1, 31)));
      // Cambio dell'ora legale (29 marzo 2026): i giorni restano giorni.
      expect(period(TagUnit.day, at: DateTime(2026, 3, 29, 12)), (DateTime(2026, 3, 29), DateTime(2026, 3, 29)));
      expect(period(TagUnit.week, at: DateTime(2026, 3, 30, 12)), (DateTime(2026, 3, 30), DateTime(2026, 4, 5)));
    });

    test('una tantum: durata e date consentite', () {
      final start = DateTime(2026, 9, 20);
      expect(Analytics.oneShotEnd(start, TagSpan.week, null), DateTime(2026, 9, 26));
      expect(Analytics.oneShotEnd(start, TagSpan.month, null), DateTime(2026, 10, 19));
      expect(Analytics.oneShotEnd(start, TagSpan.custom, DateTime(2026, 9, 22)), DateTime(2026, 9, 22));
      final trip = Tag(id: 't', name: 'Rimini', kind: TagKind.oneShot, start: start, end: DateTime(2026, 9, 22));
      expect(Analytics.fitsDate(trip, DateTime(2026, 9, 19, 23, 59)), isFalse);
      expect(Analytics.fitsDate(trip, DateTime(2026, 9, 20)), isTrue);
      expect(Analytics.fitsDate(trip, DateTime(2026, 9, 22, 23, 59)), isTrue);
      expect(Analytics.fitsDate(trip, DateTime(2026, 9, 23)), isFalse);
      expect(Analytics.fitsDate(Tag(id: 'r', name: 'r'), DateTime(1999)), isTrue); // ricorrente: sempre
    });

    test('storico di una ricorrente: periodi precedenti, ognuno ripartito da zero', () {
      final now = DateTime(2026, 9, 23, 15);
      final accounts = [Account(id: 'a', name: 'Conto', currency: 'EUR', initialBalance: 0, createdAt: now)];
      final tag = Tag(id: 'h', name: 'autostrada', unit: TagUnit.month, start: DateTime(2026, 9, 1), budget: 5000);
      final txs = [
        tx(TxType.expense, 1200, DateTime(2026, 7, 3), tags: ['autostrada']),
        tx(TxType.expense, 800, DateTime(2026, 7, 30), tags: ['autostrada']),
        tx(TxType.expense, 6000, DateTime(2026, 9, 2), tags: ['autostrada']),
        tx(TxType.income, 9999, DateTime(2026, 9, 3), tags: ['autostrada']),
      ];
      final h = Analytics.history(tag, accounts, txs, now);
      expect(h.map((s) => s.from).toList(), [DateTime(2026, 9, 1), DateTime(2026, 8, 1), DateTime(2026, 7, 1)]);
      expect(h.map((s) => s.spent).toList(), [6000, 0, 2000]);
      expect(h.map((s) => s.level).toList(), [BudgetLevel.over, BudgetLevel.ok, BudgetLevel.ok]);
      expect(h[1].finished, isTrue);
      expect(h[0].count, 1);
      // Una tantum: un solo periodo.
      final trip = Tag(id: 't', name: 'autostrada', kind: TagKind.oneShot, start: DateTime(2026, 7, 1), end: DateTime(2026, 7, 31));
      expect(Analytics.history(trip, accounts, txs, now).single.spent, 2000);
    });

    test('livelli', () {
      expect(Analytics.levelFor(799, 1000), BudgetLevel.ok);
      expect(Analytics.levelFor(800, 1000), BudgetLevel.warning);
      expect(Analytics.levelFor(1000, 1000), BudgetLevel.warning);
      expect(Analytics.levelFor(1001, 1000), BudgetLevel.over);
    });

    test('tetto di un viaggio: solo le sue date e la sua valuta', () {
      final now = DateTime(2026, 9, 23, 15);
      final accounts = [
        Account(id: 'eur', name: 'Conto', currency: 'EUR', initialBalance: 0, createdAt: now),
        Account(id: 'usd', name: 'Dollari', currency: 'USD', initialBalance: 0, createdAt: now),
      ];
      final trip = Tag(
        id: 't',
        name: 'viaggio Roma',
        kind: TagKind.oneShot,
        start: DateTime(2026, 9, 20),
        end: DateTime(2026, 9, 30),
        budget: 80000,
        currency: 'EUR',
      );
      final txs = [
        tx(TxType.expense, 30000, sep(20, 8), tags: ['viaggio Roma'], account: 'eur'),
        tx(TxType.expense, 40000, sep(22, 20), tags: ['Viaggio Roma'], account: 'eur'),
        tx(TxType.expense, 99999, sep(19, 23), tags: ['viaggio Roma'], account: 'eur'),
        tx(TxType.expense, 99999, sep(21), tags: ['viaggio Roma'], account: 'usd'),
      ];
      var s = Analytics.budgetStatus(trip, accounts, txs, now);
      expect(s.spent, 70000);
      expect(s.level, BudgetLevel.warning);
      txs.add(tx(TxType.expense, 15000, sep(30, 22), tags: ['viaggio Roma'], account: 'eur'));
      s = Analytics.budgetStatus(trip, accounts, txs, now);
      expect(s.level, BudgetLevel.over);
      expect(Analytics.budgetStatus(trip, accounts, txs, DateTime(2026, 10, 1)).finished, isTrue);
      expect(Analytics.budgetStatus(trip, accounts, txs, DateTime(2026, 9, 10)).upcoming, isTrue);
    });
  });
}

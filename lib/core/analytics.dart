import 'models.dart';

// Calcoli su saldo, periodi, etichette e tetti di spesa. Saldo e tetti come nel desktop;
// le etichette qui sono una tantum (tra due date) o ricorrenti (con storico dei periodi).

enum Period { day, week, month, halfYear, year, all }

class BalancePoint {
  const BalancePoint(this.time, this.balance);
  final DateTime time;
  final int balance;
}

class Totals {
  int income = 0;
  int expense = 0;
}

class TagSpending {
  TagSpending(this.tag);
  final String tag; // vuoto per "senza etichetta"
  int total = 0;
  int count = 0;
}

class TagReport {
  final List<TagSpending> tags = [];
  final TagSpending untagged = TagSpending('');
}

enum BudgetLevel { noBudget, ok, warning, over }

/// Spesa di un'etichetta in un periodo [from, to] (una tantum: tutta la sua durata).
class BudgetStatus {
  BudgetStatus({required this.from, required this.to});
  final DateTime from;
  final DateTime to; // ultimo istante compreso
  int spent = 0;
  int count = 0; // uscite contate
  int budget = 0;
  BudgetLevel level = BudgetLevel.noBudget;
  bool finished = false; // periodo concluso
  bool upcoming = false; // periodo non ancora iniziato

  double get ratio => budget > 0 ? spent / budget : 0;
}

class Analytics {
  /// Da questa quota del tetto scatta l'avviso "quasi al limite".
  static const warningRatio = 0.8;

  /// Saldo includendo i movimenti fino a `time` compreso.
  static int balanceAt(int initial, Iterable<Txn> txs, DateTime time) {
    var balance = initial;
    for (final t in txs) {
      if (!t.occurredAt.isAfter(time)) balance += t.signedAmount;
    }
    return balance;
  }

  static int currentBalance(Account account, Iterable<Txn> txs) =>
      account.initialBalance + txs.where((t) => t.accountId == account.id).fold(0, (s, t) => s + t.signedAmount);

  /// Serie a gradini tra `from` e `to`: un punto a `from`, due per ogni movimento
  /// (prima e dopo), uno finale a `to`.
  static List<BalancePoint> steps(int initial, List<Txn> txs, DateTime from, DateTime to) {
    final sorted = [...txs]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    var balance = balanceAt(initial, txs, from);
    final points = [BalancePoint(from, balance)];
    for (final t in sorted) {
      if (!t.occurredAt.isAfter(from) || t.occurredAt.isAfter(to)) continue;
      points.add(BalancePoint(t.occurredAt, balance));
      balance += t.signedAmount;
      points.add(BalancePoint(t.occurredAt, balance));
    }
    points.add(BalancePoint(to, balance));
    return points;
  }

  static Totals totals(Iterable<Txn> txs, DateTime from, DateTime to) {
    final totals = Totals();
    for (final t in txs) {
      if (t.occurredAt.isBefore(from) || t.occurredAt.isAfter(to)) continue;
      if (t.type == TxType.income) {
        totals.income += t.amount;
      } else {
        totals.expense += t.amount;
      }
    }
    return totals;
  }

  static DateTime periodStart(Period period, DateTime now, List<Txn> txs) {
    switch (period) {
      case Period.day:
        return now.subtract(const Duration(days: 1));
      case Period.week:
        return now.subtract(const Duration(days: 7));
      case Period.month:
        return DateTime(now.year, now.month - 1, now.day, now.hour, now.minute);
      case Period.halfYear:
        return DateTime(now.year, now.month - 6, now.day, now.hour, now.minute);
      case Period.year:
        return DateTime(now.year - 1, now.month, now.day, now.hour, now.minute);
      case Period.all:
        if (txs.isEmpty) return DateTime(now.year, now.month - 1, now.day, now.hour, now.minute);
        final earliest = txs.map((t) => t.occurredAt).reduce((a, b) => a.isBefore(b) ? a : b);
        final dayBefore = now.subtract(const Duration(days: 1));
        return earliest.isBefore(dayBefore) ? earliest : dayBefore;
    }
  }

  /// Solo uscite in [from, to]; una spesa con più etichette conta in ciascuna.
  static TagReport expensesByTag(Iterable<Txn> txs, DateTime from, DateTime to) {
    final report = TagReport();
    final index = <String, TagSpending>{};
    for (final t in txs) {
      if (t.type != TxType.expense || t.occurredAt.isBefore(from) || t.occurredAt.isAfter(to)) continue;
      if (t.tags.isEmpty) {
        report.untagged
          ..total += t.amount
          ..count += 1;
        continue;
      }
      for (final tag in t.tags) {
        final s = index.putIfAbsent(tag.toLowerCase(), () {
          final created = TagSpending(tag);
          report.tags.add(created);
          return created;
        });
        s
          ..total += t.amount
          ..count += 1;
      }
    }
    report.tags.sort((a, b) =>
        a.total != b.total ? b.total.compareTo(a.total) : a.tag.toLowerCase().compareTo(b.tag.toLowerCase()));
    return report;
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  /// Giorni di calendario tra due date (senza sorprese col cambio dell'ora legale).
  static int _daysBetween(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

  static int _floorDiv(int a, int b) => (a / b).floor();

  /// Ultimo giorno di un'etichetta una tantum che dura `span` da `start`.
  static DateTime oneShotEnd(DateTime start, TagSpan span, DateTime? customEnd) => switch (span) {
        TagSpan.week => DateTime(start.year, start.month, start.day + 6),
        TagSpan.month => DateTime(start.year, start.month + 1, start.day - 1),
        TagSpan.custom => _day(customEnd ?? start),
      };

  /// Periodo [from, to] dell'etichetta che contiene `at`. Una tantum: sempre le sue date.
  static (DateTime, DateTime) periodAt(Tag tag, DateTime at) {
    if (!tag.recurring) return (_day(tag.start), _endOfDay(tag.end ?? tag.start));
    final n = tag.every < 1 ? 1 : tag.every;
    final anchor = _day(tag.start);
    final day = _day(at);
    DateTime first;
    DateTime next;
    switch (tag.unit) {
      case TagUnit.day:
        final k = _floorDiv(_daysBetween(anchor, day), n);
        first = DateTime(anchor.year, anchor.month, anchor.day + k * n);
        next = DateTime(anchor.year, anchor.month, anchor.day + (k + 1) * n);
      case TagUnit.week:
        final base = DateTime(anchor.year, anchor.month, anchor.day - (anchor.weekday - 1)); // lunedì
        final k = _floorDiv(_daysBetween(base, day), 7 * n);
        first = DateTime(base.year, base.month, base.day + k * 7 * n);
        next = DateTime(base.year, base.month, base.day + (k + 1) * 7 * n);
      case TagUnit.month:
        final k = _floorDiv((day.year - anchor.year) * 12 + day.month - anchor.month, n);
        first = DateTime(anchor.year, anchor.month + k * n, 1);
        next = DateTime(anchor.year, anchor.month + (k + 1) * n, 1);
      case TagUnit.year:
        final k = _floorDiv(day.year - anchor.year, n);
        first = DateTime(anchor.year + k * n, 1, 1);
        next = DateTime(anchor.year + (k + 1) * n, 1, 1);
    }
    return (first, _endOfDay(DateTime(next.year, next.month, next.day - 1)));
  }

  /// Vero se il movimento può avere l'etichetta: una tantum solo tra le sue date.
  static bool fitsDate(Tag tag, DateTime at) {
    if (tag.recurring) return true;
    final (from, to) = periodAt(tag, at);
    return !at.isBefore(from) && !at.isAfter(to);
  }

  static BudgetLevel levelFor(int spent, int budget) {
    if (budget <= 0) return BudgetLevel.noBudget;
    if (spent > budget) return BudgetLevel.over;
    if (spent >= budget * warningRatio) return BudgetLevel.warning;
    return BudgetLevel.ok;
  }

  /// Uscite con l'etichetta in [from, to], su tutti i conti nella valuta dell'etichetta.
  static BudgetStatus _spending(Tag tag, List<Account> accounts, Iterable<Txn> txs, DateTime from, DateTime to, DateTime now) {
    final status = BudgetStatus(from: from, to: to)
      ..finished = now.isAfter(to)
      ..upcoming = now.isBefore(from);
    final accountIds = {for (final a in accounts) if (a.currency == tag.currency) a.id};
    final name = tag.name.toLowerCase();
    for (final t in txs) {
      if (t.type != TxType.expense || !accountIds.contains(t.accountId)) continue;
      if (t.occurredAt.isBefore(from) || t.occurredAt.isAfter(to)) continue;
      if (t.tags.any((x) => x.toLowerCase() == name)) {
        status.spent += t.amount;
        status.count += 1;
      }
    }
    final budget = tag.budget;
    if (budget != null) {
      status
        ..budget = budget
        ..level = levelFor(status.spent, budget);
    }
    return status;
  }

  /// Periodo in corso (ricorrente) o intera durata (una tantum) rispetto al tetto.
  static BudgetStatus budgetStatus(Tag tag, List<Account> accounts, Iterable<Txn> txs, DateTime now) {
    final (from, to) = periodAt(tag, now);
    return _spending(tag, accounts, txs, from, to, now);
  }

  /// Storico di un'etichetta ricorrente: dal periodo in corso all'indietro fino al primo
  /// con una spesa (o a quello di inizio), al massimo `limit` periodi. Una tantum: un solo elemento.
  static List<BudgetStatus> history(Tag tag, List<Account> accounts, Iterable<Txn> txs, DateTime now, {int limit = 120}) {
    final current = budgetStatus(tag, accounts, txs, now);
    if (!tag.recurring) return [current];
    final name = tag.name.toLowerCase();
    var earliest = _day(tag.start);
    for (final t in txs) {
      if (t.type == TxType.expense && t.occurredAt.isBefore(earliest) && t.tags.any((x) => x.toLowerCase() == name)) {
        earliest = t.occurredAt;
      }
    }
    final list = [current];
    var from = current.from;
    while (list.length < limit && from.isAfter(earliest)) {
      final (f, t) = periodAt(tag, from.subtract(const Duration(milliseconds: 1)));
      list.add(_spending(tag, accounts, txs, f, t, now));
      from = f;
    }
    return list;
  }
}

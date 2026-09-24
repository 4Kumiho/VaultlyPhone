import 'package:intl/intl.dart';

import '../core/analytics.dart';
import '../core/models.dart';

// Date e testi in italiano.

String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String longDate(DateTime d) => capitalize(DateFormat('EEEE d MMMM yyyy', 'it').format(d));

String dayTitle(DateTime d, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final day = DateTime(d.year, d.month, d.day);
  final t = DateTime(today.year, today.month, today.day);
  if (day == t) return 'Oggi';
  if (day == t.subtract(const Duration(days: 1))) return 'Ieri';
  return capitalize(DateFormat(d.year == today.year ? 'EEEE d MMMM' : 'EEEE d MMMM yyyy', 'it').format(d));
}

String shortDate(DateTime d) =>
    DateFormat(d.year == DateTime.now().year ? 'd MMM' : 'd MMM yyyy', 'it').format(d);

String numericDate(DateTime d) => DateFormat('dd/MM/yyyy', 'it').format(d);

String timeOf(DateTime d) => DateFormat('HH:mm', 'it').format(d);

const periodShort = {
  Period.day: '1G',
  Period.week: '1S',
  Period.month: '1M',
  Period.halfYear: '6M',
  Period.year: '1A',
  Period.all: 'Tutto',
};

const periodLong = {
  Period.day: 'Ultime 24 ore',
  Period.week: 'Ultima settimana',
  Period.month: 'Ultimo mese',
  Period.halfYear: 'Ultimi 6 mesi',
  Period.year: 'Ultimo anno',
  Period.all: 'Da sempre',
};

// ---- Etichette ---------------------------------------------------------------------------

/// "Ogni mese", "Ogni 2 settimane", "Ogni 10 giorni"...
String recurrenceLabel(TagUnit unit, int every) {
  const one = {TagUnit.day: 'giorno', TagUnit.week: 'settimana', TagUnit.month: 'mese', TagUnit.year: 'anno'};
  const many = {TagUnit.day: 'giorni', TagUnit.week: 'settimane', TagUnit.month: 'mesi', TagUnit.year: 'anni'};
  return every <= 1 ? 'Ogni ${one[unit]}' : 'Ogni $every ${many[unit]}';
}

/// Nome di un periodo: "Settembre 2026", "2026", "Oggi", "22 – 28 set".
String tagPeriodLabel(Tag tag, DateTime from, DateTime to) {
  if (!tag.recurring) return '${shortDate(from)} – ${shortDate(to)}';
  if (tag.every == 1) {
    switch (tag.unit) {
      case TagUnit.day:
        return dayTitle(from);
      case TagUnit.month:
        return capitalize(DateFormat('MMMM yyyy', 'it').format(from));
      case TagUnit.year:
        return '${from.year}';
      case TagUnit.week:
        break;
    }
  }
  if (tag.unit == TagUnit.year) return '${from.year} – ${to.year}';
  return '${shortDate(from)} – ${shortDate(to)}';
}

/// Etichetta breve sotto le barre del grafico dello storico.
String tagBarLabel(Tag tag, DateTime from) => switch (tag.unit) {
      TagUnit.month => DateFormat(tag.every == 1 && from.month != 1 ? 'MMM' : 'MMM yy', 'it').format(from),
      TagUnit.year => '${from.year}',
      _ => DateFormat('d/M', 'it').format(from),
    };

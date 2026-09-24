import 'models.dart';

/// Importi come interi nelle unità minime della valuta. Formato italiano: "1.234,56 €".
/// Stesse regole del desktop (core/Money).
class Money {
  static const _group = '.';
  static const _decimal = ',';

  /// 123456 con 2 decimali → "1.234,56" (separatore delle migliaia sempre, anche con 4 cifre).
  static String formatNumber(int amount, int minorUnits, {bool grouping = true}) {
    final abs = amount.abs();
    final scale = _pow10(minorUnits);
    var integer = (abs ~/ scale).toString();
    if (grouping) {
      final buf = StringBuffer();
      for (var i = 0; i < integer.length; i++) {
        if (i > 0 && (integer.length - i) % 3 == 0) buf.write(_group);
        buf.write(integer[i]);
      }
      integer = buf.toString();
    }
    var text = integer;
    if (minorUnits > 0) text += _decimal + (abs % scale).toString().padLeft(minorUnits, '0');
    return amount < 0 ? '-$text' : text;
  }

  /// 123456 in EUR → "1.234,56 €".
  static String format(int amount, Currency currency) =>
      '${formatNumber(amount, currency.minorUnits)} ${currency.symbol}';

  /// Importo scritto dall'utente. Accetta sia ',' sia '.' come separatore decimale:
  /// l'ultimo separatore è decimale se seguito da al massimo `minorUnits` cifre, altrimenti è
  /// delle migliaia. "12,5" → 1250, "1.234" → 123400, "1.234,56" → 123456, "-50" → -5000.
  static int? parse(String text, int minorUnits) {
    var s = text.trim().replaceAll(' ', '').replaceAll(' ', '');
    var negative = false;
    if (s.startsWith('-') || s.startsWith('+')) {
      negative = s.startsWith('-');
      s = s.substring(1);
    }
    if (s.isEmpty || !RegExp(r'^[0-9.,]+$').hasMatch(s)) return null;

    var integerPart = s;
    var fraction = '';
    final lastSep = s.lastIndexOf(RegExp(r'[.,]'));
    if (lastSep >= 0 && minorUnits > 0) {
      final digitsAfter = s.length - lastSep - 1;
      if (digitsAfter >= 1 && digitsAfter <= minorUnits) {
        integerPart = s.substring(0, lastSep);
        fraction = s.substring(lastSep + 1);
      }
    }
    integerPart = integerPart.replaceAll(RegExp(r'[.,]'), '');
    if (fraction.contains(RegExp(r'[.,]'))) return null;
    if (integerPart.isEmpty) integerPart = '0';
    if (integerPart.length + minorUnits > 15) return null;

    final minor = minorUnits == 0 ? 0 : int.parse(fraction.padRight(minorUnits, '0'));
    final value = int.parse(integerPart) * _pow10(minorUnits) + minor;
    return negative ? -value : value;
  }

  static int _pow10(int n) {
    var r = 1;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }
}

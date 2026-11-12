/// Strict readers for what people type. No floating point for money.
library;

import 'phone_countries.dart';

/// Up to 9 digits and 2 decimals → centimes. Null when missing, malformed
/// or not strictly positive.
int? parseAmount(String text) {
  final normalized = text
      .replaceAll(RegExp(r'[\s  ]'), '')
      .replaceAll(RegExp('MAD', caseSensitive: false), '')
      .replaceAll(',', '.');
  if (!RegExp(r'^\d{1,9}(\.\d{1,2})?$').hasMatch(normalized)) return null;
  final parts = normalized.split('.');
  final cents =
      int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  return cents > 0 ? cents : null;
}

final _date = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');

/// JJ/MM/AAAA → a real calendar day (rejects 31/02), from 2000 to [today].
DateTime? parseDay(String text, {DateTime? today}) {
  final m = _date.firstMatch(text.trim());
  if (m == null) return null;
  final day = int.parse(m[1]!);
  final month = int.parse(m[2]!);
  final year = int.parse(m[3]!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  final now = today ?? DateTime.now();
  if (year < 2000 || date.isAfter(DateTime(now.year, now.month, now.day))) {
    return null;
  }
  return date;
}

/// 24000 → « 240,00 », the editable form of an amount.
String amountInput(int cents) =>
    '${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')}';

/// Mobile number → +212600000000, else null. A number typed without a
/// calling code is read as a number of [country]; one starting with + or 00
/// is international whatever the country chosen.
String? parsePhone(String text, {PhoneCountry country = morocco}) {
  var digits = text.replaceAll(RegExp(r'[\s().-]'), '');
  if (digits.startsWith('00')) digits = '+${digits.substring(2)}';
  if (!digits.startsWith('+')) return country.toInternational(digits);
  if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(digits)) return null;
  // A listed country keeps its own rules: +212 12 is not a number.
  final known = countryOf(digits);
  if (known == null) return digits;
  return known.toInternational(digits.substring(known.dial.length + 1));
}

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

bool isValidEmail(String text) => _email.hasMatch(text.trim());

/// The three password rules shown on the sign-up screen.
({bool length, bool mixed, bool special}) passwordRules(String p) => (
  length: p.length >= 8,
  mixed: RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(p) && RegExp(r'\d').hasMatch(p),
  special: RegExp(r'[^A-Za-zÀ-ÿ0-9\s]').hasMatch(p),
);

/// Display helpers for amounts and dates, French (Morocco) conventions.
library;

const _thinSpace = ' ';
const _months = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

/// 123456 centimes → « 1 234,56 MAD ».
String formatMad(int centimes) {
  final sign = centimes < 0 ? '−' : '';
  final abs = centimes.abs();
  final units = (abs ~/ 100).toString();
  final cents = (abs % 100).toString().padLeft(2, '0');
  final grouped = StringBuffer();
  for (var i = 0; i < units.length; i++) {
    if (i > 0 && (units.length - i) % 3 == 0) grouped.write(_thinSpace);
    grouped.write(units[i]);
  }
  return '$sign$grouped,$cents${_thinSpace}MAD';
}

/// 27 October 2026 → « 27 oct. 2026 ».
String formatDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

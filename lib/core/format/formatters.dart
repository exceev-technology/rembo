/// Display helpers for amounts and dates, French (Morocco) conventions;
/// Arabic keeps the same digits and order, with Moroccan month names.
library;

import '../l10n/l10n.dart';

// No-break space: the narrow one has no width in the Archivo face.
const _thinSpace = '\u00A0';
const _monthsAr = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'ماي',
  'يونيو',
  'يوليوز',
  'غشت',
  'شتنبر',
  'أكتوبر',
  'نونبر',
  'دجنبر',
];
const _weekdaysAr = [
  'الإثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];
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
  return '$sign$grouped,$cents$_thinSpace${tr('MAD')}';
}

/// 27 October 2026 → « 27 oct. 2026 ».
String formatDate(DateTime date) =>
    '${date.day} ${_short(date.month)} ${date.year}';

String _short(int month) =>
    isArabic ? _monthsAr[month - 1] : _months[month - 1];
String _long(int month) =>
    isArabic ? _monthsAr[month - 1] : _longMonths[month - 1];

const _longMonths = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];
const _weekdays = ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'];

/// 9 November 2026 → « 9 novembre 2026 ».
String formatDateLong(DateTime date) =>
    '${date.day} ${_long(date.month)} ${date.year}';

/// « Lun. 9 novembre 2026 ».
String formatWeekday(DateTime date) =>
    '${(isArabic ? _weekdaysAr : _weekdays)[date.weekday - 1]} '
    '${formatDateLong(date)}';

/// « Novembre 2026 ».
String formatMonth(DateTime date) {
  final m = _long(date.month);
  return '${m[0].toUpperCase()}${m.substring(1)} ${date.year}';
}

/// « 14:27 ».
String formatTime(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:'
    '${at.minute.toString().padLeft(2, '0')}';

/// « 09/11/2026 », the format typed in forms.
String formatDayInput(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

/// One short mention for lists: « Aujourd’hui », « Hier », then « 10 nov. »,
/// with the year only when it is not the current one.
String formatDayShort(DateTime date, {DateTime? today}) {
  final now = today ?? DateTime.now();
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(date.year, date.month, date.day)).inDays;
  if (days == 0) return tr('Aujourd’hui');
  if (days == 1) return tr('Hier');
  final short = '${date.day} ${_short(date.month)}';
  return date.year == now.year ? short : '$short ${date.year}';
}

/// « Aujourd’hui », « Hier », « Il y a 3 jours », then the date itself.
String formatRelativeDay(DateTime date, {DateTime? today}) {
  final now = today ?? DateTime.now();
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(date.year, date.month, date.day)).inDays;
  if (days == 0) return tr('Aujourd’hui');
  if (days == 1) return tr('Hier');
  if (days > 1 && days < 7) return tr('Il y a {days} jours', {'days': days});
  return formatDate(date);
}

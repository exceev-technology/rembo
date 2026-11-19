/// OCR bench: 30 fictional receipts of varying quality (Testing Protocol),
/// with the values a reader should find. The same comparison serves the
/// parser test (on the printed lines) and the bench screen (on the
/// pictures, read by the phone or the server).
library;

import 'dart:convert';

import '../data/models.dart';

/// The fields compared, in the order of the report.
const benchFields = [
  'supplier',
  'ice',
  'date',
  'amount',
  'vat',
  'rate',
  'currency',
];

class BenchCase {
  const BenchCase({
    required this.file,
    required this.quality,
    required this.language,
    required this.lines,
    required this.expected,
  });

  final String file;

  /// clean, blur, faded, tilt, crumpled, shadow, lowres, hand.
  final String quality;
  final String language;

  /// The lines printed on the receipt, top to bottom.
  final List<String> lines;

  /// supplier, ice, date (YYYY-MM-DD), amount and vat (centimes), rate,
  /// currency, category; null when the receipt does not print it.
  final Map<String, dynamic> expected;

  static List<BenchCase> parseManifest(String json) => [
    for (final r in (jsonDecode(json) as Map)['receipts'] as List)
      BenchCase(
        file: r['file'] as String,
        quality: r['quality'] as String,
        language: r['language'] as String,
        lines: [for (final l in r['lines'] as List) '$l'],
        expected: Map<String, dynamic>.from(r['expected'] as Map),
      ),
  ];
}

String _clean(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9؀-ۿ]'), '');

/// Field by field: did [reading] find what the receipt says? A field the
/// receipt does not print counts as right when the reader left it empty.
/// The supplier matches when one name contains the other (ignoring case,
/// accents aside, spaces and punctuation).
Map<String, bool> compareReading(ReceiptReading? reading, BenchCase c) {
  final e = c.expected;
  final r = reading == null || reading.unreadable
      ? const ReceiptReading()
      : reading;
  bool same(Object? got, Object? want) => '${got ?? ''}' == '${want ?? ''}';
  final supplierRead = _clean(r.supplier ?? '');
  final supplierWanted = _clean('${e['supplier'] ?? ''}');
  return {
    'supplier':
        supplierRead.isNotEmpty &&
        (supplierRead.contains(supplierWanted) ||
            supplierWanted.contains(supplierRead)),
    'ice': same(r.supplierIce, e['ice']),
    'date': same(r.date == null ? null : isoDay(r.date!), e['date']),
    'amount': same(r.amountCents, e['amount']),
    'vat': same(r.vatCents, e['vat']),
    'rate': same(r.vatRate, e['rate']),
    // A reader may stay silent on dirhams: MAD is the default.
    'currency': same(r.currency ?? 'MAD', e['currency']),
  };
}

class BenchResult {
  const BenchResult(this.benchCase, this.fields, {this.reading, this.time});
  final BenchCase benchCase;
  final Map<String, bool> fields;
  final ReceiptReading? reading;
  final Duration? time;

  int get right => fields.values.where((ok) => ok).length;
}

class BenchReport {
  BenchReport(this.engine, this.results);
  final String engine;
  final List<BenchResult> results;

  /// Share of receipts where [field] was right.
  double rate(String field) => results.isEmpty
      ? 0
      : results.where((r) => r.fields[field] ?? false).length / results.length;

  /// Share of every field of every receipt that was right.
  double get overall {
    final all = results.expand((r) => r.fields.values).toList();
    return all.isEmpty ? 0 : all.where((ok) => ok).length / all.length;
  }

  /// Same, per quality of picture (clean, blur…).
  Map<String, double> get byQuality {
    final groups = <String, List<BenchResult>>{};
    for (final r in results) {
      groups.putIfAbsent(r.benchCase.quality, () => []).add(r);
    }
    return {
      for (final g in groups.entries)
        g.key: BenchReport(engine, g.value).overall,
    };
  }

  /// One line per receipt, 1 for a right field and 0 for a wrong one.
  String toCsv() {
    final rows = [
      ['engine', 'file', 'quality', 'language', ...benchFields, 'ms'],
      for (final r in results)
        [
          engine,
          r.benchCase.file,
          r.benchCase.quality,
          r.benchCase.language,
          for (final f in benchFields) (r.fields[f] ?? false) ? '1' : '0',
          '${r.time?.inMilliseconds ?? ''}',
        ],
    ];
    return rows.map((r) => r.join(';')).join('\r\n');
  }
}

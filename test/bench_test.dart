import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/core/agents/ocr_bench.dart';
import 'package:rembo/core/ocr/receipt_parser.dart';

/// The parser on the printed lines of the 30 bench receipts: what the
/// reading agent would find if the phone's OCR read every character right.
/// Its scores are a floor to keep, not a promise on real photos (the bench
/// screen measures those on the phone).
void main() {
  final cases = BenchCase.parseManifest(
    File('assets/bench/manifest.json').readAsStringSync(),
  );
  final today = DateTime(2026, 11, 20);
  final latin = cases.where((c) => c.language == 'fr').toList();

  final report = BenchReport('parser', [
    for (final c in latin)
      BenchResult(
        c,
        compareReading(parseReceiptText(c.lines, today: today), c),
      ),
  ]);

  test('the bench has 30 receipts of every quality', () {
    expect(cases, hasLength(30));
    expect(
      cases.map((c) => c.quality).toSet(),
      containsAll([
        'clean',
        'blur',
        'faded',
        'tilt',
        'crumpled',
        'shadow',
        'lowres',
        'hand',
      ]),
    );
    expect(cases.where((c) => c.language == 'ar'), hasLength(2));
  });

  test('on the printed text, the parser keeps its scores', () {
    // ignore: avoid_print
    print(
      [for (final f in benchFields) '$f ${(report.rate(f) * 100).round()} %']
          .join(' · '),
    );
    expect(report.rate('amount'), 1.0);
    expect(report.rate('date'), 1.0);
    expect(report.rate('ice'), 1.0);
    expect(report.rate('vat'), 1.0);
    expect(report.rate('rate'), 1.0);
    expect(report.rate('currency'), 1.0);
    expect(report.rate('supplier'), greaterThanOrEqualTo(.9));
  });

  test('the report reads as one line per receipt', () {
    final csv = report.toCsv().split('\r\n');
    expect(csv.first, startsWith('engine;file;quality;language;supplier'));
    expect(csv, hasLength(latin.length + 1));
  });
}

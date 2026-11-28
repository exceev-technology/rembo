// OCR bench on a device: the 30 fictional receipts of assets/bench, read
// by the phone's own reader (Google ML Kit), scored field by field. The
// same measure as « Banc d’essai OCR » in the app, printed for the test
// report.
//
//   flutter test integration_test/bench_device_test.dart -d <phone>
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rembo/core/agents/ocr_bench.dart';
import 'package:rembo/core/data/models.dart';
import 'package:rembo/core/ocr/receipt_reader.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OCR bench: 30 receipts read on the phone', (tester) async {
    final reader = deviceReceiptReader;
    expect(reader, isNotNull, reason: 'No reader on this device.');
    final cases = BenchCase.parseManifest(
      await rootBundle.loadString('assets/bench/manifest.json'),
    );
    final results = <BenchResult>[];
    for (final c in cases) {
      final bytes = (await rootBundle.load('assets/bench/${c.file}')).buffer
          .asUint8List();
      final watch = Stopwatch()..start();
      ReceiptReading? reading;
      try {
        reading = await reader!(bytes, c.file);
      } catch (_) {
        reading = null;
      }
      watch.stop();
      final fields = compareReading(reading, c);
      results.add(
        BenchResult(c, fields, reading: reading, time: watch.elapsed),
      );
      // ignore: avoid_print
      print(
        'BENCH ${c.file} ${c.quality} ${c.language} '
        '${benchFields.map((f) => fields[f]! ? 1 : 0).join('')} '
        '${watch.elapsedMilliseconds}ms '
        'amount=${reading?.amountCents} date=${reading?.date} '
        'supplier=${reading?.supplier}',
      );
    }
    final report = BenchReport('device', results);
    String pc(double r) => '${(r * 100).round()} %';
    // ignore: avoid_print
    print(
      'BENCH TOTAL ${pc(report.overall)} · '
      '${benchFields.map((f) => '$f ${pc(report.rate(f))}').join(' · ')}',
    );
    // ignore: avoid_print
    print(
      'BENCH QUALITY ${report.byQuality.entries.map((e) => '${e.key} ${pc(e.value)}').join(' · ')}',
    );
    // ignore: avoid_print
    print('BENCH CSV\n${report.toCsv()}');
    expect(results, hasLength(30));
  });
}

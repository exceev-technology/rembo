import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../data/models.dart';
import 'receipt_parser.dart';
import 'receipt_reader.dart';

ReceiptReader? platformReceiptReader() =>
    Platform.isAndroid || Platform.isIOS ? _readWithMlKit : null;

RowsReader? platformRowsReader() =>
    Platform.isAndroid || Platform.isIOS ? _rowsWithMlKit : null;

/// Google ML Kit, Latin script: recognises the text on the phone, then
/// [parseReceiptText] finds the values in it.
Future<ReceiptReading?> _readWithMlKit(Uint8List bytes, String name) async {
  final rows = await _rowsWithMlKit(bytes, name);
  return rows == null ? null : parseReceiptText(rows);
}

/// The rows of text the phone recognises on a picture, top to bottom.
Future<List<String>?> _rowsWithMlKit(Uint8List bytes, String name) async {
  // ML Kit reads a file (it needs the photo's orientation): the picture
  // is written to the app's temporary folder and removed right after.
  final ext = name.contains('.') ? name.split('.').last : 'jpg';
  final file = File(
    '${Directory.systemTemp.path}/rembo-read-'
    '${DateTime.now().microsecondsSinceEpoch}.$ext',
  );
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    await file.writeAsBytes(bytes, flush: true);
    final text = await recognizer.processImage(
      InputImage.fromFilePath(file.path),
    );
    return rowsOf([
      for (final block in text.blocks)
        for (final line in block.lines)
          (
            text: line.text,
            left: line.boundingBox.left,
            top: line.boundingBox.top,
            bottom: line.boundingBox.bottom,
          ),
    ], slope: _slope(text));
  } on Object {
    return null;
  } finally {
    await recognizer.close();
    if (await file.exists()) await file.delete();
  }
}

/// How much the text climbs or falls per pixel across the picture: the
/// median slope of the long lines, from their corner points. A tilted
/// ticket otherwise puts an amount on the row of another label.
double _slope(RecognizedText text) {
  final slopes = <double>[];
  for (final block in text.blocks) {
    for (final line in block.lines) {
      final c = line.cornerPoints;
      if (c.length < 2) continue;
      final dx = (c[1].x - c[0].x).toDouble();
      if (dx < 80) continue;
      slopes.add((c[1].y - c[0].y) / dx);
    }
  }
  if (slopes.isEmpty) return 0;
  slopes.sort();
  return slopes[slopes.length ~/ 2];
}

typedef Piece = ({String text, double left, double top, double bottom});

/// A receipt is a table: the label is on the left and its amount far on
/// the right, and the recogniser returns them as separate pieces. Pieces
/// printed at the same height are put back on one row, left to right.
///
/// [slope] is how much the lines fall per pixel to the right: heights are
/// compared once the picture is set level.
List<String> rowsOf(List<Piece> pieces, {double slope = 0}) {
  double level(Piece p) => (p.top + p.bottom) / 2 - slope * p.left;
  final sorted = [...pieces]..sort((a, b) => level(a).compareTo(level(b)));
  final rows = <List<Piece>>[];
  for (final p in sorted) {
    final centre = level(p);
    final last = rows.isEmpty ? null : rows.last;
    if (last != null) {
      final ref = last.first;
      final refCentre = level(ref);
      final height = ref.bottom - ref.top;
      if ((centre - refCentre).abs() < height * .6) {
        last.add(p);
        continue;
      }
    }
    rows.add([p]);
  }
  return [
    for (final row in rows)
      (row..sort((a, b) => a.left.compareTo(b.left)))
          .map((p) => p.text)
          .join(' '),
  ];
}

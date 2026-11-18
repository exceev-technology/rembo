import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../data/models.dart';
import 'receipt_parser.dart';
import 'receipt_reader.dart';

ReceiptReader? platformReceiptReader() =>
    Platform.isAndroid || Platform.isIOS ? _readWithMlKit : null;

/// Google ML Kit, Latin script: recognises the text on the phone, then
/// [parseReceiptText] finds the values in it.
Future<ReceiptReading?> _readWithMlKit(Uint8List bytes, String name) async {
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
    return parseReceiptText(
      rowsOf([
        for (final block in text.blocks)
          for (final line in block.lines)
            (
              text: line.text,
              left: line.boundingBox.left,
              top: line.boundingBox.top,
              bottom: line.boundingBox.bottom,
            ),
      ]),
    );
  } on Object {
    return null;
  } finally {
    await recognizer.close();
    if (await file.exists()) await file.delete();
  }
}

typedef Piece = ({String text, double left, double top, double bottom});

/// A receipt is a table: the label is on the left and its amount far on
/// the right, and the recogniser returns them as separate pieces. Pieces
/// printed at the same height are put back on one row, left to right.
List<String> rowsOf(List<Piece> pieces) {
  final sorted = [...pieces]
    ..sort((a, b) => (a.top + a.bottom).compareTo(b.top + b.bottom));
  final rows = <List<Piece>>[];
  for (final p in sorted) {
    final centre = (p.top + p.bottom) / 2;
    final last = rows.isEmpty ? null : rows.last;
    if (last != null) {
      final ref = last.first;
      final refCentre = (ref.top + ref.bottom) / 2;
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

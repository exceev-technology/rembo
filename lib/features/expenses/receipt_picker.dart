import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/data/models.dart';
import '../../core/l10n/l10n.dart';
import '../../core/log.dart';

class PickedReceipt {
  const PickedReceipt(this.bytes, this.name, {this.pdfPages});
  final Uint8List bytes;
  final String name;

  /// Pages of the PDF it came from: only the first one is turned into the
  /// picture kept and read. Null for a photo.
  final int? pdfPages;
}

typedef ReceiptPicker = Future<PickedReceipt?> Function({required bool camera});

const maxReceiptBytes = 10 * 1024 * 1024;

/// How a receipt is obtained, given to the screens below it: the phone's
/// camera and gallery in the app, a picture handed over by a test.
class ReceiptPickerScope extends InheritedWidget {
  const ReceiptPickerScope({
    super.key,
    required this.picker,
    required super.child,
  });
  final ReceiptPicker picker;

  /// The picker above [context], or the phone's camera and gallery.
  static ReceiptPicker read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ReceiptPickerScope>()?.picker ??
      pickWithDevice;

  @override
  bool updateShouldNotify(ReceiptPickerScope oldWidget) =>
      picker != oldWidget.picker;
}

Future<PickedReceipt?> pickWithDevice({required bool camera}) async {
  final XFile? file;
  try {
    file = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
    );
  } catch (e, st) {
    logFailure('image picker', e, st);
    throw RemboException(
      camera
          ? tr('L’appareil photo n’est pas disponible sur cet appareil.')
          : tr('Impossible d’ouvrir la galerie sur cet appareil.'),
    );
  }
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  if (bytes.length > maxReceiptBytes) {
    throw RemboException(tr('Le fichier dépasse 10 Mo.'));
  }
  return PickedReceipt(bytes, file.name);
}

/// How a PDF receipt is obtained. Tests replace it.
Future<PickedReceipt?> Function() pdfPicker = pickPdfWithDevice;

/// A PDF invoice from the phone's files: its first page becomes the
/// picture of the receipt (PNG), which the reading agent then reads.
Future<PickedReceipt?> pickPdfWithDevice() async {
  final PlatformFile? file;
  try {
    file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
  } catch (_) {
    throw RemboException(
      tr('Impossible d’ouvrir vos fichiers sur cet appareil.'),
    );
  }
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  if (bytes.length > maxReceiptBytes) {
    throw RemboException(tr('Le fichier dépasse 10 Mo.'));
  }
  return pdfFirstPage(bytes, file.name);
}

/// The first page of [pdf] as a PNG picture, about 1 600 pixels wide.
Future<PickedReceipt> pdfFirstPage(Uint8List pdf, String name) async {
  try {
    final document = await PdfDocument.openData(pdf);
    try {
      final page = await document.getPage(1);
      final scale = 1600 / page.width;
      final image = await page.render(
        width: page.width * scale,
        height: page.height * scale,
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      await page.close();
      if (image == null) throw const FormatException();
      final base = name.toLowerCase().endsWith('.pdf')
          ? name.substring(0, name.length - 4)
          : name;
      return PickedReceipt(
        image.bytes,
        '$base.png',
        pdfPages: document.pagesCount,
      );
    } finally {
      await document.close();
    }
  } on RemboException {
    rethrow;
  } catch (_) {
    throw RemboException(tr('Ce PDF ne peut pas être lu. Essayez une photo.'));
  }
}

/// Bundled picture used by the demo when no camera is available.
Future<PickedReceipt> sampleReceipt({bool unreadable = false}) async {
  final data = await rootBundle.load('assets/images/receipt_art.webp');
  return PickedReceipt(
    data.buffer.asUint8List(),
    unreadable ? 'exemple-illisible.webp' : 'exemple.webp',
  );
}

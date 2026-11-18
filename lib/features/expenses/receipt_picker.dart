import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/data/models.dart';

class PickedReceipt {
  const PickedReceipt(this.bytes, this.name);
  final Uint8List bytes;
  final String name;
}

typedef ReceiptPicker = Future<PickedReceipt?> Function({required bool camera});

const maxReceiptBytes = 10 * 1024 * 1024;

/// How a receipt is obtained. Tests replace it; the app uses the phone's
/// camera and gallery.
ReceiptPicker receiptPicker = pickWithDevice;

Future<PickedReceipt?> pickWithDevice({required bool camera}) async {
  final XFile? file;
  try {
    file = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
    );
  } catch (_) {
    throw RemboException(
      camera
          ? 'L’appareil photo n’est pas disponible sur cet appareil.'
          : 'Impossible d’ouvrir la galerie sur cet appareil.',
    );
  }
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  if (bytes.length > maxReceiptBytes) {
    throw const RemboException('Le fichier dépasse 10 Mo.');
  }
  return PickedReceipt(bytes, file.name);
}

/// Bundled picture used by the demo when no camera is available.
Future<PickedReceipt> sampleReceipt({bool unreadable = false}) async {
  final data = await rootBundle.load('assets/images/receipt-art.webp');
  return PickedReceipt(
    data.buffer.asUint8List(),
    unreadable ? 'exemple-illisible.webp' : 'exemple.webp',
  );
}

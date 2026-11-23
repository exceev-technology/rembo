import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/data/models.dart';
import '../../core/l10n/l10n.dart';
import '../../core/log.dart';

class PickedReceipt {
  const PickedReceipt(this.bytes, this.name);
  final Uint8List bytes;
  final String name;
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

/// Bundled picture used by the demo when no camera is available.
Future<PickedReceipt> sampleReceipt({bool unreadable = false}) async {
  final data = await rootBundle.load('assets/images/receipt_art.webp');
  return PickedReceipt(
    data.buffer.asUint8List(),
    unreadable ? 'exemple-illisible.webp' : 'exemple.webp',
  );
}

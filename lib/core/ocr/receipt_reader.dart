import 'dart:typed_data';

import '../data/models.dart';
import 'device_reader_none.dart' if (dart.library.io) 'device_reader_io.dart';

/// Reads a receipt on the phone itself. Null result: nothing could be
/// read at all (no reader on this device, or it failed), the person types.
typedef ReceiptReader = Future<ReceiptReading?> Function(
  Uint8List bytes,
  String name,
);

/// The reader used by the capture screen. Tests replace it; on Android
/// and iOS it is Google ML Kit, which works without a network and never
/// sends the picture anywhere. Null where there is none (desktop, web).
ReceiptReader? deviceReceiptReader = platformReceiptReader();

/// The raw rows of text the phone recognises on a picture (diagnostic of
/// the OCR bench). Null where there is no reader.
typedef RowsReader = Future<List<String>?> Function(
  Uint8List bytes,
  String name,
);

RowsReader? deviceRowsReader = platformRowsReader();

/// Reads a receipt with the phone first, and asks the server's reader only
/// when the phone could not find the essentials (typically a receipt in
/// Arabic or handwritten, which the phone's reader does not know).
/// So most pictures never leave the phone.
///
/// [onServer] returns null when no server reader is configured.
Future<ReceiptReading?> readReceipt(
  Uint8List bytes,
  String name, {
  required ReceiptReader? onDevice,
  required ReceiptReader onServer,
}) async {
  final local = onDevice == null ? null : await onDevice(bytes, name);
  if (local != null && isComplete(local)) return local;
  final remote = await onServer(bytes, name);
  // No answer from the server (busy, out of quota, slow network, or no
  // server reader): that says nothing about the picture. The form opens
  // with what the phone found, never the « unreadable » screen.
  if (remote == null) return local == null || local.unreadable ? null : local;
  // The server found nothing either: keep whatever the phone had.
  if (remote.unreadable && local != null && !local.unreadable) return local;
  return remote;
}

/// Enough to pre-fill the form: who was paid and how much.
bool isComplete(ReceiptReading reading) =>
    !reading.unreadable &&
    reading.amountCents != null &&
    (reading.supplier?.trim().isNotEmpty ?? false);

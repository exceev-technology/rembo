import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../l10n/l10n.dart';
import 'local_store.dart';
import 'models.dart';

/// Encrypts what the on-device backend keeps (accounts, expenses, receipt
/// pictures) with AES-256-GCM before it reaches [inner]. The key lives in
/// the phone's key store (see openDeviceStore), never next to the files.
///
/// Data written before encryption existed is still read as it is, and is
/// encrypted the next time it is saved.
class EncryptedStore implements LocalStore {
  EncryptedStore(this.inner, this.key);
  final LocalStore inner;
  final SecretKey key;

  static final _cipher = AesGcm.with256bits();

  /// Marks an encrypted document; plain JSON starts with « { ».
  static const _documentMark = 'rembo-aes256gcm:';

  /// Marks an encrypted file: « RMB1 ».
  static final _blobMark = Uint8List.fromList([0x52, 0x4D, 0x42, 0x31]);

  Future<Uint8List> _seal(List<int> clear) async {
    final box = await _cipher.encrypt(clear, secretKey: key);
    return Uint8List.fromList(box.concatenation());
  }

  Future<List<int>> _open(List<int> sealed) async {
    try {
      final box = SecretBox.fromConcatenation(
        sealed,
        nonceLength: _cipher.nonceLength,
        macLength: _cipher.macAlgorithm.macLength,
      );
      return await _cipher.decrypt(box, secretKey: key);
    } on SecretBoxAuthenticationError {
      // Another key, or altered data: nothing can be read from it.
      throw RemboException(
        tr('Les données enregistrées sur ce téléphone sont illisibles.'),
      );
    }
  }

  @override
  Future<String?> read() async {
    final stored = await inner.read();
    if (stored == null || !stored.startsWith(_documentMark)) return stored;
    final sealed = base64Decode(stored.substring(_documentMark.length));
    return utf8.decode(await _open(sealed));
  }

  @override
  Future<void> write(String json) async {
    final sealed = await _seal(utf8.encode(json));
    await inner.write('$_documentMark${base64Encode(sealed)}');
  }

  @override
  Future<Uint8List?> readBlob(String name) async {
    final stored = await inner.readBlob(name);
    if (stored == null || !_isSealed(stored)) return stored;
    return Uint8List.fromList(await _open(stored.sublist(_blobMark.length)));
  }

  @override
  Future<void> writeBlob(String name, Uint8List bytes) async {
    final sealed = await _seal(bytes);
    await inner.writeBlob(name, Uint8List.fromList([..._blobMark, ...sealed]));
  }

  @override
  Future<void> deleteBlob(String name) => inner.deleteBlob(name);

  static bool _isSealed(Uint8List bytes) {
    if (bytes.length < _blobMark.length) return false;
    for (var i = 0; i < _blobMark.length; i++) {
      if (bytes[i] != _blobMark[i]) return false;
    }
    return true;
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../log.dart';
import 'encrypted_store.dart';
import 'local_store.dart';

/// Files in the app's private folder. The document is replaced in one
/// rename, so a crash never leaves it half written.
class FileStore implements LocalStore {
  FileStore(this.directory);
  final Directory directory;

  File get _document => File('${directory.path}/rembo.json');
  File _blob(String name) => File(
    '${directory.path}/receipts/${name.replaceAll(RegExp(r'[^\w.-]'), '_')}',
  );

  @override
  Future<String?> read() async =>
      await _document.exists() ? _document.readAsString() : null;

  @override
  Future<void> write(String json) async {
    await directory.create(recursive: true);
    final tmp = File('${_document.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(_document.path);
  }

  @override
  Future<Uint8List?> readBlob(String name) async {
    final f = _blob(name);
    return await f.exists() ? f.readAsBytes() : null;
  }

  @override
  Future<void> writeBlob(String name, Uint8List bytes) async {
    final f = _blob(name);
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> deleteBlob(String name) async {
    final f = _blob(name);
    if (await f.exists()) await f.delete();
  }
}

/// The app's files, encrypted with a key kept in the phone's key store
/// (Android Keystore, iOS Keychain).
Future<LocalStore?> openDeviceStore() async {
  final base = await getApplicationSupportDirectory();
  final files = FileStore(Directory('${base.path}/rembo'));
  try {
    return EncryptedStore(files, await _deviceKey());
  } catch (e, st) {
    // No key store on this device (rare): the data stays as before.
    logFailure('no key store: local data kept unencrypted', e, st);
    return files;
  }
}

/// Created once, on first use, and never written anywhere else.
Future<SecretKey> _deviceKey() async {
  const storage = FlutterSecureStorage();
  const name = 'rembo_local_store_key';
  var encoded = await storage.read(key: name);
  if (encoded == null) {
    final key = await AesGcm.with256bits().newSecretKey();
    encoded = base64Encode(await key.extractBytes());
    await storage.write(key: name, value: encoded);
  }
  return SecretKey(base64Decode(encoded));
}

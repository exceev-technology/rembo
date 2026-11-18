import 'dart:typed_data';

/// Where the on-device backend keeps its data: one JSON document and one
/// file per receipt.
abstract class LocalStore {
  Future<String?> read();
  Future<void> write(String json);
  Future<Uint8List?> readBlob(String name);
  Future<void> writeBlob(String name, Uint8List bytes);
  Future<void> deleteBlob(String name);
}

/// Kept in memory: tests, and platforms without a file system.
class MemoryStore implements LocalStore {
  String? document;
  final blobs = <String, Uint8List>{};

  @override
  Future<String?> read() async => document;
  @override
  Future<void> write(String json) async => document = json;
  @override
  Future<Uint8List?> readBlob(String name) async => blobs[name];
  @override
  Future<void> writeBlob(String name, Uint8List bytes) async =>
      blobs[name] = bytes;
  @override
  Future<void> deleteBlob(String name) async => blobs.remove(name);
}

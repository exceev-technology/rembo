import 'dart:math';

/// Random UUID v4. Created on the phone so that a request sent twice
/// (after a lost connection) designates the same row on the server.
String newUuid() {
  final r = Random.secure();
  String hex(int n) =>
      List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
  final variant = (8 + r.nextInt(4)).toRadixString(16);
  return '${hex(8)}-${hex(4)}-4${hex(3)}-$variant${hex(3)}-${hex(12)}';
}

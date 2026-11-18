import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend.dart';
import 'demo_backend.dart';
import 'demo_build.dart';
import 'local_store.dart';
import 'local_store_none.dart' if (dart.library.io) 'local_store_io.dart';
import 'supabase_backend.dart';

// Public client values only, given at build time:
//   flutter run --dart-define-from-file=.env
const _url = String.fromEnvironment('SUPABASE_URL');
const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const _ocr = bool.fromEnvironment('REMBO_OCR');
const _demo = bool.fromEnvironment('REMBO_DEMO');

/// Three ways to run, in this order:
///  1. Supabase, when a project is configured: shared between phones;
///  2. the fictional demo, with `REMBO_DEMO=true`, or in a debug build
///     without a file system (browser);
///  3. real accounts and expenses kept on this phone only.
/// A release build never starts the demo unless REMBO_DEMO=true.
Future<RemboBackend> createBackend() async {
  if (_url.isNotEmpty && _anonKey.isNotEmpty) {
    await Supabase.initialize(url: _url, publishableKey: _anonKey);
    return SupabaseBackend(Supabase.instance.client, receiptReader: _ocr);
  }
  final store = _demo ? null : await openDeviceStore();
  if (demoAllowed && store == null) return DemoBackend();
  return LocalBackend.open(store ?? MemoryStore());
}

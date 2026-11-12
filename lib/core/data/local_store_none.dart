import 'local_store.dart';

/// No file system here (browser): the app falls back to the demo.
Future<LocalStore?> openDeviceStore() async => null;

import 'package:flutter/material.dart';

import 'app/rembo_app.dart';
import 'core/data/app_state.dart';
import 'core/data/backend_factory.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(await createBackend());
  await state.restore();
  runApp(RemboApp(state: state));
}

import 'dart:io';

import 'package:flutter/foundation.dart';

/// The fictional demo (people, expenses, sample receipt) is part of debug
/// builds and tests, and of a release build only when asked for with
/// `--dart-define=REMBO_DEMO=true`. Otherwise this is false when the app is
/// compiled, and the compiler leaves the demo code out of the release.
const demoAllowed = !kReleaseMode || bool.fromEnvironment('REMBO_DEMO');

/// Tools for the team (the OCR bench): in tests, or when built with
/// --dart-define=REMBO_TOOLS=true. The debug APK handed to testers and to
/// the jury does not show them.
bool get teamTools =>
    const bool.fromEnvironment('REMBO_TOOLS') ||
    (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'));

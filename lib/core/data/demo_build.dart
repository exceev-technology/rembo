import 'package:flutter/foundation.dart';

/// The fictional demo (people, expenses, sample receipt) is part of debug
/// builds and tests, and of a release build only when asked for with
/// `--dart-define=REMBO_DEMO=true`. Otherwise this is false when the app is
/// compiled, and the compiler leaves the demo code out of the release.
const demoAllowed = !kReleaseMode || bool.fromEnvironment('REMBO_DEMO');

/// Tools for the team (the OCR bench): in test builds only, or when built
/// with --dart-define=REMBO_TOOLS=true. People using the app never see them.
const teamTools = !kReleaseMode || bool.fromEnvironment('REMBO_TOOLS');

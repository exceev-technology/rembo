import 'dart:developer' as developer;

/// Writes a failure the app recovers from (the person is not told, or is
/// told something simpler) to the device log, so that it can still be found.
void logFailure(String what, Object error, [StackTrace? stack]) =>
    developer.log(what, name: 'rembo', error: error, stackTrace: stack);

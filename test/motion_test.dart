import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/app/rembo_app.dart';
import 'package:rembo/core/data/app_state.dart';
import 'package:rembo/core/data/demo_backend.dart';
import 'package:rembo/features/onboarding/splash_screen.dart';

/// The other tests ask for reduced motion. These ones leave animations on:
/// the app must stay usable while things move, and nothing may throw.
void main() {
  testWidgets('With animations: welcome plays, pages slide, tabs fade', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(DemoBackend(latency: Duration.zero));
    await tester.pumpWidget(RemboApp(state: state));

    // Arrival, reading and stamp, frame by frame.
    for (var i = 0; i < 38; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('welcome-title')), findsOneWidget);

    // Turning the receipt with the finger, then letting it go.
    await tester.drag(find.byType(GestureDetector).first, const Offset(90, 30));
    await tester.pump(const Duration(seconds: 1));

    // The receipt is read again later in the loop.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(const ValueKey('welcome-login')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);

    // Signing in brings the home in; switching tabs fades.
    await tester.runAsync(() => state.signIn('marius@atlas-conseil.ma', 'x'));
    await tester.pumpWidget(RemboApp(key: UniqueKey(), state: state));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('tab-expenses')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Mes dépenses'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Opening: the logo waits for the app, then the light spreads', (
    tester,
  ) async {
    var ready = false;
    var done = 0;
    late StateSetter refresh;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: StatefulBuilder(
          builder: (context, setState) {
            refresh = setState;
            return SplashScreen(ready: ready, onDone: () => done++);
          },
        ),
      ),
    );
    // The logo has landed but the app is not ready: nothing ends.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(seconds: 2));
    expect(done, 0);

    refresh(() => ready = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 100));
    expect(done, 1);
    expect(tester.takeException(), isNull);
  });
}

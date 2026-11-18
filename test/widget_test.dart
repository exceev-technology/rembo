import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/app/app_router.dart';
import 'package:rembo/app/app_routes.dart';
import 'package:rembo/app/rembo_app.dart';

/// Some screens animate forever (welcome) or simulate a short loading
/// (receipt reading), so pumpAndSettle is not usable everywhere.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pump(const Duration(milliseconds: 600));
}

const title = ValueKey('destination-title');

void main() {
  test('Every destination is wired to its real screen', () {
    expect(
      AppRouter.screens.keys.toSet(),
      AppRoutes.destinations.map((d) => d.route).toSet(),
    );
  });

  testWidgets('Every destination opens from the menu and returns', (
    tester,
  ) async {
    await tester.pumpWidget(const RemboApp());
    for (final destination in AppRoutes.destinations) {
      final card = find.byKey(ValueKey('destination-${destination.route}'));
      await tester.ensureVisible(card);
      await tester.tap(card);
      await settle(tester);
      expect(find.byKey(title), findsOneWidget, reason: destination.route);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byKey(const ValueKey('navigation-menu')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Welcome leads to the real login screen', (tester) async {
    await tester.pumpWidget(const RemboApp(initialRoute: AppRoutes.welcome));
    await settle(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('welcome-start')));
    await tester.tap(find.byKey(const ValueKey('welcome-start')));
    await settle(tester);
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
  });

  testWidgets('Unknown destination offers recovery', (tester) async {
    await tester.pumpWidget(const RemboApp(initialRoute: '/inconnue'));
    await tester.pumpAndSettle();
    expect(find.text('Cet espace est introuvable'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('back-to-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('navigation-menu')), findsOneWidget);
  });

  testWidgets('All destinations also support direct entry', (tester) async {
    for (final destination in AppRoutes.destinations) {
      await tester.pumpWidget(
        RemboApp(key: UniqueKey(), initialRoute: destination.route),
      );
      await settle(tester);
      expect(find.byKey(title), findsOneWidget, reason: destination.route);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Narrow mobile and enlarged text do not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const RemboApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final destination in AppRoutes.destinations) {
      await tester.pumpWidget(
        RemboApp(key: UniqueKey(), initialRoute: destination.route),
      );
      await settle(tester);
      expect(tester.takeException(), isNull, reason: destination.route);
    }
  });
}

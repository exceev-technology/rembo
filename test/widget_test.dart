import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/app/app_router.dart';
import 'package:rembo/app/app_routes.dart';
import 'package:rembo/app/rembo_app.dart';

final placeholders = AppRoutes.destinations
    .where((d) => !AppRouter.screens.containsKey(d.route))
    .toList();

void main() {
  testWidgets('Every menu destination opens a placeholder and returns safely', (
    tester,
  ) async {
    await tester.pumpWidget(const RemboApp());
    for (final destination in placeholders) {
      final card = find.byKey(ValueKey('destination-${destination.route}'));
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('destination-title')), findsOneWidget);
      expect(find.text(destination.title), findsOneWidget);
      expect(find.text('Écran provisoire'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('back-to-menu')));
      await tester.tap(find.byKey(const ValueKey('back-to-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('navigation-menu')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('System back returns to the menu', (tester) async {
    await tester.pumpWidget(const RemboApp());
    await tester.ensureVisible(
      find.byKey(const ValueKey('destination-/connexion')),
    );
    await tester.tap(find.byKey(const ValueKey('destination-/connexion')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('navigation-menu')), findsOneWidget);
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
    for (final destination in placeholders) {
      await tester.pumpWidget(
        RemboApp(key: UniqueKey(), initialRoute: destination.route),
      );
      await tester.pumpAndSettle();
      expect(find.text(destination.title), findsOneWidget);
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
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('back-to-menu')));
      expect(tester.takeException(), isNull);
    }
  });
}

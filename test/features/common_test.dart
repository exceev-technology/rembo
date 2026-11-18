import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/app/app_router.dart';
import 'package:rembo/core/widgets/rembo_widgets.dart';
import 'package:rembo/features/common/demo_session.dart';
import 'package:rembo/features/common/screens/notifications_screen.dart';
import 'package:rembo/features/common/screens/profile_screen.dart';
import 'package:rembo/features/common/screens/settings_screen.dart';

Widget app(Widget home) => MaterialApp(
  theme: RemboTheme.light(),
  home: home,
  onGenerateRoute: AppRouter.onGenerateRoute,
);

/// Lists build lazily: scroll until the widget exists, then show it.
/// A negative [delta] scrolls back up.
Future<Finder> reveal(
  WidgetTester tester,
  String key, {
  double delta = 200,
}) async {
  final finder = find.byKey(ValueKey(key));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      delta,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  return finder;
}

Future<void> tapKey(
  WidgetTester tester,
  String key, {
  double delta = 200,
}) async {
  await tester.tap(await reveal(tester, key, delta: delta));
  await tester.pumpAndSettle();
}

Future<void> loaded(WidgetTester tester) async {
  await tester.pump(NotificationsScreen.loadingDelay);
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => demoOffline.value = false);

  testWidgets('Shared state views render their wording', (tester) async {
    await tester.pumpWidget(app(const EmptyState.noExpenses()));
    expect(find.text('Aucune dépense'), findsOneWidget);
    await tester.pumpWidget(app(const EmptyState.noNotifications()));
    expect(find.text('Aucune notification'), findsOneWidget);
    await tester.pumpWidget(app(const LoadingState()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(app(ErrorState(onRetry: () {})));
    expect(find.text('Réessayer'), findsOneWidget);
    await tester.pumpWidget(app(const Scaffold(body: OfflineBanner())));
    expect(find.textContaining('Pas de connexion internet'), findsOneWidget);
  });

  testWidgets('Settings open the profile and confirm preferences', (
    tester,
  ) async {
    await tester.pumpWidget(app(const SettingsScreen()));
    await tapKey(tester, 'pref-reminder');
    expect(find.text('Choix enregistré'), findsOneWidget);
    await tapKey(tester, 'open-profile', delta: -200);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text(DemoProfile.company), findsOneWidget);
  });

  testWidgets('Notifications load, are read, then cleared', (tester) async {
    await tester.pumpWidget(app(const NotificationsScreen()));
    expect(find.text('Chargement des notifications…'), findsOneWidget);
    await loaded(tester);
    expect(find.text('2 non lues'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('notifications-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mark-read')));
    await tester.pumpAndSettle();
    expect(find.text('Tout est lu.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('notifications-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('clear-all')));
    await tester.pumpAndSettle();
    expect(find.text('Aucune notification'), findsOneWidget);
  });

  testWidgets('Offline shows a banner, an error, then recovers', (
    tester,
  ) async {
    demoOffline.value = true;
    await tester.pumpWidget(app(const NotificationsScreen()));
    await loaded(tester);
    expect(find.byType(OfflineBanner), findsOneWidget);
    expect(find.text('Notifications indisponibles'), findsOneWidget);
    demoOffline.value = false;
    await tester.tap(find.byKey(const ValueKey('retry')));
    await loaded(tester);
    expect(find.byType(OfflineBanner), findsNothing);
    expect(find.text('2 non lues'), findsOneWidget);
  });

  testWidgets('Logging out returns to the login route', (tester) async {
    await tester.pumpWidget(app(const SettingsScreen()));
    await tapKey(tester, 'logout');
    expect(find.text('Connexion'), findsWidgets);
  });

  testWidgets('Screens fit a narrow phone with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    demoOffline.value = true;
    await tester.pumpWidget(app(const SettingsScreen()));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(app(const ProfileScreen()));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(app(const NotificationsScreen()));
    await loaded(tester);
    expect(tester.takeException(), isNull);
  });
}

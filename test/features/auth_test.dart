import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/app/app_router.dart';
import 'package:rembo/core/theme/rembo_theme.dart';
import 'package:rembo/features/auth/auth_validation.dart';
import 'package:rembo/features/auth/login_screen.dart';

Widget app() => MaterialApp(
  theme: RemboTheme.light(),
  home: const LoginScreen(),
  onGenerateRoute: AppRouter.onGenerateRoute,
);

void main() {
  test('E-mail and password checks', () {
    expect(AuthValidation.email(''), isNotNull);
    expect(AuthValidation.email('nom@'), isNotNull);
    expect(AuthValidation.email(' amina@atlas.ma '), isNull);
    expect(AuthValidation.password(''), isNotNull);
    expect(AuthValidation.password('x'), isNull);
  });

  testWidgets('Missing fields show an error under each field', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pump();
    expect(find.text('Saisissez votre adresse e-mail.'), findsOneWidget);
    expect(find.text('Saisissez votre mot de passe.'), findsOneWidget);
  });

  testWidgets('Password visibility can be toggled', (tester) async {
    await tester.pumpWidget(app());
    TextField field() =>
        tester.widget<TextField>(find.byKey(const ValueKey('login-password')));
    expect(field().obscureText, isTrue);
    await tester.tap(find.byKey(const ValueKey('toggle-password')));
    await tester.pump();
    expect(field().obscureText, isFalse);
  });

  testWidgets('Valid sign-in loads, then opens the collaborator space', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.enterText(
      find.byKey(const ValueKey('login-email')),
      'amina@atlas.ma',
    );
    await tester.enterText(find.byKey(const ValueKey('login-password')), 'x');
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(AuthValidation.simulatedDelay);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('Espace collaborateur'), findsOneWidget);
  });

  testWidgets('Forgot password sends a simulated link and comes back', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.enterText(
      find.byKey(const ValueKey('login-email')),
      'amina@atlas.ma',
    );
    await tester.tap(find.byKey(const ValueKey('login-forgot')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('forgot-submit')));
    await tester.pump(AuthValidation.simulatedDelay);
    await tester.pump();
    expect(find.text('Lien envoyé'), findsOneWidget);
    expect(find.textContaining('amina@atlas.ma'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('forgot-back')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Login fits a narrow phone with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(app());
    await tester.ensureVisible(find.byKey(const ValueKey('login-submit')));
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

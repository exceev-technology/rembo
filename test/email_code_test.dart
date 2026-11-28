// With a server, a new account and a forgotten password are confirmed with
// a code from the e-mail, typed in the app: no link to open elsewhere.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/app/app_routes.dart';
import 'package:rembo/app/rembo_app.dart';
import 'package:rembo/core/data/app_state.dart';
import 'package:rembo/core/data/local_backend.dart';
import 'package:rembo/core/data/models.dart';

/// Behaves like the server: sign-up waits for the e-mailed code.
class _Server extends DemoBackend {
  _Server() : super(latency: Duration.zero);

  final sent = <String>[];
  String? newPassword;
  ({String email, String password, String fullName})? _pending;

  @override
  bool get isDemo => false;

  @override
  Future<AppUser?> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    _pending = (email: email, password: password, fullName: fullName);
    sent.add('confirmation');
    return null;
  }

  @override
  Future<void> resendSignUpCode(String email) async => sent.add('again');

  @override
  Future<AppUser> confirmSignUp({
    required String email,
    required String code,
  }) async {
    if (code != '123456') {
      throw const RemboException(
        'Code incorrect ou expiré. Demandez-en un nouveau.',
      );
    }
    final p = _pending!;
    return (await super.signUp(
      email: p.email,
      password: p.password,
      fullName: p.fullName,
    ))!;
  }

  @override
  Future<void> sendPasswordReset(String email) async => sent.add('reset');

  @override
  Future<AppUser> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (code != '654321') {
      throw const RemboException(
        'Code incorrect ou expiré. Demandez-en un nouveau.',
      );
    }
    this.newPassword = newPassword;
    return signIn(email, newPassword);
  }
}

late AppState state;
late _Server _server;

Future<void> _start(WidgetTester tester, String route) async {
  tester.view.physicalSize = const Size(420, 2600);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  _server = _Server();
  state = AppState(_server);
  await tester.pumpWidget(RemboApp(state: state, initialRoute: route));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(ValueKey(key)), text);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('A new account is confirmed with the e-mailed code', (
    tester,
  ) async {
    await _start(tester, AppRoutes.signup);
    await _type(tester, 'signup-email', 'yasmine@exemple.ma');
    await _type(tester, 'signup-first', 'Yasmine');
    await _type(tester, 'signup-last', 'Essai');
    await _type(tester, 'signup-password', 'Secret#2026');
    await _tap(tester, 'signup-submit');
    expect(find.text('Confirmez votre adresse'), findsOneWidget);
    expect(_server.sent, ['confirmation']);

    await _tap(tester, 'signup-resend');
    expect(_server.sent, ['confirmation', 'again']);
    expect(find.text('Un nouveau code a été envoyé.'), findsOneWidget);

    await _type(tester, 'signup-code', '12');
    await _tap(tester, 'signup-confirm');
    expect(
      find.text('Saisissez le code à 6 chiffres reçu par e-mail.'),
      findsOneWidget,
    );
    await _type(tester, 'signup-code', '000000');
    await _tap(tester, 'signup-confirm');
    expect(
      find.text('Code incorrect ou expiré. Demandez-en un nouveau.'),
      findsOneWidget,
    );
    expect(state.user, isNull);

    await _type(tester, 'signup-code', '123456');
    await _tap(tester, 'signup-confirm');
    expect(state.user?.email, 'yasmine@exemple.ma');
  });

  testWidgets('A forgotten password is replaced with the e-mailed code', (
    tester,
  ) async {
    await _start(tester, AppRoutes.forgotPassword);
    await _type(tester, 'reset-email', DemoBackend.marius.email);
    await _tap(tester, 'reset-submit');
    expect(_server.sent, ['reset']);
    expect(find.text('Code envoyé'), findsOneWidget);

    await _type(tester, 'reset-code', '654321');
    await _type(tester, 'reset-password', 'court');
    await _tap(tester, 'reset-confirm');
    expect(
      find.text('Le mot de passe ne respecte pas les règles.'),
      findsOneWidget,
    );
    await _type(tester, 'reset-password', 'Nouveau#2026');
    await _tap(tester, 'reset-confirm');
    expect(_server.newPassword, 'Nouveau#2026');
    expect(state.user?.email, DemoBackend.marius.email);
  });
}

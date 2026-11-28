// Sprint 5 goal on a device: capture, correction, submission and decision,
// end to end, with no server (the app keeps the data on the device).
// Runs on an Android phone and, in the CI, on an iOS simulator:
//
//   flutter test integration_test/journey_test.dart -d <device>
//
// Sara creates her company and invites Omar. Omar declares a compliant
// expense and one over the limit, after correcting what he typed. Sara
// confirms the compliant one in one gesture and rejects the other with a
// reason; Omar sees the reason.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rembo/features/onboarding/splash_screen.dart';
import 'package:rembo/main.dart' as app;

/// Pause after each action, so that a person can follow on the screen.
const _pace = Duration(milliseconds: 600);

Finder _key(String key) => find.byKey(ValueKey(key));

/// Scrolls the page up, then down, until [finder] is built: long forms
/// only build what is near the screen.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(Scrollable);
  for (final dy in [300.0, -300.0]) {
    for (var i = 0; i < 12 && finder.evaluate().isEmpty; i++) {
      if (scrollable.evaluate().isEmpty) return;
      await tester.drag(scrollable.first, Offset(0, dy));
      await tester.pump(const Duration(milliseconds: 150));
    }
  }
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  var revealed = false;
  while (finder.evaluate().isEmpty) {
    if (!revealed && DateTime.now().isAfter(end.subtract(timeout ~/ 2))) {
      revealed = true;
      await _reveal(tester, finder);
      continue;
    }
    if (DateTime.now().isAfter(end)) {
      final texts = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .whereType<String>()
          .take(25)
          .join(' | ');
      fail(
        'Still not on screen after ${timeout.inSeconds} s: $finder\n'
        'On screen: $texts',
      );
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.pump(_pace);
}

Future<void> _tapFinder(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  // Let a page transition end: a tap during it is not delivered.
  await tester.pump(const Duration(milliseconds: 700));
  await tester.tap(finder.first);
  await tester.pump(_pace);
}

Future<void> _tap(WidgetTester tester, String key) =>
    _tapFinder(tester, _key(key));

Future<void> _type(WidgetTester tester, String key, String text) async {
  await _waitFor(tester, _key(key));
  await tester.ensureVisible(_key(key));
  await tester.enterText(_key(key), text);
  await tester.pump(const Duration(milliseconds: 300));
}

void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

Future<void> _signUp(
  WidgetTester tester, {
  required String first,
  required String email,
}) async {
  await _tap(tester, 'welcome-start');
  await _type(tester, 'signup-email', email);
  await _type(tester, 'signup-first', first);
  await _type(tester, 'signup-last', 'Essai');
  await _type(tester, 'signup-password', 'Secret#2026');
  _unfocus();
  await _tap(tester, 'signup-submit');
}

Future<void> _signIn(WidgetTester tester, String email) async {
  await _tap(tester, 'welcome-login');
  await _type(tester, 'login-email', email);
  await _type(tester, 'login-password', 'Secret#2026');
  _unfocus();
  await _tap(tester, 'login-submit');
  await _waitFor(tester, _key('tab-profile'));
}

Future<void> _signOut(WidgetTester tester) async {
  await _tap(tester, 'tab-profile');
  await _tap(tester, 'profile-signout');
  await _waitFor(tester, _key('welcome-start'));
}

Future<void> _choose(WidgetTester tester, String key, String item) async {
  await _tap(tester, key);
  await _tapFinder(tester, find.text(item).last);
  await tester.pumpAndSettle();
}

/// Types an expense by hand, up to the summary before submission.
Future<void> _declare(
  WidgetTester tester, {
  required String supplier,
  required String amount,
  required String category,
}) async {
  await _tap(tester, 'home-add');
  await _tap(tester, 'capture-manual');
  await _type(tester, 'form-supplier', supplier);
  await _type(tester, 'form-amount', amount);
  await _choose(tester, 'form-category', category);
  await _type(tester, 'form-reason', 'Mission client');
  _unfocus();
  await _tap(tester, 'form-continue');
  await _waitFor(tester, _key('summary-submit'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Capture, correction, submission and decision on the device', (
    tester,
  ) async {
    final run = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final sara = 'sara.$run@essai.test';
    final omar = 'omar.$run@essai.test';

    app.main();
    await tester.pump(const Duration(seconds: 1));
    final opened = DateTime.now().add(const Duration(seconds: 40));
    while (find.byType(SplashScreen).evaluate().isNotEmpty) {
      if (DateTime.now().isAfter(opened)) fail('The opening never ended.');
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pump(_pace);
    // A device keeps its last session: start signed out.
    await _waitFor(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w.key == const ValueKey('welcome-start') ||
            w.key == const ValueKey('tab-profile'),
      ),
    );
    if (_key('tab-profile').evaluate().isNotEmpty) await _signOut(tester);

    // Sara creates the company and invites Omar.
    await _signUp(tester, first: 'Sara', email: sara);
    await _type(tester, 'company-name', 'Atelier Essai $run');
    _unfocus();
    await _tap(tester, 'company-submit');
    await _tap(tester, 'tab-profile');
    await _tap(tester, 'profile-team');
    await _tap(tester, 'team-invite');
    await _type(tester, 'invite-email', omar);
    _unfocus();
    await _tap(tester, 'invite-submit');
    await _waitFor(tester, _key('invite-done'));
    await _tapFinder(tester, find.text('Terminer'));
    await _tap(tester, 'page-back');
    await _signOut(tester);

    // Omar signs up, sees the invitation, joins on his answer, and declares
    // two expenses.
    await _signUp(tester, first: 'Omar', email: omar);
    await _tap(tester, 'company-join');
    await _waitFor(tester, _key('tab-profile'));

    // A compliant one, after correcting a wrong amount.
    await _declare(
      tester,
      supplier: 'Librairie Essai',
      amount: '4550',
      category: 'Fournitures',
    );
    await _tap(tester, 'summary-edit');
    await _type(tester, 'form-amount', '45,50');
    _unfocus();
    await _tap(tester, 'form-continue');
    await _waitFor(tester, _key('summary-preview-ok'));
    await _tap(tester, 'summary-submit');
    await _waitFor(tester, find.text('Conforme, en attente de validation'));
    await _tap(tester, 'result-home');

    // One over the meal limit: the compliance agent says so first.
    await _declare(
      tester,
      supplier: 'Restaurant Essai',
      amount: '320',
      category: 'Repas',
    );
    await _waitFor(tester, _key('summary-preview'));
    await _tap(tester, 'summary-submit');
    await _waitFor(tester, find.text('Transmise à votre responsable'));
    await _tap(tester, 'result-home');
    await _signOut(tester);

    // Sara confirms the compliant one and rejects the other.
    await _signIn(tester, sara);
    await _tap(tester, 'tab-exceptions');
    await _tap(tester, 'compliant-all');
    await _tap(tester, 'compliant-confirm');
    // Let the confirmation message leave the buttons free.
    await tester.pump(const Duration(seconds: 5));
    await _waitFor(tester, find.text('Omar Essai'));
    await _tapFinder(tester, find.text('Omar Essai'));
    await _tap(tester, 'decision-reject');
    await _type(tester, 'reject-reason', 'Plafond repas : joindre la liste.');
    _unfocus();
    await _tap(tester, 'reject-confirm');
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Omar Essai'), findsNothing);
    await _signOut(tester);

    // Omar sees both decisions.
    await _signIn(tester, omar);
    await _waitFor(tester, find.textContaining('Restaurant Essai'));
    await _tapFinder(tester, find.textContaining('Restaurant Essai'));
    await _waitFor(tester, find.text('Plafond repas : joindre la liste.'));
  });
}

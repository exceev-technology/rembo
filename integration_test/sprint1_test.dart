// Sprint 1 on a real phone, against a real Supabase: accounts, company,
// invitations and one space per role.
//
// Against the local stack (nothing leaves the PC):
//   supabase start
//   adb reverse tcp:54321 tcp:54321
//   flutter test integration_test/sprint1_test.dart -d <phone> \
//     --dart-define-from-file=.env.local
//
// The accounts are created in the app and used at once: this run needs the
// e-mail confirmation off in the local stack (enable_confirmations = false
// under [auth.email] in supabase/config.toml, not to be committed).
//
// Every run uses new fictional addresses, so it can be run again.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rembo/features/onboarding/splash_screen.dart';
import 'package:rembo/main.dart' as app;

/// Pause after each action, so that a person can follow on the phone.
const _pace = Duration(milliseconds: 900);

Finder _key(String key) => find.byKey(ValueKey(key));

/// The welcome page moves for ever, so nothing here waits for the app to
/// « settle »: it waits for what should appear.
Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      fail('Still not on screen after ${timeout.inSeconds} s: $finder');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.pump(_pace);
}

Future<void> _tap(WidgetTester tester, String key) async {
  await _waitFor(tester, _key(key));
  await tester.ensureVisible(_key(key));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(_key(key));
  await tester.pump(_pace);
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await _waitFor(tester, _key(key));
  await tester.ensureVisible(_key(key));
  await tester.enterText(_key(key), text);
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _signUp(
  WidgetTester tester, {
  required String first,
  required String email,
}) async {
  await _tap(tester, 'welcome-start');
  await _type(tester, 'signup-email', email);
  await _type(tester, 'signup-first', first);
  await _type(tester, 'signup-last', 'Test');
  await _type(tester, 'signup-password', 'Secret#2026');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(_pace);
  await _tap(tester, 'signup-submit');
}

Future<void> _signOut(WidgetTester tester) async {
  await _tap(tester, 'tab-profile');
  await _tap(tester, 'profile-signout');
  await _waitFor(tester, _key('welcome-start'));
}

Future<void> _invite(WidgetTester tester, String email, String role) async {
  await _tap(tester, 'team-invite');
  await _type(tester, 'invite-email', email);
  if (role != 'Collaborateur') {
    await _tap(tester, 'invite-role');
    await tester.tap(find.text(role).last);
    await tester.pump(_pace);
  }
  await _tap(tester, 'invite-submit');
  await _waitFor(tester, _key('invite-done'));
  await tester.tap(find.text('Terminer'));
  await tester.pump(_pace);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Sprint 1: accounts, company, invitations, one space per role', (
    tester,
  ) async {
    final run = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final sara = 'sara.$run@exemple.ma';
    final omar = 'omar.$run@exemple.ma';
    final lina = 'lina.$run@exemple.ma';

    app.main();
    // The app is built behind the opening: wait until the logo is gone.
    await tester.pump(const Duration(seconds: 1));
    final opened = DateTime.now().add(const Duration(seconds: 40));
    while (find.byType(SplashScreen).evaluate().isNotEmpty) {
      if (DateTime.now().isAfter(opened)) fail('The opening never ended.');
      await tester.pump(const Duration(milliseconds: 200));
    }
    // A previous run may have left someone signed in.
    await _waitFor(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w.key == const ValueKey('welcome-start') ||
            w.key == const ValueKey('tab-profile'),
      ),
    );
    if (_key('tab-profile').evaluate().isNotEmpty) await _signOut(tester);

    // 1. A new person creates an account, then a company.
    await _signUp(tester, first: 'Sara', email: sara);
    await _type(tester, 'company-name', 'Atelier Test $run');
    FocusManager.instance.primaryFocus?.unfocus();
    await _tap(tester, 'company-submit');

    // 2. The founder is manager.
    await _waitFor(tester, _key('tab-exceptions'));

    // 3. She invites a collaborator and an accountant.
    await _tap(tester, 'tab-profile');
    await _tap(tester, 'profile-team');
    await _invite(tester, omar, 'Collaborateur');
    await _invite(tester, lina, 'Comptable');
    expect(find.text('Invitation en attente'), findsNWidgets(2));
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump(_pace);
    await _signOut(tester);

    // 4. The invited collaborator sees the invitation, accepts it and lands
    //    in the collaborator space.
    await _signUp(tester, first: 'Omar', email: omar);
    await _waitFor(tester, _key('company-join'));
    await _tap(tester, 'company-join');
    await _waitFor(tester, _key('tab-expenses'));
    expect(_key('company-name'), findsNothing);
    expect(_key('tab-exceptions'), findsNothing);
    await _signOut(tester);

    // 5. The invited accountant accepts and lands in the accountant space.
    await _signUp(tester, first: 'Lina', email: lina);
    await _waitFor(tester, _key('company-join'));
    await _tap(tester, 'company-join');
    await _waitFor(tester, _key('tab-exports'));
    expect(_key('tab-exceptions'), findsNothing);
    await _signOut(tester);

    // 6. A wrong password is refused with a clear message.
    await _tap(tester, 'welcome-login');
    await _type(tester, 'login-email', sara);
    await _type(tester, 'login-password', 'Mauvais#2026');
    FocusManager.instance.primaryFocus?.unfocus();
    await _tap(tester, 'login-submit');
    await _waitFor(tester, find.text('E-mail ou mot de passe incorrect.'));

    // 7. The right one opens the manager space again.
    await _type(tester, 'login-password', 'Secret#2026');
    FocusManager.instance.primaryFocus?.unfocus();
    await _tap(tester, 'login-submit');
    await _waitFor(tester, _key('tab-exceptions'));

    // 8. The team now has three members and no pending invitation.
    await _tap(tester, 'tab-profile');
    await _tap(tester, 'profile-team');
    await _waitFor(tester, _key('member-$omar'));
    expect(_key('member-$lina'), findsOneWidget);
    expect(find.text('Invitation en attente'), findsNothing);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump(_pace);
    await _signOut(tester);
  });
}

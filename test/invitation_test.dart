import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/app/app_routes.dart';
import 'package:rembo/app/rembo_app.dart';
import 'package:rembo/core/data/app_state.dart';
import 'package:rembo/core/data/demo_backend.dart';
import 'package:rembo/core/data/models.dart';

late AppState state;

Future<void> _start(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 2600);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  state = AppState(DemoBackend(latency: Duration.zero));
  await tester.pumpWidget(RemboApp(state: state, initialRoute: AppRoutes.home));
  await tester.pumpAndSettle();
}

Future<void> _run(WidgetTester tester, Future<void> action) async {
  await tester.pumpAndSettle();
  await action;
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('An invited person joins only by answering the invitation', (
    tester,
  ) async {
    await _start(tester);
    await _run(tester, state.signIn(DemoBackend.salma.email, 'x'));
    await _run(tester, state.invite('karim@exemple.ma', UserRole.accountant));
    await _run(tester, state.signOut());

    await _run(
      tester,
      state.signUp(
        email: 'karim@exemple.ma',
        password: 'Secret1!',
        fullName: 'Karim Alaoui',
      ),
    );
    // Signed up, still outside the company: the invitation is shown.
    expect(state.user!.companyId, isNull);
    expect(find.byKey(const ValueKey('company-invitation')), findsOneWidget);
    expect(find.text('${DemoBackend.companyName} vous invite'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('company-join')));
    await tester.pumpAndSettle();
    expect(state.user!.companyName, DemoBackend.companyName);
    expect(state.user!.role, UserRole.accountant);
    expect(state.invitation, isNull);
  });

  testWidgets('Without an invitation, only the company creation is offered', (
    tester,
  ) async {
    await _start(tester);
    await _run(
      tester,
      state.signUp(email: 'x@y.ma', password: 'Secret1!', fullName: 'X Y'),
    );
    expect(find.byKey(const ValueKey('company-invitation')), findsNothing);
    expect(
      find.text('Aucune invitation : créez votre entreprise.'),
      findsOneWidget,
    );
  });
}

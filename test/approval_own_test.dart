import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/app/app_routes.dart';
import 'package:rembo/app/rembo_app.dart';
import 'package:rembo/core/data/app_state.dart';
import 'package:rembo/core/data/local_backend.dart';
import 'package:rembo/core/data/models.dart';
import 'package:rembo/features/collaborator/expense_detail_screen.dart';

late AppState state;

Future<void> _start(WidgetTester tester, AppUser who) async {
  tester.view.physicalSize = const Size(420, 2600);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  state = AppState(DemoBackend(latency: Duration.zero));
  await tester.pumpWidget(
    RemboApp(state: state, initialRoute: AppRoutes.login),
  );
  await tester.pumpAndSettle();
  final done = state.signIn(who.email, 'x');
  await tester.pumpAndSettle();
  await done;
  await tester.pumpAndSettle();
}

/// Creates and submits an expense the automatic control sends to a manager.
Future<Expense> _flagged() async {
  final draft = await state.backend.saveDraft(
    Expense(
      id: '',
      employeeId: state.user!.id,
      employeeName: state.user!.fullName,
      supplier: 'Imprimerie Atlas',
      date: DateTime.now().subtract(const Duration(days: 1)),
      amountCents: 9900,
      category: 'Autre',
      reason: 'Cartes de visite',
      createdAt: DateTime.now(),
    ),
  );
  final submitted = await state.backend.submit(draft.id);
  await state.refresh();
  return submitted;
}

Future<void> _openDetail(WidgetTester tester, String id) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  ExpenseDetailScreen.open(navigator.context, id);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('The manager approves their own expense', (tester) async {
    await _start(tester, DemoBackend.salma);
    final own = await _flagged();
    expect(own.status, ExpenseStatus.needsReview);
    expect(state.toReview.map((e) => e.id), contains(own.id));
    await tester.pumpAndSettle();

    await _openDetail(tester, own.id);
    final decide = find.byKey(const ValueKey('detail-decide'));
    await tester.ensureVisible(decide);
    await tester.tap(decide);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('decision-approve')));
    await tester.pumpAndSettle();

    final decided = state.byId(own.id)!;
    expect(decided.status, ExpenseStatus.approved);
    expect(decided.events.last.actorName, DemoBackend.salma.fullName);
  });

  testWidgets('An employee cannot decide on their own expense', (tester) async {
    await _start(tester, DemoBackend.marius);
    final own = await _flagged();
    expect(own.status, ExpenseStatus.needsReview);
    expect(state.toReview, isEmpty);
    await tester.pumpAndSettle();

    await _openDetail(tester, own.id);
    expect(find.byKey(const ValueKey('detail-decide')), findsNothing);
  });
}

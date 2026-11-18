import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/app/app_routes.dart';
import 'package:rembo/app/rembo_app.dart';
import 'package:rembo/core/data/app_state.dart';
import 'package:rembo/core/data/demo_backend.dart';
import 'package:rembo/core/data/models.dart';
import 'package:rembo/features/collaborator/expense_detail_screen.dart';

late AppState state;

Future<void> _start(WidgetTester tester) async {
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
}

Future<void> _signIn(WidgetTester tester, AppUser who) async {
  final done = state.signIn(who.email, 'x');
  await tester.pumpAndSettle();
  await done;
  await tester.pumpAndSettle();
}

/// Marius submits an expense the automatic control sends to a manager.
Future<String> _flagged(String supplier) async {
  final draft = await state.backend.saveDraft(
    Expense(
      id: '',
      employeeId: state.user!.id,
      employeeName: state.user!.fullName,
      supplier: supplier,
      date: DateTime.now().subtract(const Duration(days: 1)),
      amountCents: 9900,
      category: 'Autre',
      reason: 'Achat divers',
      createdAt: DateTime.now(),
    ),
  );
  await state.backend.submit(draft.id);
  return draft.id;
}

Future<void> _openDetail(WidgetTester tester, String id) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  ExpenseDetailScreen.open(navigator.context, id);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('The history shows what the manager wrote with a decision', (
    tester,
  ) async {
    await _start(tester);
    await _signIn(tester, DemoBackend.marius);
    final rejected = await _flagged('Librairie Centrale');
    final approved = await _flagged('Imprimerie Atlas');

    await _signIn(tester, DemoBackend.salma);
    await state.backend.decide(
      rejected,
      approve: false,
      reason: 'Ticket illisible',
    );
    await state.backend.decide(
      approved,
      approve: true,
      reason: 'Accordé pour ce client',
    );

    await _signIn(tester, DemoBackend.marius);
    await state.refresh();
    await tester.pumpAndSettle();

    await _openDetail(tester, rejected);
    expect(find.text('Rejetée par Salma Idrissi'), findsOneWidget);
    expect(find.text('Motif : Ticket illisible'), findsOneWidget);
    Navigator.of(tester.element(find.text('Motif : Ticket illisible'))).pop();
    await tester.pumpAndSettle();

    await _openDetail(tester, approved);
    expect(find.text('Validée par Salma Idrissi'), findsOneWidget);
    expect(find.text('Commentaire : Accordé pour ce client'), findsOneWidget);
  });

  testWidgets('A decision of the automatic control adds no note', (
    tester,
  ) async {
    await _start(tester);
    await _signIn(tester, DemoBackend.marius);
    final id = await _flagged('Librairie Centrale');
    await state.refresh();
    await tester.pumpAndSettle();

    await _openDetail(tester, id);
    expect(find.textContaining('Motif : '), findsNothing);
    expect(find.textContaining('Commentaire : '), findsNothing);
  });
}

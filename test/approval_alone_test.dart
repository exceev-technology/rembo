import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/app/app_routes.dart';
import 'package:rembo/app/rembo_app.dart';
import 'package:rembo/core/data/app_state.dart';
import 'package:rembo/core/data/local_backend.dart';
import 'package:rembo/core/data/models.dart';
import 'package:rembo/features/collaborator/expense_detail_screen.dart';

late AppState state;

/// The team cannot be read: everything else loads.
class _TeamUnavailable extends DemoBackend {
  _TeamUnavailable() : super(latency: Duration.zero, managersDeclare: true);

  @override
  Future<List<Member>> fetchMembers() async =>
      throw const RemboException('Connexion impossible.', network: true);
}

Future<void> _start(
  WidgetTester tester,
  AppUser who, {
  DemoBackend? backend,
}) async {
  tester.view.physicalSize = const Size(420, 2600);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  state = AppState(
    backend ?? DemoBackend(latency: Duration.zero, managersDeclare: true),
  );
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
  testWidgets('The only manager is told to invite another one', (tester) async {
    await _start(tester, DemoBackend.salma);
    final own = await _flagged();
    expect(own.status, ExpenseStatus.needsReview);
    await tester.pumpAndSettle();

    await _openDetail(tester, own.id);
    expect(find.byKey(const ValueKey('detail-alone-manager')), findsOneWidget);
    expect(find.text('Vous êtes le seul responsable'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('detail-invite-manager')));
    await tester.pumpAndSettle();
    expect(find.text('Équipe'), findsWidgets);
  });

  testWidgets('An employee never sees the notice', (tester) async {
    await _start(tester, DemoBackend.marius);
    final own = await _flagged();
    expect(own.status, ExpenseStatus.needsReview);
    await tester.pumpAndSettle();

    await _openDetail(tester, own.id);
    expect(find.byKey(const ValueKey('detail-alone-manager')), findsNothing);
  });

  testWidgets('Nothing is said while the team could not be loaded', (
    tester,
  ) async {
    await _start(tester, DemoBackend.salma, backend: _TeamUnavailable());
    final own = await _flagged();
    expect(own.status, ExpenseStatus.needsReview);
    expect(state.membersLoaded, isFalse);
    await tester.pumpAndSettle();

    await _openDetail(tester, own.id);
    expect(find.byKey(const ValueKey('detail-alone-manager')), findsNothing);
  });
}

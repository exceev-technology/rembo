import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/core/demo/demo_expenses.dart';
import 'package:rembo/core/theme/rembo_theme.dart';
import 'package:rembo/features/manager/approval_history_screen.dart';
import 'package:rembo/features/manager/approval_store.dart';
import 'package:rembo/features/manager/manager_home_screen.dart';

Widget app(ApprovalStore store) => MaterialApp(
  theme: RemboTheme.light(),
  home: ManagerHomeScreen(store: store),
);

/// Lists build lazily: scroll until the widget exists, then show it.
Future<Finder> reveal(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  return finder;
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(await reveal(tester, key));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Pending requests are listed with their total', (tester) async {
    await tester.pumpWidget(app(ApprovalStore.demo()));
    expect(find.text('4 demandes à traiter · 2 266,50 MAD'), findsOneWidget);
    expect(find.byKey(const ValueKey('request-req-105')), findsNothing);
    await tapKey(tester, 'manager-filter-approved');
    expect(find.byKey(const ValueKey('request-req-105')), findsOneWidget);
  });

  testWidgets('Approval asks for confirmation and updates the list', (
    tester,
  ) async {
    final store = ApprovalStore.demo();
    await tester.pumpWidget(app(store));
    await tapKey(tester, 'request-req-101');
    await tapKey(tester, 'approve');
    expect(find.text('Approuver la dépense ?'), findsOneWidget);
    await tapKey(tester, 'confirm-approve');
    expect(store.byId('req-101').status, DemoExpenseStatus.approved);
    expect(find.byType(ManagerHomeScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('request-req-101')), findsNothing);
    expect(store.history.first.supplier, 'Train Al Boraq');
  });

  testWidgets('Rejection requires a reason', (tester) async {
    final store = ApprovalStore.demo();
    await tester.pumpWidget(app(store));
    await tapKey(tester, 'request-req-102');
    expect(
      find.text('Montant au-dessus du plafond repas de 500,00 MAD.'),
      findsOneWidget,
    );
    await tapKey(tester, 'reject');
    await tester.tap(find.byKey(const ValueKey('confirm-reject')));
    await tester.pump();
    expect(find.text('Le motif est obligatoire.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('reject-reason')),
      'Plafond dépassé',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-reject')));
    await tester.pumpAndSettle();
    expect(store.byId('req-102').status, DemoExpenseStatus.rejected);
    expect(store.history.first.reason, 'Plafond dépassé');
  });

  testWidgets('Self-approval is unavailable', (tester) async {
    await tester.pumpWidget(app(ApprovalStore.demo()));
    await tapKey(tester, 'request-req-104');
    await reveal(tester, 'approve');
    expect(find.byKey(const ValueKey('self-approval')), findsOneWidget);
    final approve = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const ValueKey('approve')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(approve.onPressed, isNull);
  });

  testWidgets('History lists past decisions', (tester) async {
    await tester.pumpWidget(app(ApprovalStore.demo()));
    await tapKey(tester, 'manager-history');
    expect(find.byType(ApprovalHistoryScreen), findsOneWidget);
    expect(
      find.text('Motif : Cadeau client hors politique de dépenses.'),
      findsOneWidget,
    );
  });

  testWidgets('Screens fit a narrow phone with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(app(ApprovalStore.demo()));
    await tapKey(tester, 'request-req-102');
    await reveal(tester, 'reject');
    expect(tester.takeException(), isNull);
  });
}

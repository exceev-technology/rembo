import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/app/app_router.dart';
import 'package:rembo/core/theme/rembo_theme.dart';
import 'package:rembo/features/collaborator/screens/collaborator_home_screen.dart';
import 'package:rembo/features/collaborator/screens/expense_detail_screen.dart';
import 'package:rembo/features/collaborator/screens/expenses_list_screen.dart';

Widget app(Widget home) => MaterialApp(
  theme: RemboTheme.light(),
  home: home,
  onGenerateRoute: AppRouter.onGenerateRoute,
);

void main() {
  testWidgets('Home shows the total of the fictional expenses', (tester) async {
    await tester.pumpWidget(app(const CollaboratorHomeScreen()));
    expect(find.text('4 dépenses ce mois-ci'), findsOneWidget);
    expect(find.text('1 090,00 MAD'), findsOneWidget);
  });

  testWidgets('Add an expense opens the capture route', (tester) async {
    await tester.pumpWidget(app(const CollaboratorHomeScreen()));
    await tester.tap(find.byKey(const ValueKey('collab-add')));
    await tester.pumpAndSettle();
    expect(find.text('Capture du justificatif'), findsWidgets);
  });

  testWidgets('List filters by status and opens a detail', (tester) async {
    await tester.pumpWidget(app(const CollaboratorHomeScreen()));
    await tester.ensureVisible(find.byKey(const ValueKey('collab-see-all')));
    await tester.tap(find.byKey(const ValueKey('collab-see-all')));
    await tester.pumpAndSettle();
    expect(find.byType(ExpensesListScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filter-approved')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('expense-demo-003')), findsOneWidget);
    expect(find.byKey(const ValueKey('expense-demo-001')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('expense-demo-003')));
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseDetailScreen), findsOneWidget);
    expect(find.text('760,00 MAD'), findsWidgets);
  });

  testWidgets('An empty list explains itself and offers to add', (
    tester,
  ) async {
    await tester.pumpWidget(app(const ExpensesListScreen(expenses: [])));
    expect(find.text('Aucune dépense'), findsOneWidget);
    expect(find.text('Ajouter une dépense'), findsOneWidget);
  });

  testWidgets('Screens fit a narrow phone with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(app(const CollaboratorHomeScreen()));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(app(const ExpensesListScreen()));
    expect(tester.takeException(), isNull);
  });
}

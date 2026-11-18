import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/app/app_routes.dart';
import 'package:rembo/app/rembo_app.dart';
import 'package:rembo/features/expenses/review_screen.dart';
import 'package:rembo/features/expenses/summary_screen.dart';

/// Lists build lazily: scroll until the widget exists, then show it.
Future<Finder> reveal(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  return finder;
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(await reveal(tester, key));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Collaborator: sign in, declare an expense, back home', (
    tester,
  ) async {
    await tester.pumpWidget(const RemboApp(initialRoute: AppRoutes.login));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('login-email')),
      'amina@atlas.ma',
    );
    await tester.enterText(find.byKey(const ValueKey('login-password')), 'x');
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Espace collaborateur'), findsOneWidget);

    await tapKey(tester, 'collab-add');
    await tapKey(tester, 'capture-camera');
    await tester.tap(await reveal(tester, 'capture-continue'));
    await tester.pump();
    await tester.pump(ReviewScreen.readingDelay);
    await tester.pumpAndSettle();
    await tapKey(tester, 'category-Repas');
    await tester.enterText(
      await reveal(tester, 'field-reason'),
      'Déjeuner client',
    );
    await tapKey(tester, 'review-next');
    await tapKey(tester, 'summary-submit');
    await tester.pump(SummaryScreen.submitDelay);
    await tester.pumpAndSettle();
    expect(find.text('Dépense envoyée'), findsOneWidget);
    await tapKey(tester, 'confirmation-home');
    expect(find.text('Espace collaborateur'), findsOneWidget);
  });

  testWidgets('Manager: approve a pending request', (tester) async {
    await tester.pumpWidget(const RemboApp(initialRoute: AppRoutes.manager));
    await tester.pumpAndSettle();
    expect(find.textContaining('4 demandes à traiter'), findsOneWidget);
    await tapKey(tester, 'request-req-101');
    await tapKey(tester, 'approve');
    await tapKey(tester, 'confirm-approve');
    expect(find.textContaining('3 demandes à traiter'), findsOneWidget);
  });

  testWidgets('Accountant: select, preview and export', (tester) async {
    await tester.pumpWidget(const RemboApp(initialRoute: AppRoutes.accountant));
    await tester.pumpAndSettle();
    await tapKey(tester, 'select-all');
    await tester.tap(find.byKey(const ValueKey('preview-export')));
    await tester.pumpAndSettle();
    await tapKey(tester, 'export-csv');
    await tester.tap(find.byKey(const ValueKey('confirm-export')));
    await tester.pumpAndSettle();
    expect(find.text('0 dépenses approuvées à exporter'), findsOneWidget);
  });

  testWidgets('Collaborator home reaches settings, then signs out', (
    tester,
  ) async {
    await tester.pumpWidget(
      const RemboApp(initialRoute: AppRoutes.collaborator),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Paramètres'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'logout');
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
  });
}

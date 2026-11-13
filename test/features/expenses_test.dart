import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/app/app_router.dart';
import 'package:rembo/app/app_routes.dart';
import 'package:rembo/core/theme/rembo_theme.dart';
import 'package:rembo/features/expenses/capture_screen.dart';
import 'package:rembo/features/expenses/expense_draft.dart';
import 'package:rembo/features/expenses/review_screen.dart';
import 'package:rembo/features/expenses/summary_screen.dart';

/// Stands in for #24: the module's own route is wired only in this test.
Widget app() => MaterialApp(
  theme: RemboTheme.light(),
  home: const CaptureScreen(),
  onGenerateRoute: (settings) => settings.name == AppRoutes.review
      ? MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ReviewScreen(),
        )
      : AppRouter.onGenerateRoute(settings),
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

Future<void> attachAndRead(WidgetTester tester, String source) async {
  await tester.pumpWidget(app());
  await tapKey(tester, source);
  await tester.tap(await reveal(tester, 'capture-continue'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byKey(const ValueKey('review-reading')), findsOneWidget);
  await tester.pump(ReviewScreen.readingDelay);
  await tester.pumpAndSettle();
}

void main() {
  test('Amounts and required fields are checked locally', () {
    expect(ExpenseDraft.parseAmount('380,00'), 38000);
    expect(ExpenseDraft.parseAmount('1 234,5'), 123450);
    expect(ExpenseDraft.parseAmount('0'), isNull);
    expect(ExpenseDraft.parseAmount('abc'), isNull);
    expect(ExpenseDraft.parseAmount('12,345'), isNull);
    expect(ExpenseDraft.parseAmount('-3'), isNull);
    expect(ExpenseDraft.parseAmount('125,5'), 12550);
    expect(ExpenseDraft.parseAmount('0,10'), 10);
    final today = DateTime(2026, 11, 10);
    expect(ExpenseDraft.parseDate('31/02/2026', today: today), isNull);
    expect(ExpenseDraft.parseDate('29/02/2024', today: today), isNotNull);
    expect(ExpenseDraft.parseDate('10/11/2026', today: today), isNotNull);
    expect(ExpenseDraft.parseDate('11/11/2026', today: today), isNull);
    expect(ExpenseDraft.parseDate('01/01/1999', today: today), isNull);
    final draft = ExpenseDraft();
    expect(
      draft.errors().keys,
      containsAll(<DraftField>[
        DraftField.supplier,
        DraftField.date,
        DraftField.amount,
        DraftField.category,
        DraftField.reason,
      ]),
    );
    draft.set(DraftField.date, '32/13/2026');
    expect(
      draft.errors()[DraftField.date],
      'Date invalide : une date passée au format JJ/MM/AAAA.',
    );
  });

  testWidgets('Retake removes the attached receipt', (tester) async {
    await tester.pumpWidget(app());
    await tapKey(tester, 'capture-import');
    await reveal(tester, 'capture-continue');
    await tapKey(tester, 'capture-retake');
    expect(find.byKey(const ValueKey('capture-continue')), findsNothing);
  });

  testWidgets('Full journey: read, complete, review, submit, confirm', (
    tester,
  ) async {
    await attachAndRead(tester, 'capture-camera');
    expect(find.text('Lu sur le reçu'), findsWidgets);
    expect(find.text('Le Zellige · Rabat'), findsOneWidget);
    await tapKey(tester, 'review-next');
    expect(find.text('2 champs à corriger'), findsOneWidget);

    await tapKey(tester, 'category-Repas');
    await tester.enterText(
      await reveal(tester, 'field-reason'),
      'Déjeuner client',
    );
    await tapKey(tester, 'review-next');
    expect(find.byType(SummaryScreen), findsOneWidget);
    expect(find.text('380,00 MAD'), findsOneWidget);

    await tapKey(tester, 'summary-edit');
    expect(find.text('Déjeuner client'), findsOneWidget);
    await tapKey(tester, 'review-next');

    await tapKey(tester, 'summary-submit');
    await tester.pump(SummaryScreen.submitDelay);
    await tester.pumpAndSettle();
    expect(find.text('Dépense envoyée'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Dépense envoyée'), findsOneWidget);

    await tapKey(tester, 'confirmation-home');
    expect(find.text('Espace collaborateur'), findsWidgets);
  });

  testWidgets('An unreadable receipt asks for manual entry', (tester) async {
    await attachAndRead(tester, 'capture-unreadable');
    expect(find.byKey(const ValueKey('review-unreadable')), findsOneWidget);
    expect(find.text('Lu sur le reçu'), findsNothing);
    await tapKey(tester, 'review-next');
    expect(find.text('5 champs à corriger'), findsOneWidget);
    await reveal(tester, 'field-amount');
    expect(
      find.text('Montant absent : indiquez le total TTC du reçu.'),
      findsOneWidget,
    );
  });

  testWidgets('Manual entry skips the reading and starts empty', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tapKey(tester, 'capture-manual');
    expect(find.byKey(const ValueKey('review-reading')), findsNothing);
    expect(find.byKey(const ValueKey('review-manual')), findsOneWidget);
    expect(find.text('Lu sur le reçu'), findsNothing);
  });

  testWidgets('Screens fit a narrow phone with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await attachAndRead(tester, 'capture-camera');
    await tapKey(tester, 'review-next');
    expect(tester.takeException(), isNull);
  });
}

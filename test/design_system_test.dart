import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/core/demo/demo_expenses.dart';
import 'package:rembo/core/widgets/rembo_widgets.dart';

Widget host(Widget child) => MaterialApp(
  theme: RemboTheme.light(),
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: child,
    ),
  ),
);

void main() {
  test('Amounts are formatted in MAD with French separators', () {
    expect(formatMad(0), '0,00 MAD');
    expect(formatMad(16500), '165,00 MAD');
    expect(formatMad(123456), '1 234,56 MAD');
    expect(formatMad(100000005), '1 000 000,05 MAD');
    expect(formatMad(-4500), '−45,00 MAD');
  });

  test('Dates use short French month names', () {
    expect(formatDate(DateTime(2026, 10, 27)), '27 oct. 2026');
    expect(formatDate(DateTime(2026, 2, 1)), '1 févr. 2026');
  });

  testWidgets('Status badges use the shared French wording', (tester) async {
    await tester.pumpWidget(
      host(
        Wrap(
          children: [
            for (final s in DemoExpenseStatus.values) StatusBadge(status: s),
          ],
        ),
      ),
    );
    for (final label in ['Brouillon', 'Soumise', 'Approuvée', 'Rejetée']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('Primary button reacts to taps and ignores them while loading', (
    tester,
  ) async {
    var taps = 0;
    Widget button(bool loading) => host(
      RemboPrimaryButton(
        label: 'Continuer',
        loading: loading,
        onPressed: () => taps++,
      ),
    );
    await tester.pumpWidget(button(false));
    await tester.tap(find.text('Continuer'));
    expect(taps, 1);
    await tester.pumpWidget(button(true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    expect(taps, 1);
  });

  testWidgets('Text field shows its error instead of its helper', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const RemboTextField(
          label: 'E-mail',
          helper: 'Votre adresse professionnelle',
          errorText: 'Saisissez votre e-mail.',
        ),
      ),
    );
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Saisissez votre e-mail.'), findsOneWidget);
    expect(find.text('Votre adresse professionnelle'), findsNothing);
  });

  testWidgets('Logo and illustration assets are bundled', (tester) async {
    await tester.pumpWidget(
      host(
        const Column(
          children: [
            RemboLogo(),
            RemboLogo(showWordmark: false),
            RemboIllustration(),
          ],
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('REMBO'), findsNWidgets(2));
  });

  testWidgets('Components fit a narrow phone with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      host(
        Column(
          children: [
            const RemboLogo(),
            for (final e in demoExpenses) ExpenseCard.fromDemo(e),
            const RemboMessage(
              tone: MessageTone.warning,
              title: 'Montant à compléter',
              message: 'Le montant n’a pas pu être lu sur le reçu.',
            ),
            RemboSecondaryButton(label: 'Reprendre', onPressed: () {}),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}

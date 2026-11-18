import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/core/theme/rembo_theme.dart';
import 'package:rembo/features/accountant/accountant_home_screen.dart';
import 'package:rembo/features/accountant/export_history_screen.dart';
import 'package:rembo/features/accountant/export_preview_screen.dart';
import 'package:rembo/features/accountant/export_store.dart';

Widget app(ExportStore store) => MaterialApp(
  theme: RemboTheme.light(),
  home: AccountantHomeScreen(store: store),
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
  test('CSV lines use semicolons and decimal commas', () {
    final lines = ExportStore.csvLines(
      ExportStore.demo().toExport.take(1).toList(),
    );
    expect(lines, [
      ExportStore.csvHeader,
      '20/10/2026;Train Al Boraq;249,00;22,64;Transport;Client Atlas Logistique',
    ]);
  });

  testWidgets('Selection recalculates the total', (tester) async {
    await tester.pumpWidget(app(ExportStore.demo()));
    expect(find.text('5 dépenses approuvées à exporter'), findsOneWidget);
    await tapKey(tester, 'accounting-acc-201');
    await tapKey(tester, 'accounting-acc-202');
    expect(find.text('2 sélectionnées · 629,00 MAD'), findsOneWidget);
  });

  testWidgets('Category filter and select all', (tester) async {
    final store = ExportStore.demo();
    await tester.pumpWidget(app(store));
    await tapKey(tester, 'category-Transport');
    expect(find.byKey(const ValueKey('accounting-acc-202')), findsNothing);
    await tapKey(tester, 'select-all');
    expect(store.selected, {'acc-201', 'acc-205'});
  });

  testWidgets('Export is previewed, confirmed and recorded', (tester) async {
    final store = ExportStore.demo();
    await tester.pumpWidget(app(store));
    await tapKey(tester, 'accounting-acc-203');
    await tester.tap(find.byKey(const ValueKey('preview-export')));
    await tester.pumpAndSettle();
    expect(find.byType(ExportPreviewScreen), findsOneWidget);
    expect(find.textContaining('Hôtel Atlas Agadir'), findsWidgets);
    await tapKey(tester, 'export-csv');
    await tester.tap(find.byKey(const ValueKey('confirm-export')));
    await tester.pumpAndSettle();
    expect(find.byType(AccountantHomeScreen), findsOneWidget);
    expect(store.toExport, hasLength(4));
    expect(store.history, hasLength(2));
    await tester.tap(find.byKey(const ValueKey('export-history')));
    await tester.pumpAndSettle();
    expect(find.byType(ExportHistoryScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('export-1')), findsOneWidget);
  });

  testWidgets('Screens fit a narrow phone with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final store = ExportStore.demo()..toggle('acc-201');
    await tester.pumpWidget(app(store));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('preview-export')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

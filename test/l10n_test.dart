import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/app/app_routes.dart';
import 'package:rembo/app/rembo_app.dart';
import 'package:rembo/core/data/app_state.dart';
import 'package:rembo/core/data/local_backend.dart';
import 'package:rembo/core/data/models.dart';
import 'package:rembo/core/format/formatters.dart';
import 'package:rembo/core/format/phone_countries.dart';
import 'package:rembo/core/l10n/ar.dart';
import 'package:rembo/core/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every `tr('…')` of the app, adjacent pieces joined, as Dart reads them.
Set<String> _textsOfTheApp() {
  final call = RegExp(r"\btr\(\s*((?:'(?:[^'\\]|\\.)*'\s*)+)");
  final piece = RegExp(r"'((?:[^'\\]|\\.)*)'");
  final texts = <String>{};
  for (final file in Directory('lib').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    for (final m in call.allMatches(file.readAsStringSync())) {
      texts.add(
        piece
            .allMatches(m.group(1)!)
            .map((p) => p.group(1)!)
            .join()
            .replaceAll(r'\n', '\n')
            .replaceAll(r"\'", "'"),
      );
    }
  }
  return texts;
}

Set<String> _marks(String text) =>
    RegExp(r'\{\w+\}').allMatches(text).map((m) => m.group(0)!).toSet();

late AppState state;

Future<void> _start(
  WidgetTester tester, {
  String route = AppRoutes.home,
  Size size = const Size(420, 2600),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  state = AppState(DemoBackend(latency: Duration.zero));
  await tester.pumpWidget(RemboApp(state: state, initialRoute: route));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> _signIn(WidgetTester tester, UserRole role) async {
  final email = switch (role) {
    UserRole.employee => DemoBackend.marius.email,
    UserRole.manager => DemoBackend.salma.email,
    UserRole.accountant => DemoBackend.nadia.email,
  };
  final done = state.signIn(email, 'x');
  await tester.pumpAndSettle();
  await done;
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  // The language is shared by the whole app: every test starts in French.
  tearDown(() => appLocale.value = const Locale('fr'));

  group('Arabic table', () {
    test('every text of the app has its Arabic', () {
      final texts = _textsOfTheApp();
      expect(texts.length, greaterThan(350));
      final missing = texts.where((t) => !arabic.containsKey(t)).toList();
      expect(missing, isEmpty);
    });

    test('roles, statuses, flags and categories have their Arabic', () {
      appLocale.value = const Locale('ar');
      final labels = [
        for (final r in UserRole.values) r.label,
        for (final s in ExpenseStatus.values) s.label,
        for (final k in FlagKind.values) k.label,
        for (final c in expenseCategories) tr(c),
      ];
      for (final label in labels) {
        expect(label, matches(RegExp(r'[؀-ۿ]')), reason: label);
        expect(label, isNot(matches(RegExp(r'[A-Za-zÀ-ÿ]'))), reason: label);
      }
    });

    test('a translation keeps the values of its French text', () {
      arabic.forEach((french, arabicText) {
        expect(_marks(arabicText), _marks(french), reason: french);
        expect(arabicText.trim(), isNotEmpty, reason: french);
      });
    });
  });

  group('Arabic formats', () {
    test('French stays the default and an unknown text comes back', () {
      expect(tr('Se connecter'), 'Se connecter');
      appLocale.value = const Locale('ar');
      expect(tr('Se connecter'), 'تسجيل الدخول');
      expect(tr('Texte jamais traduit'), 'Texte jamais traduit');
      expect(tr('Bonjour {firstName}', {'firstName': 'Salma'}), 'مرحبا Salma');
    });

    test('amounts and dates keep their digits, Moroccan month names', () {
      appLocale.value = const Locale('ar');
      expect(formatMad(123456), '1 234,56 درهم');
      expect(formatDate(DateTime(2026, 11, 9)), '9 نونبر 2026');
      expect(formatWeekday(DateTime(2026, 11, 9)), 'الإثنين 9 نونبر 2026');
      expect(
        formatDayShort(DateTime(2026, 8, 3), today: DateTime(2026, 8, 3)),
        'اليوم',
      );
    });

    test('expense counts follow the Arabic number forms', () {
      expect(expenseCount(1), '1 dépense');
      expect(expenseCount(4), '4 dépenses');
      appLocale.value = const Locale('ar');
      expect(expenseCount(1), 'مصروف واحد');
      expect(expenseCount(2), 'مصروفان');
      expect(expenseCount(7), '7 مصاريف');
      expect(expenseCount(25), '25 مصروفا');
    });

    test('reasons stored in French by the control are shown in Arabic', () {
      expect(trData('Justificatif manquant'), 'Justificatif manquant');
      appLocale.value = const Locale('ar');
      expect(trData('Justificatif manquant'), 'وثيقة الإثبات ناقصة');
      expect(
        trData('Plafond Repas dépassé de 40,00 MAD'),
        'تجاوز سقف وجبات بمبلغ 40,00 درهم',
      );
      // What a person typed is never touched.
      expect(trData('Déjeuner client'), 'Déjeuner client');
      expect(phoneCountries.first.localName, 'المغرب');
    });

    test('the language chosen is remembered on the phone', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await setLanguage(const Locale('ar'));
      appLocale.value = const Locale('fr');
      await loadLanguage();
      expect(isArabic, isTrue);
    });
  });

  group('Arabic app', () {
    testWidgets('the welcome page switches to Arabic, right to left', (
      tester,
    ) async {
      await _start(tester);
      expect(find.text('Commencer'), findsOneWidget);
      await _tap(tester, 'language-button');
      expect(tester.takeException(), isNull, reason: 'sheet');
      await _tap(tester, 'language-ar');
      expect(tester.takeException(), isNull, reason: 'switch');
      expect(find.text('Commencer'), findsNothing);
      expect(find.text('ابدأ'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('ابدأ'))),
        TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);

      // The screens already open follow, and the choice can be undone.
      await _tap(tester, 'welcome-login');
      expect(tester.takeException(), isNull, reason: 'login');
      expect(find.text('تسجيل الدخول'), findsWidgets);
      await _tap(tester, 'language-button');
      await _tap(tester, 'language-fr');
      expect(find.text('Se connecter'), findsWidgets);
    });

    testWidgets('the profile changes the language of every tab', (
      tester,
    ) async {
      await _start(tester);
      await _signIn(tester, UserRole.employee);
      await _tap(tester, 'tab-profile');
      await _tap(tester, 'profile-language');
      await _tap(tester, 'language-ar');
      expect(find.text('ملفي الشخصي'), findsOneWidget);
      expect(find.text('الرئيسية'), findsOneWidget);
      await _tap(tester, 'tab-expenses');
      expect(find.text('مصاريفي'), findsOneWidget);
      expect(find.text('Mes dépenses'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final role in UserRole.values) {
      testWidgets('${role.name}: every tab fits a narrow phone in Arabic', (
        tester,
      ) async {
        appLocale.value = const Locale('ar');
        await _start(tester, size: const Size(320, 640), textScale: 2);
        expect(tester.takeException(), isNull, reason: 'welcome');
        await _signIn(tester, role);
        for (final tab in [
          role == UserRole.accountant ? 'tab-overview' : 'tab-home',
          if (role == UserRole.employee) 'tab-expenses',
          if (role == UserRole.manager) 'tab-exceptions',
          if (role == UserRole.accountant) 'tab-exports',
          'tab-activity',
          'tab-profile',
        ]) {
          await _tap(tester, tab);
          expect(tester.takeException(), isNull, reason: tab);
        }
      });
    }

    testWidgets('entry and form screens fit a narrow phone in Arabic', (
      tester,
    ) async {
      appLocale.value = const Locale('ar');
      for (final route in [
        AppRoutes.login,
        AppRoutes.signup,
        AppRoutes.forgotPassword,
      ]) {
        await _start(
          tester,
          route: route,
          size: const Size(320, 640),
          textScale: 2,
        );
        expect(tester.takeException(), isNull, reason: route);
      }
    });
  });
}

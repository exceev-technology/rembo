/// Languages of the app. The code is written in French; [tr] gives the same
/// text in the language chosen, and French again when a text has no
/// translation yet.
library;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ar.dart';
import '../log.dart';

/// The languages offered, each under its own name.
const appLanguages = <(Locale, String)>[
  (Locale('fr'), 'Français'),
  (Locale('ar'), 'العربية'),
];

/// The language shown. Change it with [setLanguage].
final appLocale = ValueNotifier<Locale>(const Locale('fr'));

bool get isArabic => appLocale.value.languageCode == 'ar';

/// [french] in the current language. Values replace their `{name}` marks:
/// « Bonjour {firstName} » with firstName: Salma gives « Bonjour Salma ».
String tr(String french, [Map<String, Object?> values = const {}]) {
  var text = isArabic ? (arabic[french] ?? french) : french;
  values.forEach((name, value) => text = text.replaceAll('{$name}', '$value'));
  return text;
}

/// [value] kept in its own left-to-right order inside an Arabic sentence:
/// « +212 6… » would otherwise show its plus sign at the end.
String ltr(String value) => isArabic ? '\u2066$value\u2069' : value;

/// A name or reference typed in another script, kept as one block when it
/// is joined to Arabic text: « Taxi Bleu · 10 نونبر » keeps its date whole.
String isolate(String value) => isArabic ? '\u2068$value\u2069' : value;

final _overLimit = RegExp(r'^Plafond (.+) dépassé de (.+?)(?: | )MAD$');

/// A French text that was stored with the expense (reason found by the
/// automatic control, name of the agent), shown in the current language.
/// Free text typed by people comes back unchanged.
String trData(String? stored) {
  if (stored == null || !isArabic) return stored ?? '';
  final known = arabic[stored];
  if (known != null) return known;
  final over = _overLimit.firstMatch(stored);
  if (over != null) {
    return tr('Plafond {category} dépassé de {over}', {
      'category': tr(over.group(1)!),
      'over': '${over.group(2)} ${tr('MAD')}',
    });
  }
  final late = _tooOld.firstMatch(stored);
  if (late != null) {
    return tr('Dépense datée de plus de {days} jours', {'days': late.group(1)});
  }
  return stored;
}

/// « Dépense datée de plus de 30 jours »: the company's deadline.
final _tooOld = RegExp(r'^Dépense datée de plus de (\d+) jours$');

/// « 1 dépense », « 3 dépenses »; Arabic has its own forms for 1, 2, 3–10
/// and above.
String expenseCount(int n) {
  if (!isArabic) return n == 1 ? '1 dépense' : '$n dépenses';
  if (n == 1) return 'مصروف واحد';
  if (n == 2) return 'مصروفان';
  final tail = n % 100;
  return tail >= 3 && tail <= 10 ? '$n مصاريف' : '$n مصروفا';
}

const _languageKey = 'rembo_language';

/// Restores the language chosen earlier; a phone set to Arabic starts in
/// Arabic the first time.
Future<void> loadLanguage() async {
  String? code;
  try {
    code = (await SharedPreferences.getInstance()).getString(_languageKey);
  } catch (e, st) {
    logFailure('saved language not read', e, st);
    // No storage here (some tests, exotic platforms): keep the default.
  }
  code ??= WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  appLocale.value = Locale(code == 'ar' ? 'ar' : 'fr');
}

/// Switches the whole app to [locale] and remembers it on this phone.
Future<void> setLanguage(Locale locale) async {
  if (locale == appLocale.value) return;
  appLocale.value = locale;
  // Texts are read when a widget builds: rebuild every screen that is open.
  void rebuild(Element element) {
    element.markNeedsBuild();
    element.visitChildren(rebuild);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(rebuild);
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, locale.languageCode);
  } catch (e, st) {
    logFailure('language not saved', e, st);
    // The choice still holds until the app is closed.
  }
}

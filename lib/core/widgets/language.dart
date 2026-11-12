import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/rembo_tokens.dart';
import 'rembo_page.dart';

/// Name of the language shown, in that language.
String get currentLanguageName =>
    appLanguages.firstWhere((l) => l.$1 == appLocale.value).$2;

/// Lets the person choose the language of the app.
Future<void> showLanguageSheet(BuildContext context) => showRemboSheet<void>(
  context,
  title: tr('Langue de l’application'),
  builder: (sheet) => Column(
    children: [
      for (final (locale, name) in appLanguages)
        ListTile(
          key: ValueKey('language-${locale.languageCode}'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            locale == appLocale.value
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            color: locale == appLocale.value
                ? RemboColors.indigo
                : RemboColors.muted,
          ),
          title: Text(name, style: RemboText.body),
          onTap: () {
            Navigator.of(sheet).pop();
            setLanguage(locale);
          },
        ),
    ],
  ),
);

/// Small button of the entry pages: shows the language, opens the choice.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: const ValueKey('language-button'),
    onPressed: () => showLanguageSheet(context),
    style: TextButton.styleFrom(
      foregroundColor: RemboColors.night,
      minimumSize: const Size(48, 48),
    ),
    icon: const Icon(Icons.language_rounded, size: 20),
    label: Text(currentLanguageName, semanticsLabel: tr('Langue')),
  );
}

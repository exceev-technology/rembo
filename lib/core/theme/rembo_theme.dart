import 'package:flutter/material.dart';

import 'rembo_tokens.dart';

abstract final class RemboTheme {
  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: RemboColors.indigo,
          brightness: Brightness.light,
        ).copyWith(
          primary: RemboColors.indigo,
          onPrimary: Colors.white,
          secondary: RemboColors.night,
          onSecondary: Colors.white,
          surface: RemboColors.card,
          onSurface: RemboColors.ink,
          error: RemboColors.danger,
          outline: RemboColors.border,
        );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(RemboRadius.md),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: RemboColors.background,
      fontFamily: RemboFonts.body,
      fontFamilyFallback: RemboFonts.sansFallback,
      textTheme: const TextTheme(
        headlineMedium: RemboText.display,
        titleLarge: RemboText.title,
        titleMedium: RemboText.subtitle,
        bodyLarge: RemboText.body,
        bodyMedium: RemboText.body,
        bodySmall: RemboText.caption,
        labelSmall: RemboText.label,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: RemboColors.background,
        foregroundColor: RemboColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: RemboText.subtitle,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: RemboColors.indigo,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: RemboSpace.xl,
            vertical: RemboSpace.lg,
          ),
          textStyle: RemboText.subtitle,
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: RemboColors.night,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: RemboSpace.xl,
            vertical: RemboSpace.lg,
          ),
          side: const BorderSide(color: RemboColors.border, width: 1.5),
          textStyle: RemboText.subtitle,
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: RemboColors.indigo,
          minimumSize: const Size(48, 48),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: RemboColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: RemboSpace.lg,
          vertical: RemboSpace.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RemboRadius.md),
          borderSide: const BorderSide(color: RemboColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RemboRadius.md),
          borderSide: const BorderSide(color: RemboColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RemboRadius.md),
          borderSide: const BorderSide(color: RemboColors.indigo, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RemboRadius.md),
          borderSide: const BorderSide(color: RemboColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RemboRadius.md),
          borderSide: const BorderSide(color: RemboColors.danger, width: 2),
        ),
        hintStyle: RemboText.body.copyWith(color: RemboColors.muted),
      ),
      cardTheme: CardThemeData(
        color: RemboColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RemboRadius.lg),
          side: const BorderSide(color: RemboColors.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: RemboColors.card,
        selectedColor: RemboColors.surface,
        side: const BorderSide(color: RemboColors.border),
        labelStyle: RemboText.caption.copyWith(color: RemboColors.ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RemboRadius.pill),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: RemboColors.border,
        thickness: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: RemboColors.ink,
      ),
    );
  }
}

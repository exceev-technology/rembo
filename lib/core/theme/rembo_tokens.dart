import 'package:flutter/material.dart';

/// REMBO charter colours (issue #16). Text colours on tinted backgrounds
/// are darkened so every badge passes WCAG AA contrast.
abstract final class RemboColors {
  static const indigo = Color(0xFF4A35E0);
  static const night = Color(0xFF2E2A7E);
  static const ink = Color(0xFF0E0E14);
  static const surface = Color(0xFFEEEFFD);
  static const green = Color(0xFF1F9D6B);
  static const orange = Color(0xFFD9822B);

  static const background = Color(0xFFFAF9FF);
  static const card = Color(0xFFFFFFFF);
  static const muted = Color(0xFF626274);
  static const border = Color(0xFFDED9F2);
  static const danger = Color(0xFFB42318);

  static const successText = Color(0xFF13704B);
  static const successTint = Color(0xFFE3F4EC);
  static const infoText = Color(0xFF3A28B8);
  static const infoTint = surface;
  static const warningText = Color(0xFF8A4B0C);
  static const warningTint = Color(0xFFFBEEDD);
  static const dangerTint = Color(0xFFFDECEA);
  static const neutralText = Color(0xFF4A4A58);
  static const neutralTint = Color(0xFFEDEDF2);
}

/// Spacing scale, in logical pixels.
abstract final class RemboSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class RemboRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const pill = 999.0;
}

abstract final class RemboElevation {
  static const card = [
    BoxShadow(color: Color(0x0F2E2A7E), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const floating = [
    BoxShadow(color: Color(0x262E2A7E), blurRadius: 32, offset: Offset(0, 14)),
  ];
}

/// Archivo, Instrument Sans and JetBrains Mono are the charter fonts,
/// bundled as variable fonts in assets/fonts (SIL Open Font License).
abstract final class RemboFonts {
  static const display = 'Archivo';
  static const body = 'Instrument Sans';
  static const mono = 'JetBrains Mono';
  static const sansFallback = ['Roboto', 'Helvetica', 'Arial', 'sans-serif'];
  static const monoFallback = ['Roboto Mono', 'Menlo', 'monospace'];
}

/// Variable fonts ignore [FontWeight] on some engines, so every weighted
/// style also sets the matching `wght` axis.
abstract final class RemboText {
  static const display = TextStyle(
    fontFamily: RemboFonts.display,
    fontFamilyFallback: RemboFonts.sansFallback,
    fontSize: 32,
    height: 1.15,
    fontWeight: FontWeight.w800,
    fontVariations: [FontVariation('wght', 800)],
    letterSpacing: -1,
    color: RemboColors.ink,
  );
  static const title = TextStyle(
    fontFamily: RemboFonts.display,
    fontFamilyFallback: RemboFonts.sansFallback,
    fontSize: 22,
    height: 1.25,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700)],
    letterSpacing: -0.4,
    color: RemboColors.ink,
  );
  static const subtitle = TextStyle(
    fontFamily: RemboFonts.body,
    fontFamilyFallback: RemboFonts.sansFallback,
    fontSize: 17,
    height: 1.35,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wght', 600)],
    color: RemboColors.ink,
  );
  static const body = TextStyle(
    fontFamily: RemboFonts.body,
    fontFamilyFallback: RemboFonts.sansFallback,
    fontSize: 15,
    height: 1.5,
    color: RemboColors.ink,
  );
  static const caption = TextStyle(
    fontFamily: RemboFonts.body,
    fontFamilyFallback: RemboFonts.sansFallback,
    fontSize: 13,
    height: 1.4,
    color: RemboColors.muted,
  );
  static const label = TextStyle(
    fontFamily: RemboFonts.body,
    fontFamilyFallback: RemboFonts.sansFallback,
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700)],
    letterSpacing: 0.4,
  );

  /// Amounts, VAT and ICE numbers: tabular figures keep columns aligned.
  static const amount = TextStyle(
    fontFamily: RemboFonts.mono,
    fontFamilyFallback: RemboFonts.monoFallback,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wght', 600)],
    fontFeatures: [FontFeature.tabularFigures()],
    color: RemboColors.ink,
  );
}

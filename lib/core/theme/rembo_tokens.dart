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

/// Type roles. Archivo speaks for the brand: page titles and money.
/// Instrument Sans carries everything that is read: names, sentences,
/// labels. JetBrains Mono is kept for references (ICE, identifiers).
///
/// Variable fonts ignore [FontWeight] on some engines, so every weighted
/// style also sets the matching `wght` axis.
abstract final class RemboText {
  /// Large title of an entry page or a « moment ».
  static const display = TextStyle(
    fontFamily: RemboFonts.display,
    fontFamilyFallback: RemboFonts.sansFallback,
    fontSize: 30,
    height: 1.12,
    fontWeight: FontWeight.w800,
    fontVariations: [FontVariation('wght', 800)],
    letterSpacing: -1.1,
    color: RemboColors.ink,
  );

  /// Section title.
  static const title = TextStyle(
    fontFamily: RemboFonts.display,
    fontFamilyFallback: RemboFonts.sansFallback,
    fontSize: 19,
    height: 1.25,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700)],
    letterSpacing: -0.4,
    color: RemboColors.ink,
  );

  /// Name of a thing in a card or a row.
  static const subtitle = TextStyle(
    fontFamily: RemboFonts.body,
    fontFamilyFallback: RemboFonts.sansFallback,
    fontSize: 15.5,
    height: 1.3,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wght', 600)],
    letterSpacing: -0.1,
    color: RemboColors.ink,
  );
  static const body = TextStyle(
    fontFamily: RemboFonts.body,
    fontFamilyFallback: RemboFonts.sansFallback,
    fontSize: 14.5,
    height: 1.45,
    color: RemboColors.ink,
  );

  /// Secondary sentences: notes, hints, explanations. Smaller than the
  /// body so that most of them stay on one line.
  static const note = TextStyle(
    fontFamily: RemboFonts.body,
    fontFamilyFallback: RemboFonts.sansFallback,
    fontSize: 13,
    height: 1.35,
    color: RemboColors.muted,
  );

  /// Details under a name: date, person, count.
  static const caption = TextStyle(
    fontFamily: RemboFonts.body,
    fontFamilyFallback: RemboFonts.sansFallback,
    fontSize: 12.5,
    height: 1.35,
    color: RemboColors.muted,
  );

  /// Badges and small markers.
  static const label = TextStyle(
    fontFamily: RemboFonts.body,
    fontFamilyFallback: RemboFonts.sansFallback,
    fontSize: 11.5,
    height: 1.2,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wght', 600)],
    letterSpacing: 0.1,
  );

  /// Money, in the brand face: tabular figures keep columns aligned.
  static const amount = TextStyle(
    fontFamily: RemboFonts.display,
    fontFamilyFallback: RemboFonts.sansFallback,
    fontSize: 15.5,
    height: 1.2,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700)],
    fontFeatures: [FontFeature.tabularFigures()],
    letterSpacing: -0.2,
    color: RemboColors.ink,
  );

  /// References read character by character: ICE, identifiers.
  static const code = TextStyle(
    fontFamily: RemboFonts.mono,
    fontFamilyFallback: RemboFonts.monoFallback,
    fontSize: 13,
    fontFeatures: [FontFeature.tabularFigures()],
    color: RemboColors.ink,
  );
}

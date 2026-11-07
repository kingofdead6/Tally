import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'palette.dart';

/// Bricolage Grotesque for headings and every amount, Figtree for body text.
class AppText {
  AppText._();

  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle display(double size, {Color? color, FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.1,
        letterSpacing: -0.5,
        fontFeatures: _tabular,
      );

  static TextStyle money(double size, {Color? color, FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.0,
        letterSpacing: -0.3,
        fontFeatures: _tabular,
      );
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final tones = Tones(brightness == Brightness.dark);
    final scheme = ColorScheme.fromSeed(seedColor: Palette.cedar, brightness: brightness).copyWith(
      primary: tones.brand,
      onPrimary: brightness == Brightness.dark ? Palette.pine : Colors.white,
      surface: tones.sheet,
      onSurface: tones.text,
      error: tones.expense,
      outline: tones.line,
    );

    final body = GoogleFonts.figtreeTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(bodyColor: tones.text, displayColor: tones.text);

    final radius = BorderRadius.circular(14);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: tones.bg,
      textTheme: body.copyWith(
        headlineMedium: AppText.display(26, color: tones.text),
        headlineSmall: AppText.display(22, color: tones.text),
        titleLarge: AppText.display(19, color: tones.text, weight: FontWeight.w600),
        titleMedium: body.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: tones.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: tones.text,
        titleTextStyle: AppText.display(20, color: tones.text, weight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tones.sheet,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: TextStyle(color: tones.textSoft),
        labelStyle: TextStyle(color: tones.textSoft),
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: tones.line)),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: tones.line)),
        focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: tones.brand, width: 1.6)),
        errorBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: tones.expense)),
        focusedErrorBorder:
            OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: tones.expense, width: 1.6)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          foregroundColor: tones.text,
          side: BorderSide(color: tones.line),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: GoogleFonts.figtree(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tones.brand,
          textStyle: GoogleFonts.figtree(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tones.sheet,
        surfaceTintColor: Colors.transparent,
        indicatorColor: fade(tones.brand, 0.14),
        elevation: 0,
        height: 68,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tones.bg,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark ? Palette.frost : Palette.ink,
        contentTextStyle: GoogleFonts.figtree(
          color: brightness == Brightness.dark ? Palette.ink : Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerColor: tones.line,
      splashFactory: InkSparkle.splashFactory,
    );
  }
}

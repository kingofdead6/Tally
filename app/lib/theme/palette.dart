import 'package:flutter/material.dart';

/// Tally colour tokens. Green from the flag (deepened to read as money),
/// a softened flag red for spending, dinar gold for the budget.
class Palette {
  Palette._();

  static const cedar = Color(0xFF0B5D43); // brand
  static const cedarDeep = Color(0xFF063D2C);
  static const mint = Color(0xFF1FA971); // money in
  static const flagRed = Color(0xFFD6364F); // money out
  static const gold = Color(0xFFD9A93A); // budget

  // Light
  static const paper = Color(0xFFF3F6F2);
  static const sheet = Color(0xFFFFFFFF);
  static const ink = Color(0xFF13201B);
  static const inkSoft = Color(0xFF5B6B64);
  static const line = Color(0xFFE1E8E3);

  // Dark
  static const pine = Color(0xFF0D1512);
  static const pineSheet = Color(0xFF16211C);
  static const pineLine = Color(0xFF24332C);
  static const frost = Color(0xFFE8EFEB);
  static const frostSoft = Color(0xFF93A69D);

  /// Swatches offered when creating categories and wallets.
  static const swatches = <String>[
    '#0B5D43', '#1FA971', '#14B8A6', '#0EA5E9', '#3B82F6', '#6366F1',
    '#8B5CF6', '#EC4899', '#D6364F', '#F97316', '#D9A93A', '#84CC16',
    '#64748B', '#78716C',
  ];
}

Color fade(Color c, double opacity) => c.withAlpha((opacity.clamp(0, 1) * 255).round());

Color hexColor(String hex, {Color fallback = Palette.cedar}) {
  final h = hex.replaceAll('#', '');
  if (h.length != 6) return fallback;
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}

/// Semantic colours that change with light / dark mode.
class Tones {
  final bool dark;
  const Tones(this.dark);

  static Tones of(BuildContext context) => Tones(Theme.of(context).brightness == Brightness.dark);

  Color get bg => dark ? Palette.pine : Palette.paper;
  Color get sheet => dark ? Palette.pineSheet : Palette.sheet;
  Color get line => dark ? Palette.pineLine : Palette.line;
  Color get text => dark ? Palette.frost : Palette.ink;
  Color get textSoft => dark ? Palette.frostSoft : Palette.inkSoft;
  Color get income => Palette.mint;
  Color get expense => dark ? const Color(0xFFF0607A) : Palette.flagRed;
  Color get brand => dark ? const Color(0xFF3FC08E) : Palette.cedar;
}

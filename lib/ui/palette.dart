import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

/// Wählbare Grundfarben. Nicht gesetzte Farben bleiben beim Standard.
class AppPalette {
  const AppPalette({this.accent, this.migraine, this.period, this.background});

  static const defaultAccent = Color(0xFFD97BA4);
  static const defaultMigraine = Color(0xFFA98FD9);
  static const defaultPeriod = Color(0xFFE88A97);
  static const defaultBackground = Color(0xFFF8ECF0);

  final Color? accent;
  final Color? migraine;
  final Color? period;
  final Color? background;

  AppPalette copyWith({
    Color? accent,
    Color? migraine,
    Color? period,
    Color? background,
    bool resetAccent = false,
    bool resetMigraine = false,
    bool resetPeriod = false,
    bool resetBackground = false,
  }) => AppPalette(
    accent: resetAccent ? null : accent ?? this.accent,
    migraine: resetMigraine ? null : migraine ?? this.migraine,
    period: resetPeriod ? null : period ?? this.period,
    background: resetBackground ? null : background ?? this.background,
  );

  /// Schreibt die Farben in [AppColors]. Flächen und Rasterlinien leiten sich
  /// vom Hintergrund ab; ohne eigenen Hintergrund bleiben die Standard-Rosétöne.
  void apply() {
    AppColors.accent = accent ?? defaultAccent;
    AppColors.migraine = migraine ?? defaultMigraine;
    AppColors.period = period ?? defaultPeriod;
    final bg = background;
    if (bg == null) {
      AppColors.background = defaultBackground;
      AppColors.surface = const Color(0xFFFCE3EC);
      AppColors.surfaceHigh = const Color(0xFFEFCCD9);
    } else {
      final hsl = HSLColor.fromColor(bg);
      Color shade(double d) =>
          hsl.withLightness((hsl.lightness - d).clamp(0.0, 1.0)).toColor();
      AppColors.background = bg;
      AppColors.surface = shade(0.04);
      AppColors.surfaceHigh = shade(0.11);
    }
  }
}

/// Hält die gewählten Farben und speichert sie dauerhaft.
class PaletteController extends ChangeNotifier {
  PaletteController([AppPalette initial = const AppPalette()])
    : _palette = initial {
    _palette.apply();
  }

  static const _keys = {
    'accent': 'color_accent',
    'migraine': 'color_migraine',
    'period': 'color_period',
    'background': 'color_background',
  };

  AppPalette _palette;
  SharedPreferences? _prefs;

  AppPalette get palette => _palette;

  static Future<PaletteController> load() async {
    final prefs = await SharedPreferences.getInstance();
    Color? read(String k) {
      final v = prefs.getInt(_keys[k]!);
      return v == null ? null : Color(v);
    }

    final c = PaletteController(
      AppPalette(
        accent: read('accent'),
        migraine: read('migraine'),
        period: read('period'),
        background: read('background'),
      ),
    );
    c._prefs = prefs;
    return c;
  }

  Future<void> set(AppPalette p) async {
    _palette = p;
    p.apply();
    notifyListeners();
    final prefs = _prefs;
    if (prefs == null) return;
    for (final e in {
      'accent': p.accent,
      'migraine': p.migraine,
      'period': p.period,
      'background': p.background,
    }.entries) {
      final c = e.value;
      if (c == null) {
        await prefs.remove(_keys[e.key]!);
      } else {
        await prefs.setInt(_keys[e.key]!, c.toARGB32());
      }
    }
  }
}

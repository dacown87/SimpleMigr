import 'package:flutter/material.dart';

import '../data/database.dart';

/// Zartes Rosé statt Weiß: hell genug zum Lesen, aber ohne grelle Flächen,
/// weil Licht während einer Attacke oft unangenehm ist.
class AppColors {
  static const background = Color(0xFFF8ECF0);
  static const surface = Color(0xFFFCE3EC);
  static const surfaceHigh = Color(0xFFEFCCD9); // Felder (aus) und Rasterlinien
  static const text = Color(0xFF4F3A45);
  static const textDim = Color(0xFF9B7F8C);
  static const migraine = Color(0xFFA98FD9); // Lavendel, Farbe der Migräne-Awareness
  static const onMigraine = Color(0xFF2B1A4D);
  static const period = Color(0xFFE88A97); // Pastellrot
  static const accent = Color(0xFFD97BA4); // Rosa
  static const onAccent = Color(0xFF4A1F33);
  static const sunny = Color(0xFFE9C655); // Monatsfeier: festliches Gelb
  static const onSunny = Color(0xFF4A3D10);
  static const gold = Color(0xFFC99A1E); // Monatsfeier, dunkler als sunny
}

/// Farben hängen fest am Systemschlüssel.
Color? colorForKey(String? key) => switch (key) {
      SymptomKey.migraine => AppColors.migraine,
      SymptomKey.period => AppColors.period,
      _ => null,
    };

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.light,
    surface: AppColors.surface,
  ).copyWith(
    primary: AppColors.accent,
    onPrimary: Colors.white,
    onSurface: AppColors.text,
    secondaryContainer: AppColors.surfaceHigh,
    onSecondaryContainer: AppColors.text,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.surfaceHigh,
      height: 68,
    ),
    textTheme: ThemeData(brightness: Brightness.light).textTheme.apply(
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
        ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.accent.withValues(alpha: 0.45),
      checkmarkColor: AppColors.text,
      side: const BorderSide(color: AppColors.surfaceHigh),
    ),
    dividerColor: AppColors.surfaceHigh,
  );
}

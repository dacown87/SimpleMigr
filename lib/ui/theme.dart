import 'package:flutter/material.dart';

import '../data/database.dart';

/// Dunkel und kontrastarm: Licht ist während einer Attacke oft unangenehm.
class AppColors {
  static const background = Color(0xFF14161A);
  static const surface = Color(0xFF1E2127);
  static const surfaceHigh = Color(0xFF2A2E36);
  static const text = Color(0xFFC9CDD4);
  static const textDim = Color(0xFF8A909B);
  static const migraine = Color(0xFFB8A23A); // gelb
  static const onMigraine = Color(0xFF1B1800);
  static const period = Color(0xFF9E4B4B); // rot
  static const accent = Color(0xFF6C8EBF);
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
    brightness: Brightness.dark,
    surface: AppColors.surface,
  ).copyWith(primary: AppColors.accent);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      height: 68,
    ),
    textTheme: ThemeData(brightness: Brightness.dark).textTheme.apply(
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
        ),
    dividerColor: AppColors.surfaceHigh,
  );
}

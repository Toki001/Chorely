import 'package:flutter/material.dart';

abstract final class ChorelyColors {
  static const primary = Color(0xFF675CE8);
  static const background = Color(0xFFF8F9FC);
  static const ink = Color(0xFF171923);
  static const secondary = Color(0xFF596174);
  static const lavender = Color(0xFFEEE9FF);
  static const mint = Color(0xFFE0F6EB);
  static const border = Color(0xFFE6E9F0);
  static const attention = Color(0xFF955409);
}

ThemeData chorelyTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: ChorelyColors.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: ChorelyColors.primary,
    primary: ChorelyColors.primary,
    surface: Colors.white,
    onSurface: ChorelyColors.ink,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 34,
      height: 1.12,
      fontWeight: FontWeight.w700,
      letterSpacing: -1,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -.6,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      height: 1.25,
      fontWeight: FontWeight.w700,
    ),
    titleMedium: TextStyle(
      fontSize: 17,
      height: 1.3,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5),
    bodyMedium: TextStyle(fontSize: 14, height: 1.45),
  ).apply(bodyColor: ChorelyColors.ink, displayColor: ChorelyColors.ink),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 56),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.all(18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: ChorelyColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: ChorelyColors.border),
    ),
  ),
);

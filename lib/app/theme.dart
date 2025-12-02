import 'package:flutter/material.dart';

class AppTheme {
  // Light theme
  static final ThemeData lightTheme = ThemeData(
    primaryColor: const Color(0xFFB8E0D2),
    brightness: Brightness.light,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFB8E0D2),
      foregroundColor: Colors.black,
    ),
    scaffoldBackgroundColor: Colors.white,
    cardColor: const Color(0xFF8ABEB7),
    dividerColor: const Color(0xFF7AA89E),
    highlightColor: const Color(0xFF7AA89E),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFB8E0D2),
        foregroundColor: Colors.black,
      ),
    ),
  );

  // Dark theme (optional)
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.indigo,
  );
}
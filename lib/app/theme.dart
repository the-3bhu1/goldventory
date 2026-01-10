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
    dialogTheme: const DialogTheme(
      backgroundColor: highlightBackground,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFB8E0D2),
        foregroundColor: Colors.black,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.black,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.black),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Colors.black,
      selectionHandleColor: Colors.black,
    ),
  );

  static const Color highlightBackground = Color(0xFFF0F8F3);

  // Dark theme (optional)
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.indigo,
  );
}
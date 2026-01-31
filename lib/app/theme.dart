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
    dialogTheme: const DialogThemeData(
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
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFFC6E6DA);
        }
        return Colors.transparent; // Use default for unselected or transparent
      }),
      checkColor: WidgetStateProperty.all(Colors.black),
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: Colors.black,
      collapsedIconColor: Colors.black,
      textColor: Colors.black,
      collapsedTextColor: Colors.black,
    ),
  );

  static const Color highlightBackground = Color(0xFFF0F8F3);

  // Dark theme (optional)
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.indigo,
  );
}

class AppColors {
  static const Color inventoryCardBackground = Color(0xFFC6E6DA);
  static final Color shimmerBase = Colors.grey.shade300;
  static final Color shimmerHighlight = Colors.grey.shade200;
  static final Color surfaceVariant = Colors.grey.shade200;
  static final Color borderGrey = Colors.grey.shade300;
  static final Color textGrey = Colors.grey.shade600;
}
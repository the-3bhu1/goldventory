import 'package:flutter/material.dart';

class AppTheme {
  // Light theme
  static final ThemeData lightTheme = ThemeData(
    primaryColor: const Color(0xFF003D33), // Darker Teal for Headers
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF003D33),
      primary: const Color(0xFF003D33),
      onPrimary: Colors.white,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF0F9F8),
      foregroundColor: Color(0xFF003D33),
    ),
    scaffoldBackgroundColor: const Color(0xFFF0F9F8),
    cardColor: const Color(0xFFCEEDE4), // Light Teal for Cards
    dividerColor: const Color(0xFFD1EBE8),
    highlightColor: const Color(0xFFB3E0DB),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF003D33),
      foregroundColor: Colors.white,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Color(0xFFF0F8F3),
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

  static Color getHighlightBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFF0F9F8)
        : const Color(0xFF1E2626);
  }

  // Dark theme
  static final ThemeData darkTheme = ThemeData(
    primaryColor: const Color(0xFF00A28E),
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF00A28E),
      primary: const Color(0xFF00A28E),
      onPrimary: Colors.white,
      brightness: Brightness.dark,
    ).copyWith(
      secondary: const Color(0xFF00A28E),
      onSecondary: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF111717),
      foregroundColor: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFF111717),
    cardColor: const Color(0xFF232D2D), // Deep Slate/Teal Card
    dividerColor: const Color(0xFF2D3838),
    highlightColor: const Color(0xFF2D3838),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF00A28E),
      foregroundColor: Colors.white,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Color(0xFF1E2626),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00A28E),
        foregroundColor: Colors.white,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Colors.white,
      selectionHandleColor: Colors.white,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF00A28E);
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: Colors.white,
      collapsedIconColor: Colors.white,
      textColor: Colors.white,
      collapsedTextColor: Colors.white,
    ),
  );
}

class AppColors {
  static Color inventoryCardBackground(BuildContext context) => Theme.of(context).brightness == Brightness.light ? const Color(0xFFCEEDE4) : const Color(0xFF232D2D);
  static Color shimmerBase(BuildContext context) => Theme.of(context).brightness == Brightness.light ? const Color(0xFFD1EBE8) : const Color(0xFF1E2626);
  static Color shimmerHighlight(BuildContext context) => Theme.of(context).brightness == Brightness.light ? const Color(0xFFF0F9F8) : const Color(0xFF2D3838);
  static Color surfaceVariant(BuildContext context) => Theme.of(context).brightness == Brightness.light ? const Color(0xFFF0F9F8) : const Color(0xFF1E2626);
  static Color borderGrey(BuildContext context) => Theme.of(context).brightness == Brightness.light ? const Color(0xFFD1EBE8) : const Color(0xFF2D3838);
  static Color textGrey(BuildContext context) => Theme.of(context).brightness == Brightness.light ? const Color(0xFF003D33).withOpacity(0.7) : Colors.grey.shade400;
}
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: Colors.black,
      onPrimary: Colors.white,
      secondary: Colors.black,
      onSecondary: Colors.white,
      error: Colors.black,
      onError: Colors.white,
      background: Colors.white,
      onBackground: Colors.black,
      surface: Colors.white,
      onSurface: Colors.black,
    ),
    useMaterial3: true,
    cardTheme: const CardTheme(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 2,
    ),
    iconTheme: const IconThemeData(color: Colors.black),
    primaryIconTheme: const IconThemeData(color: Colors.white),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Colors.black),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: Colors.white,
      onPrimary: Colors.black,
      secondary: Colors.white,
      onSecondary: Colors.black,
      error: Colors.white,
      onError: Colors.black,
      background: Colors.black,
      onBackground: Colors.white,
      surface: Colors.black,
      onSurface: Colors.white,
    ),
    useMaterial3: true,
    cardTheme: CardTheme(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.black,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      centerTitle: true,
      elevation: 2,
    ),
    iconTheme: const IconThemeData(color: Colors.white),
    primaryIconTheme: const IconThemeData(color: Colors.black),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
    ),
  );
}
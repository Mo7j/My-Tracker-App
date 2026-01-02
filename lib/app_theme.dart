import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData buildAppTheme({bool dark = true}) {
  final overlayClear = MaterialStateProperty.resolveWith<Color?>(
    (states) => states.contains(MaterialState.hovered) || states.contains(MaterialState.focused) || states.contains(MaterialState.pressed)
        ? Colors.transparent
        : null,
  );

  if (dark) {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF0E1117),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3A7AFE),
        brightness: Brightness.dark,
        surface: const Color(0xFF151924),
        surfaceVariant: const Color(0xFF1B1F2C),
      ),
      textTheme: GoogleFonts.interTightTextTheme(base.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      cardColor: const Color(0xFF151924),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF0E1117),
        selectedItemColor: Color(0xFF3A7AFE),
        unselectedItemColor: Color(0xFF7D8395),
        showUnselectedLabels: true,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF3A7AFE),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(overlayColor: overlayClear),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(overlayColor: overlayClear),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(overlayColor: overlayClear),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(overlayColor: overlayClear),
      ),
    );
  } else {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3A7AFE),
        brightness: Brightness.light,
        surface: Colors.white,
        surfaceVariant: const Color(0xFFE8EDF5),
      ),
      textTheme: GoogleFonts.interTightTextTheme(base.textTheme).apply(
        bodyColor: const Color(0xFF111827),
        displayColor: const Color(0xFF111827),
      ),
      cardColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Color(0xFF111827),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Color(0xFF3A7AFE),
        unselectedItemColor: Color(0xFF6B7280),
        showUnselectedLabels: true,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF3A7AFE),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(overlayColor: overlayClear),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(overlayColor: overlayClear),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(overlayColor: overlayClear),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(overlayColor: overlayClear),
      ),
    );
  }
}

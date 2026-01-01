import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: const Color(0xFF0E1117),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF3A7AFE),
      brightness: Brightness.dark,
      surface: const Color(0xFF151924),
      surfaceVariant: const Color(0xFF1B1F2C),
    ),
    textTheme: GoogleFonts.montserratTextTheme(base.textTheme).apply(
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
  );
}

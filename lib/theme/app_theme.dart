import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Color palette ported 1:1 from the `:root` CSS custom properties
/// in doctor_app.html.
class AppColors {
  AppColors._();

  static const blue900 = Color(0xFF0B2A52);
  static const blue700 = Color(0xFF124A99);
  static const blue600 = Color(0xFF1D6FE0);
  static const blue500 = Color(0xFF3D8BFF);
  static const blue100 = Color(0xFFE5F0FF);
  static const blue50 = Color(0xFFF5F9FF);

  static const teal500 = Color(0xFF0EA5A4);
  static const teal100 = Color(0xFFE3F8F7);
  static const tealDark = Color(0xFF0B6D6C);

  static const green600 = Color(0xFF178A4C);
  static const green100 = Color(0xFFE5F8EC);

  static const amber600 = Color(0xFFB5720A);
  static const amber100 = Color(0xFFFDF1DC);
  static const amberDark = Color(0xFF7A4E06);
  static const amberBorder = Color(0xFFF3DBA6);

  static const red600 = Color(0xFFD0342C);
  static const red100 = Color(0xFFFBE8E7);

  static const ink900 = Color(0xFF0F1B2D);
  static const ink600 = Color(0xFF51617A);
  static const ink400 = Color(0xFF96A2B5);

  static const line = Color(0xFFE4EAF2);
  static const lineSoft = Color(0xFFEDF1F7);
  static const white = Color(0xFFFFFFFF);

  static const deviceBg = Color(0xFFDCE6F2);
}

class AppRadius {
  AppRadius._();
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 26.0;
}

class AppText {
  AppText._();

  static TextStyle display({
    double size = 15,
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.ink900,
  }) =>
      GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: weight, color: color);

  static TextStyle body({
    double size = 13,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.ink900,
  }) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

  static TextStyle mono({
    double size = 11,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.ink900,
  }) =>
      GoogleFonts.ibmPlexMono(fontSize: size, fontWeight: weight, color: color);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.blue50,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.blue600,
      primary: AppColors.blue600,
      secondary: AppColors.teal500,
      error: AppColors.red600,
    ),
    fontFamily: GoogleFonts.inter().fontFamily,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink900,
      displayColor: AppColors.ink900,
      fontFamily: GoogleFonts.inter().fontFamily,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.blue500, width: 1.4),
      ),
      hintStyle: AppText.body(color: AppColors.ink400),
    ),
  );
}

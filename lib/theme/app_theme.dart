import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Primary brand scale — ported from the website doctor dashboard's
/// `--color-brand-*` tokens (`AI-Clinic-project/src/doctor/doctor.css`) so
/// the app matches the site's actual current teal/green identity instead of
/// the old doctor_app.html-prototype blue. Token names keep the `blue*`
/// suffixes since ~50 files already reference them by name — only the values
/// changed, so this is a full rebrand with no call-site churn.
class AppColors {
  AppColors._();

  static const blue900 = Color(0xFF08453C); // brand-900
  static const blue700 = Color(0xFF0B6F5F); // brand-700
  static const blue600 = Color(0xFF0D8C77); // brand-600 — primary
  static const blue500 = Color(0xFF14A88F); // brand-500
  static const blue100 = Color(0xFFD2F9EE); // brand-100
  static const blue50 = Color(0xFFEEFDF9); // brand-50

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

  // In-progress status is deliberately a distinct orange, not the amber
  // used for "pending" — keep it out of the amber family so the two
  // statuses stay visually distinguishable.
  static const orange100 = Color(0xFFFDEBD6);
  static const orange600 = Color(0xFFC25A00);

  // Video-call "theater" surface — a dark palette used only inside the
  // call screen, kept as named tokens instead of inline hex so it reads
  // as intentional rather than a one-off.
  static const callSurfaceEnd = Color(0xFF173F72);
  static const callTextLight = Color(0xFFBFD2EC);
  static const callIconMuted = Color(0xFF7CA3D6);
  static const callTextMuted = Color(0xFF9FB6D9);
  static const callSurfaceDark = Color(0xFF14243B);
  static const callSurfaceDarker = Color(0xFF0B1E38);
}

class AppRadius {
  AppRadius._();
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 26.0;
}

/// Soft, slightly colored elevation scale — replaces the single ad-hoc
/// shadow that used to live inline in `AppCard` so every raised surface
/// (cards, buttons, the bottom nav, sheets) shares one depth language.
class AppShadow {
  AppShadow._();

  static List<BoxShadow> sm = [
    BoxShadow(color: AppColors.blue900.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1)),
  ];

  static List<BoxShadow> md = [
    BoxShadow(color: AppColors.blue900.withValues(alpha: 0.07), blurRadius: 12, offset: const Offset(0, 4)),
  ];

  static List<BoxShadow> lg = [
    BoxShadow(color: AppColors.blue900.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 8)),
  ];
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

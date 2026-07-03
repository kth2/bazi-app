import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App palette: cinnabar red on rice-paper cream, classic 命理 aesthetic.
const Color kPrimaryRed = Color(0xFF8B1E1E);
const Color kPaperCream = Color(0xFFFDF6EC);
const Color kInkBlack = Color(0xFF2B2B2B);
const Color kGoldAccent = Color(0xFFB8860B);

/// Five-element colors, used throughout chart displays.
const Map<String, Color> kElementColors = {
  '木': Color(0xFF2E7D32),
  '火': Color(0xFFC62828),
  '土': Color(0xFF8D6E63),
  '金': Color(0xFFB8860B),
  '水': Color(0xFF1565C0),
};

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimaryRed,
      surface: kPaperCream,
    ),
    scaffoldBackgroundColor: kPaperCream,
  );

  return base.copyWith(
    textTheme: GoogleFonts.notoSansScTextTheme(base.textTheme).apply(
      bodyColor: kInkBlack,
      displayColor: kInkBlack,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: kPrimaryRed,
      foregroundColor: kPaperCream,
      centerTitle: true,
      titleTextStyle: GoogleFonts.notoSerifSc(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: kPaperCream,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kPrimaryRed,
        foregroundColor: kPaperCream,
        minimumSize: const Size.fromHeight(52),
        textStyle: GoogleFonts.notoSansSc(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: kInkBlack.withValues(alpha: 0.2)),
      ),
    ),
    cardTheme: base.cardTheme.copyWith(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

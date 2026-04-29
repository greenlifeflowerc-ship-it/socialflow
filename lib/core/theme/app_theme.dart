import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Backward-compat constants
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color secondaryGold = Color(0xFFC5A028);
  static const Color backgroundBlack = Color(0xFF080808);
  static const Color surfaceDark = Color(0xFF141414);
  static const Color textWhite = Color(0xFFF0F0F0);
  static const Color textGrey = Color(0xFFB0B0B0);

  // Theme registry
  static ThemeData get darkTheme => midnightTheme;

  static ThemeData getTheme(String name) {
    switch (name) {
      case 'ocean':
        return oceanTheme;
      case 'amethyst':
        return amethystTheme;
      case 'emerald':
        return emeraldTheme;
      default:
        return midnightTheme;
    }
  }

  static ThemeData get midnightTheme => _build(
        bg: const Color(0xFF080808),
        surface: const Color(0xFF141414),
        primary: const Color(0xFFD4AF37),
        onPrimary: Colors.black,
      );

  static ThemeData get oceanTheme => _build(
        bg: const Color(0xFF060C16),
        surface: const Color(0xFF0D1929),
        primary: const Color(0xFF29B6F6),
        onPrimary: Colors.black,
      );

  static ThemeData get amethystTheme => _build(
        bg: const Color(0xFF080610),
        surface: const Color(0xFF110D1F),
        primary: const Color(0xFFCE93D8),
        onPrimary: Colors.black,
      );

  static ThemeData get emeraldTheme => _build(
        bg: const Color(0xFF060C08),
        surface: const Color(0xFF0D1A10),
        primary: const Color(0xFF66BB6A),
        onPrimary: Colors.black,
      );

  static ThemeData _build({
    required Color bg,
    required Color surface,
    required Color primary,
    required Color onPrimary,
  }) {
    final textColor = const Color(0xFFF0F0F0);
    final subTextColor = const Color(0xFFB0B0B0);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: primary.withOpacity(0.75),
        surface: surface,
        onPrimary: onPrimary,
        onSurface: textColor,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: textColor,
        displayColor: textColor,
      ).copyWith(
        displayLarge: GoogleFonts.playfairDisplay(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: GoogleFonts.playfairDisplay(
          color: primary,
          fontWeight: FontWeight.w600,
        ),
        bodySmall: GoogleFonts.poppins(
          color: subTextColor,
          fontSize: 12,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: primary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          fontFamily: GoogleFonts.playfairDisplay().fontFamily,
        ),
        iconTheme: IconThemeData(color: primary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 6,
          shadowColor: primary.withOpacity(0.35),
          minimumSize: const Size(0, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary.withOpacity(0.55)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        labelStyle: TextStyle(color: primary.withOpacity(0.8)),
        hintStyle: TextStyle(color: subTextColor.withOpacity(0.5)),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: primary.withOpacity(0.12)),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: primary.withOpacity(0.1)),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : Colors.grey[600],
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? primary.withOpacity(0.38)
              : Colors.grey.withOpacity(0.25),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: subTextColor,
        type: BottomNavigationBarType.fixed,
        elevation: 16,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: primary,
        textColor: textColor,
      ),
      iconTheme: IconThemeData(color: primary),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 24,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: const TextStyle(color: Color(0xFFF0F0F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

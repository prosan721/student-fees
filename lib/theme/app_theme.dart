import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Blends two colors together based on an amount (0.0 to 1.0)
  static Color blend(Color color1, Color color2, double amount) {
    return Color.fromRGBO(
      (color1.red * amount + color2.red * (1 - amount)).round(),
      (color1.green * amount + color2.green * (1 - amount)).round(),
      (color1.blue * amount + color2.blue * (1 - amount)).round(),
      1,
    );
  }

  static ThemeData getThemeData({required Color primaryColor, required bool isDark}) {
    // Generate theme colors exactly as calculations in original web app
    final primaryDark = blend(primaryColor, Colors.black, 0.65);
    final secondary = blend(primaryColor, Colors.white, 0.70);

    // Backgrounds
    final Color bg1;
    final Color bg2;
    if (isDark) {
      bg1 = blend(primaryColor, const Color(0xFF09090B), 0.05);
      bg2 = blend(primaryColor, const Color(0xFF121214), 0.08);
    } else {
      bg1 = blend(primaryColor, const Color(0xFF0F172A), 0.08);
      bg2 = blend(primaryColor, const Color(0xFF1E293B), 0.12);
    }

    final Color surface = isDark ? const Color(0xCC09090B) : const Color(0xCC1E293B);
    final Color textColor = Colors.white;
    const Color grayColor = Color(0xFF94A3B8);
    final Color border = isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.08);

    final baseTheme = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);

    return baseTheme.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondary,
        surface: surface,
        brightness: isDark ? Brightness.dark : Brightness.light,
      ),
      scaffoldBackgroundColor: Colors.transparent, // Background will be custom painted
      textTheme: GoogleFonts.plusJakartaSansTextTheme(baseTheme.textTheme).apply(
        bodyColor: textColor,
        displayColor: textColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0x9909090B) : const Color(0x990F172A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: grayColor,
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButtonStyleFrom(
          primaryColor: primaryColor,
          primaryDarkColor: primaryDark,
        ),
      ),
      cardTheme: CardTheme(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: border, width: 1),
        ),
        elevation: 0,
      ),
    );
  }

  // Custom Glassmorphism Box Decoration
  static BoxDecoration glassDecoration({
    required BuildContext context,
    required bool isDark,
    double opacity = 0.7,
    double borderRadius = 24.0,
    Color? customColor,
  }) {
    final border = isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.08);
    final bgColor = customColor ?? (isDark ? const Color(0xFF09090B) : const Color(0xFF1E293B));
    
    return BoxDecoration(
      color: bgColor.withOpacity(opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: border, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }
}

// Extends button style with custom colors to avoid static issues
extension ElevatedButtonStyleFrom on ElevatedButtonThemeData {
  static ButtonStyle style({
    required Color primaryColor,
    required Color primaryDarkColor,
    double borderRadius = 14.0,
  }) {
    return ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: primaryColor,
      shadowColor: Colors.black.withOpacity(0.06),
      elevation: 8,
      padding: const EdgeInsets.all(15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      textStyle: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// AutoTerra brand palette
class AppColors {
  static const brandBlack = Color(0xFF171717);
  static const brandRed = Color(0xFFF01D2C);
  static const brandWhite = Color(0xFFF5F5F5);
  static const canvas = Color(0xFFF0F0F0);

  // Aliases for compatibility
  static const primary = brandBlack;
  static const primaryDark = Color(0xFF0A0A0A);
  static const accent = brandRed;
  static const accentLight = Color(0xFFFF4455);
  static const surface = brandWhite;
  static const surfaceCard = Color(0xFFFCFCFC);
  static const surfaceDark = Color(0xFF1F1F1F);
  static const border = Color(0xFFD4D4D4);
  static const borderDark = Color(0xFF2E2E2E);
  static const textPrimary = Color(0xFF171717);
  static const textSecondary = Color(0xFF5A5A5A);
  static const textHint = Color(0xFF9A9A9A);
  static const textOnDark = Color(0xFFF5F5F5);
  static const textOnDarkMuted = Color(0xFF9A9A9A);

  // Functional colors - strict version
  static const success = Color(0xFF22C55E); // Strict green
  static const warning = Color(0xFFF59E0B); // Strict amber
  static const error = brandRed;
  static const info = brandBlack; // Use black for info to keep it strict

  // Status
  static const statusNew = brandBlack;
  static const statusActive = Color(0xFF171717); // Neutral for active
  static const statusPending = warning;
  static const statusBlocked = brandRed;

  // Category
  static const categoryA = brandRed;
  static const categoryB = brandBlack;
  static const categoryC = Color(0xFF5A5A5A);
}

// Chamfer helper
class AppShapes {
  static const double chamferSm = 4.0;
  static const double chamferMd = 8.0;
  static const double chamferLg = 16.0;

  // Top-right chamfer only (brand cut)
  static Path chamferPath(Size size, double cut) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width - cut, 0)
      ..lineTo(size.width, cut)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  // Double chamfer (top-right and bottom-left)
  static Path chamferPathDouble(Size size, double cut) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width - cut, 0)
      ..lineTo(size.width, cut)
      ..lineTo(size.width, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height - cut)
      ..close();
  }

  static ShapeBorder get strictShape => const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(2)),
      );

  static ShapeBorder get angularShape => const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      );
}

class _AppFonts {
  static TextStyle tektur({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) {
    return GoogleFonts.tektur(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle spaceGrotesk({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
}

class ChamferClipper extends CustomClipper<Path> {
  final double cut;
  final bool doubleCut;
  const ChamferClipper({this.cut = AppShapes.chamferMd, this.doubleCut = false});

  @override
  Path getClip(Size size) => doubleCut
      ? AppShapes.chamferPathDouble(size, cut)
      : AppShapes.chamferPath(size, cut);

  @override
  bool shouldReclip(ChamferClipper old) => old.cut != cut || old.doubleCut != doubleCut;
}

class AppTheme {
  static ThemeData get light {
    final baseTextTheme = _buildTextTheme();
    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.tektur().fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandBlack,
        primary: AppColors.brandBlack,
        secondary: AppColors.brandRed,
        surface: AppColors.brandWhite,
        error: AppColors.brandRed,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.canvas,
      textTheme: _buildTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.brandBlack,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: _AppFonts.tektur(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.8,
        ),
        iconTheme: const IconThemeData(color: Colors.white, size: 20),
        actionsIconTheme: const IconThemeData(color: Colors.white, size: 20),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
          side: BorderSide(color: AppColors.border, width: 1.5),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandRed,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: _AppFonts.tektur(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandBlack,
          side: const BorderSide(color: AppColors.brandBlack, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: _AppFonts.tektur(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brandRed,
          textStyle: _AppFonts.tektur(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.border, width: 1.5),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.brandBlack, width: 2.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.brandRed, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        labelStyle: _AppFonts.spaceGrotesk(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: _AppFonts.spaceGrotesk(
          color: AppColors.textHint,
          fontSize: 14,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1.5,
        space: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.brandBlack,
        selectedItemColor: AppColors.brandRed,
        unselectedItemColor: Colors.white.withValues(alpha: 0.4),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: _AppFonts.tektur(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: _AppFonts.tektur(
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: AppColors.brandRed,
        labelStyle: _AppFonts.tektur(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: AppColors.brandBlack,
        ),
        secondaryLabelStyle: _AppFonts.tektur(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: Colors.white,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColors.brandBlack, width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.brandRed,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.5),
        indicatorColor: AppColors.brandRed,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: AppColors.brandRed, width: 4),
        ),
        labelStyle: _AppFonts.tektur(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: _AppFonts.tektur(
          fontSize: 13,
          letterSpacing: 0.5,
        ),
        dividerColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.brandBlack,
        contentTextStyle: _AppFonts.spaceGrotesk(
          color: Colors.white,
          fontSize: 14,
        ),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        titleTextStyle: _AppFonts.tektur(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: 0.5,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        elevation: 0,
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: _AppFonts.tektur(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      ),
      displayMedium: _AppFonts.tektur(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
      headlineLarge: _AppFonts.tektur(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: 0.5,
      ),
      headlineMedium: _AppFonts.tektur(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineSmall: _AppFonts.tektur(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleLarge: _AppFonts.spaceGrotesk(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleMedium: _AppFonts.spaceGrotesk(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: _AppFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      bodyMedium: _AppFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
      bodySmall: _AppFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textHint,
      ),
      labelLarge: _AppFonts.tektur(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppColors.brandRed,
        letterSpacing: 1.0,
      ),
      labelMedium: _AppFonts.tektur(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.8,
      ),
      labelSmall: _AppFonts.tektur(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.textHint,
        letterSpacing: 0.8,
      ),
    );
  }
}

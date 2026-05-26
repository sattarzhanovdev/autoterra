import 'package:flutter/material.dart';

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

  static const success = Color(0xFF1A9E5C);
  static const warning = Color(0xFFD4920A);
  static const error = brandRed;
  static const info = Color(0xFF3A6EA5);

  // Status
  static const statusNew = Color(0xFF3A6EA5);
  static const statusActive = Color(0xFF1A9E5C);
  static const statusPending = Color(0xFFD4920A);
  static const statusBlocked = brandRed;

  // Category
  static const categoryA = brandRed;
  static const categoryB = Color(0xFF3A6EA5);
  static const categoryC = Color(0xFF5A5A5A);
}

// Chamfer helper
class AppShapes {
  static const double chamferSm = 8.0;
  static const double chamferMd = 12.0;
  static const double chamferLg = 20.0;

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

  // Bottom-left chamfer
  static Path chamferPathBL(Size size, double cut) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height - cut)
      ..close();
  }
}

class _AppFonts {
  static TextStyle tektur({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) {
    return TextStyle(
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
    return TextStyle(
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
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
}

class ChamferClipper extends CustomClipper<Path> {
  final double cut;
  const ChamferClipper({this.cut = AppShapes.chamferMd});

  @override
  Path getClip(Size size) => AppShapes.chamferPath(size, cut);

  @override
  bool shouldReclip(ChamferClipper old) => old.cut != cut;
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
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
          letterSpacing: 0.4,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandRed,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: _AppFonts.tektur(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandBlack,
          side: const BorderSide(color: AppColors.brandBlack, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: _AppFonts.tektur(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brandRed,
          textStyle: _AppFonts.tektur(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          borderSide: BorderSide(color: AppColors.brandBlack, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          borderSide: BorderSide(color: AppColors.brandRed),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: _AppFonts.spaceGrotesk(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
        hintStyle: _AppFonts.spaceGrotesk(
          color: AppColors.textHint,
          fontSize: 14,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.brandBlack,
        selectedItemColor: AppColors.brandRed,
        unselectedItemColor: Colors.white.withValues(alpha: 0.45),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: _AppFonts.spaceGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: _AppFonts.spaceGrotesk(fontSize: 11),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.brandWhite,
        selectedColor: AppColors.brandRed.withValues(alpha: 0.12),
        labelStyle: _AppFonts.spaceGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColors.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.brandRed,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.brandRed,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.brandRed,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: _AppFonts.spaceGrotesk(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: _AppFonts.spaceGrotesk(fontSize: 13),
        dividerColor: AppColors.border,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.brandBlack,
        contentTextStyle: _AppFonts.spaceGrotesk(
          color: Colors.white,
          fontSize: 14,
        ),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        titleTextStyle: _AppFonts.spaceGrotesk(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        ),
        elevation: 0,
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: _AppFonts.spaceGrotesk(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      displayMedium: _AppFonts.spaceGrotesk(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineLarge: _AppFonts.tektur(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineMedium: _AppFonts.tektur(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineSmall: _AppFonts.tektur(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleLarge: _AppFonts.spaceGrotesk(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleMedium: _AppFonts.spaceGrotesk(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: _AppFonts.inter(
        fontSize: 15,
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
        fontWeight: FontWeight.w700,
        color: AppColors.brandRed,
        letterSpacing: 0.5,
      ),
      labelMedium: _AppFonts.tektur(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.6,
      ),
      labelSmall: _AppFonts.tektur(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.textHint,
        letterSpacing: 0.6,
      ),
    );
  }
}

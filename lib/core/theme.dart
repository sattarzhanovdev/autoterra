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

  static const success = brandBlack;
  static const warning = Color(0xFF5A5A5A);
  static const error = brandRed;
  static const info = Color(0xFF9A9A9A);

  // Status
  static const statusNew = Color(0xFF9A9A9A);
  static const statusActive = brandBlack;
  static const statusPending = Color(0xFF5A5A5A);
  static const statusBlocked = brandRed;

  // Category
  static const categoryA = brandRed;
  static const categoryB = brandBlack;
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
  static TextStyle octosquares({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: 'TTOctosquares',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle neoris({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: 'TTNeoris',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
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
        titleTextStyle: _AppFonts.octosquares(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.8,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        elevation: 0,
        shape: const BeveledRectangleBorder(
          side: BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandRed,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const BeveledRectangleBorder(),
          textStyle: _AppFonts.octosquares(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandBlack,
          side: const BorderSide(color: AppColors.brandBlack, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const BeveledRectangleBorder(),
          textStyle: _AppFonts.octosquares(
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.brandBlack, width: 2)),
        labelStyle: _AppFonts.octosquares(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
        hintStyle: _AppFonts.neoris(color: AppColors.textHint, fontSize: 14),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.brandRed,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
        indicatorColor: AppColors.brandRed,
        labelStyle: _AppFonts.octosquares(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
        unselectedLabelStyle: _AppFonts.octosquares(fontSize: 11, fontWeight: FontWeight.w900),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.brandBlack,
        selectedItemColor: AppColors.brandRed,
        unselectedItemColor: Colors.white.withValues(alpha: 0.45),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: _AppFonts.neoris(fontSize: 11, fontWeight: FontWeight.bold),
        unselectedLabelStyle: _AppFonts.neoris(fontSize: 11),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: BeveledRectangleBorder(),
        elevation: 0,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: NoTransitionsBuilder(),
          TargetPlatform.iOS: NoTransitionsBuilder(),
          TargetPlatform.linux: NoTransitionsBuilder(),
          TargetPlatform.macOS: NoTransitionsBuilder(),
          TargetPlatform.windows: NoTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: _AppFonts.octosquares(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
      headlineMedium: _AppFonts.octosquares(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
      titleLarge: _AppFonts.octosquares(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: 0.5),
      bodyLarge: _AppFonts.neoris(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
      bodyMedium: _AppFonts.neoris(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
      labelLarge: _AppFonts.octosquares(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.brandBlack, letterSpacing: 0.8),
    );
  }
}

class NoTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

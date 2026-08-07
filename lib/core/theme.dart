import 'package:flutter/material.dart';

// AutoTerra brand palette
class AppColors {
  static const brandBlack = Color(0xFF171717);
  static const brandRed = Color(0xFFF01D2C);
  static const brandWhite = Color(0xFFF5F5F5);

  // Фон страницы — фирменный белый (гайдбук, стр. 12). Карточки отделяются
  // от него не оттенком, а фирменной обводкой [border].
  static const canvas = brandWhite;

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

/// Фирменный срез. Гайдбук, стр. 16: у форм фаска (chamfer) вместо
/// стандартного скругления, на макетах она ставится в правый верхний угол.
/// Нижняя граница среза по гайду — 10 px, поэтому мельче [chamferSm] не берём.
class AppShapes {
  static const double chamferSm = 10.0;
  static const double chamferMd = 14.0;
  static const double chamferLg = 20.0;

  static BorderRadius cut([double size = chamferMd]) =>
      BorderRadius.only(topRight: Radius.circular(size));

  /// Ответная фаска для нижней половины составной формы. Гайдбук, стр. 16:
  /// формы, стоящие друг за другом, соединяются в пару — верхняя срезана
  /// справа сверху, нижняя слева снизу.
  static BorderRadius cutPaired([double size = chamferMd]) =>
      BorderRadius.only(bottomLeft: Radius.circular(size));

  static BeveledRectangleBorder border({
    double size = chamferMd,
    BorderSide side = BorderSide.none,
  }) =>
      BeveledRectangleBorder(borderRadius: cut(size), side: side);
}

/// Начертания — гайдбук, стр. 13. У Octosquares в айдентике есть только
/// Medium (500), у Neoris — Regular (400) для текста и DemiBold (600) для
/// акцентов. Других весов в брендбуке нет, поэтому не изобретаем.
class _AppFonts {
  static const _medium = FontWeight.w500;
  static const _regular = FontWeight.w400;
  static const _demiBold = FontWeight.w600;

  static TextStyle octosquares({
    double? fontSize,
    FontWeight fontWeight = _medium,
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
    FontWeight fontWeight = _regular,
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

  static TextStyle neorisAccent({
    double? fontSize,
    Color? color,
    double? letterSpacing,
  }) =>
      neoris(
        fontSize: fontSize,
        fontWeight: _demiBold,
        color: color,
        letterSpacing: letterSpacing,
      );
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
          color: Colors.white,
          letterSpacing: 0.8,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        elevation: 0,
        shape: AppShapes.border(
          size: AppShapes.chamferMd,
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
          shape: AppShapes.border(size: AppShapes.chamferSm),
          textStyle: _AppFonts.octosquares(
            fontSize: 13,
            letterSpacing: 0.8,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandBlack,
          side: const BorderSide(color: AppColors.brandBlack, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: AppShapes.border(size: AppShapes.chamferSm),
          textStyle: _AppFonts.octosquares(fontSize: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: AppShapes.cut(AppShapes.chamferSm), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: AppShapes.cut(AppShapes.chamferSm), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: AppShapes.cut(AppShapes.chamferSm), borderSide: const BorderSide(color: AppColors.brandBlack, width: 2)),
        labelStyle: _AppFonts.octosquares(color: AppColors.textSecondary, fontSize: 11),
        hintStyle: _AppFonts.neoris(color: AppColors.textHint, fontSize: 14),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.brandRed,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
        indicatorColor: AppColors.brandRed,
        labelStyle: _AppFonts.octosquares(fontSize: 11, letterSpacing: 0.5),
        unselectedLabelStyle: _AppFonts.octosquares(fontSize: 11),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.brandBlack,
        selectedItemColor: AppColors.brandRed,
        unselectedItemColor: Colors.white.withValues(alpha: 0.45),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: _AppFonts.neorisAccent(fontSize: 11),
        unselectedLabelStyle: _AppFonts.neoris(fontSize: 11),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: AppShapes.border(size: AppShapes.chamferLg),
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
      displayLarge: _AppFonts.octosquares(fontSize: 28, color: AppColors.textPrimary),
      headlineMedium: _AppFonts.octosquares(fontSize: 18, color: AppColors.textPrimary),
      titleLarge: _AppFonts.octosquares(fontSize: 15, color: AppColors.textPrimary, letterSpacing: 0.5),
      bodyLarge: _AppFonts.neoris(fontSize: 15, color: AppColors.textPrimary),
      bodyMedium: _AppFonts.neoris(fontSize: 14, color: AppColors.textSecondary),
      labelLarge: _AppFonts.octosquares(fontSize: 13, color: AppColors.brandBlack, letterSpacing: 0.8),
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

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Логотип по гайдбуку.
///
/// Минимальные размеры (стр. 10) заданы по **ширине**, а не по высоте:
/// упрощённая горизонтальная версия — от 120 px, фирменный знак — от 64 px.
/// Если места меньше, логотип не сжимаем, а откатываемся на знак; если и знак
/// не помещается — не рисуем ничего, это лучше нечитаемого логотипа.
///
/// Цветовые пары (стр. 07): на тёмном фоне текстовая часть белая, на светлом —
/// фирменная чёрная. Вручную логотип не перекрашиваем (стр. 11) — берём
/// подготовленный файл.
class AppLogo extends StatelessWidget {
  static const double _logoAspectRatio = 1800 / 201;
  static const double _minFullLogoWidth = 120;
  static const double _minIconSize = 64;

  final double? width;
  final double height;
  final bool showText;

  /// Фон, на котором стоит логотип. `true` — тёмный, берём белую текстовую
  /// часть; `false` — светлый, берём чёрную.
  final bool onDarkBackground;
  final bool fallbackToIcon;

  const AppLogo({
    super.key,
    this.width,
    this.height = 40,
    this.showText = true,
    this.onDarkBackground = true,
    this.fallbackToIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = width ?? constraints.maxWidth;
        final fullLogoWidth = height * _logoAspectRatio;
        // Охранное поле (стр. 09) — задаётся геометрией логотипа.
        final fullLogoClearSpace = height * 0.25;
        final iconClearSpace = height * 0.2;

        final fitsFullLogo = availableWidth.isInfinite ||
            availableWidth >= fullLogoWidth + fullLogoClearSpace * 2;

        if (showText && fullLogoWidth >= _minFullLogoWidth && fitsFullLogo) {
          return Padding(
            padding: EdgeInsets.all(fullLogoClearSpace),
            child: SvgPicture.asset(
              onDarkBackground ? 'assets/logo.svg' : 'assets/logo-dark.svg',
              height: height,
              width: fullLogoWidth,
              fit: BoxFit.contain,
            ),
          );
        }

        if ((!showText || fallbackToIcon) && height >= _minIconSize) {
          return Padding(
            padding: EdgeInsets.all(iconClearSpace),
            child: SvgPicture.asset(
              // Знак без подложки — assets/icon.svg это ярлык приложения
              // (белый знак на красном квадрате), внутри интерфейса он не к месту.
              'assets/mark.svg',
              width: height,
              height: height,
              fit: BoxFit.contain,
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

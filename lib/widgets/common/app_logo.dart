import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppLogo extends StatelessWidget {
  static const double _logoAspectRatio = 1800 / 201;
  static const double _minFullLogoHeight = 28;
  static const double _minIconSize = 28;

  final double? width;
  final double height;
  final bool showText;
  final bool darkMode;
  final bool fallbackToIcon;

  const AppLogo({
    super.key,
    this.width,
    this.height = 40,
    this.showText = true,
    this.darkMode = true,
    this.fallbackToIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = width ?? constraints.maxWidth;
        final fullLogoWidth = height * _logoAspectRatio;
        final fullLogoClearSpace = height * 0.25;
        final iconClearSpace = height * 0.2;
        final canShowFullLogo =
            showText &&
            height >= _minFullLogoHeight &&
            (availableWidth.isInfinite ||
                availableWidth >= fullLogoWidth + fullLogoClearSpace * 2);

        if (canShowFullLogo) {
          return Padding(
            padding: EdgeInsets.all(fullLogoClearSpace),
            child: SvgPicture.asset(
              'assets/logo.svg',
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
              'assets/icon.svg',
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

class AppLogoSmall extends StatelessWidget {
  final double size;

  const AppLogoSmall({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final safeZone = size * 0.2;
    if (size < AppLogo._minIconSize) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.all(safeZone),
      child: SvgPicture.asset(
        'assets/icon.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

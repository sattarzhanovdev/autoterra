import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppLogo extends StatelessWidget {
  final double? width;
  final double height;
  final bool showText;
  final bool darkMode;

  const AppLogo({
    super.key,
    this.width,
    this.height = 40,
    this.showText = true,
    this.darkMode = true,
  });

  @override
  Widget build(BuildContext context) {
    // Safe zone is approx 1/4 of height according to geometry logic
    final safeZone = height * 0.25;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: safeZone),
      child: showText
          ? SvgPicture.asset(
              'assets/logo.svg',
              height: height,
              width: width, // Allow auto-scale if null
              fit: BoxFit.contain,
            )
          : SvgPicture.asset(
              'assets/icon.svg',
              height: height,
              width: width,
              fit: BoxFit.contain,
            ),
    );
  }
}

class AppLogoSmall extends StatelessWidget {
  final double size;

  const AppLogoSmall({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final safeZone = size * 0.2;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: safeZone),
      child: SvgPicture.asset(
        'assets/icon.svg',
        width: size * 1.1,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

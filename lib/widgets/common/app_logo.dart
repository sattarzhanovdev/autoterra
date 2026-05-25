import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppLogo extends StatelessWidget {
  final double width;
  final double height;
  final bool showText;
  final bool darkMode;

  const AppLogo({
    super.key,
    this.width = 140,
    this.height = 40,
    this.showText = true,
    this.darkMode = true,
  });

  @override
  Widget build(BuildContext context) {
    if (showText) {
      return SvgPicture.asset(
        'assets/logo.svg',
        width: width,
        height: height,
        fit: BoxFit.contain,
      );
    }

    return SvgPicture.asset(
      'assets/icon.svg',
      width: height * 1.1,
      height: height,
      fit: BoxFit.contain,
    );
  }
}

class AppLogoSmall extends StatelessWidget {
  final double size;

  const AppLogoSmall({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icon.svg',
      width: size * 1.1,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

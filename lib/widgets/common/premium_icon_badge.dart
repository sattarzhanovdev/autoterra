import 'package:flutter/material.dart';

import '../../core/theme.dart';

class PremiumIconBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final Color iconColor;

  const PremiumIconBadge({
    super.key,
    required this.icon,
    this.size = 42,
    this.iconSize = 20,
    this.iconColor = AppColors.brandRed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: BeveledRectangleBorder(
          side: BorderSide(color: AppColors.brandBlack, width: 1.0),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 1,
            left: 1,
            child: Container(
              width: 5,
              height: 5,
              color: AppColors.brandRed,
            ),
          ),
          Center(
            child: Icon(icon, color: iconColor, size: iconSize),
          ),
        ],
      ),
    );
  }
}

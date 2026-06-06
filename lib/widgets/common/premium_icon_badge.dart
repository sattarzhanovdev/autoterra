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
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.brandBlack, width: 1.5),
        borderRadius: BorderRadius.zero,
      ),
      child: Stack(
        children: [
          Positioned(
            top: 2,
            left: 2,
            child: Container(
              width: 6,
              height: 6,
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

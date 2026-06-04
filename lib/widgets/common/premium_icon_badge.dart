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
        border: Border.all(color: AppColors.border, width: 1.5),
        borderRadius: BorderRadius.zero,
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 3,
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

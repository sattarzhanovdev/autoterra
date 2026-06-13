import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Icon badge with straight top edge, two vertical "pin" lines at top,
/// and rounded bottom corners — matching AutoTerra's brand design.
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
    // Pin line dimensions scale with badge size
    final double pinHeight = size * 0.18;
    final double pinWidth = 1.5;
    final double pinSpacing = size * 0.18;
    final double bottomRadius = size * 0.28;

    return SizedBox(
      width: size,
      height: size + pinHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Two thin vertical red lines ("pins") at the top
          SizedBox(
            height: pinHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: pinWidth,
                  height: pinHeight,
                  color: AppColors.brandRed,
                ),
                SizedBox(width: pinSpacing),
                Container(
                  width: pinWidth,
                  height: pinHeight,
                  color: AppColors.brandRed,
                ),
              ],
            ),
          ),
          // Main badge body: straight top, rounded bottom
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border, width: 1.0),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(bottomRadius),
                bottomRight: Radius.circular(bottomRadius),
              ),
            ),
            child: Center(
              child: Icon(icon, color: iconColor, size: iconSize),
            ),
          ),
        ],
      ),
    );
  }
}

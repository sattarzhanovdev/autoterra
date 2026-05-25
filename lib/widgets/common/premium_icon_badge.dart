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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF1F1F1)],
        ),
        border: Border.all(color: const Color(0xFFE3E3E3), width: 1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 10,
            right: 10,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.brandRed.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(2),
              ),
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

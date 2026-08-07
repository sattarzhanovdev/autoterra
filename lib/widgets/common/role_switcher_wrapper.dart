import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';

class RoleSwitcherWrapper extends StatelessWidget {
  final Widget child;

  const RoleSwitcherWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Only show in debug/profile mode
    if (!kDebugMode && !kProfileMode) {
      return child;
    }

    return Stack(
      children: [
        child,
        Positioned(
          bottom: 100,
          right: 0,
          child: _RoleSwitcherButton(),
        ),
      ],
    );
  }
}

class _RoleSwitcherButton extends StatefulWidget {
  @override
  State<_RoleSwitcherButton> createState() => _RoleSwitcherButtonState();
}

class _RoleSwitcherButtonState extends State<_RoleSwitcherButton> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isOpen)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: AppColors.brandBlack,
            shape: const BeveledRectangleBorder(
              side: BorderSide(color: AppColors.brandRed, width: 0.5),
            ),
            child: Container(
              width: 200,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: UserRole.values.map((role) {
                  final isSelected = authService.currentRole == role;
                  return GestureDetector(
                    onTap: () {
                      authService.setRole(role);
                      setState(() => _isOpen = false);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      color: Colors.transparent,
                      child: Text(
                        role.label.toUpperCase(),
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.brandRed
                              : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 0.5,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        GestureDetector(
          onLongPress: () {
            setState(() => _isOpen = !_isOpen);
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: const ShapeDecoration(
              color: AppColors.brandBlack,
              shape: BeveledRectangleBorder(),
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              color: AppColors.brandRed,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}

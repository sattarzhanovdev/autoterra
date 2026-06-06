import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../core/constants.dart';

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
          Container(
            width: 200,
            decoration: const BoxDecoration(
              color: Color(0xFF171717),
              borderRadius: BorderRadius.zero,
            ),
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
                      role.name.toUpperCase(),
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFFF01D2C)
                            : Colors.white,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        GestureDetector(
          onLongPress: () {
            setState(() => _isOpen = !_isOpen);
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFF171717),
              borderRadius: BorderRadius.zero,
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              color: Color(0xFFF01D2C),
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}

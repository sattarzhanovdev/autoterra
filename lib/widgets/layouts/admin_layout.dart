import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/admin/admin_integration_screen.dart';
import '../../screens/admin/admin_manager_tasks_screen.dart';
import '../../screens/profile/profile_screen.dart';

final GlobalKey<AdminLayoutState> adminLayoutKey = GlobalKey<AdminLayoutState>();

class AdminLayout extends StatefulWidget {
  AdminLayout() : super(key: adminLayoutKey);

  @override
  State<AdminLayout> createState() => AdminLayoutState();
}

class AdminLayoutState extends State<AdminLayout> {
  int _currentIndex = 0;

  void setTab(int index) {
    setState(() => _currentIndex = index);
  }

  final List<Widget> _screens = [
    const AdminDashboardScreen(),
    const AdminIntegrationScreen(),
    const AdminManagerTasksScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF171717), width: 2)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: const Color(0xFF171717),
          selectedItemColor: const Color(0xFFF01D2C),
          unselectedItemColor: Colors.white.withValues(alpha: 0.5),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'ДАШБОРД'),
            BottomNavigationBarItem(icon: Icon(Icons.sync_alt_outlined), activeIcon: Icon(Icons.sync_alt), label: 'ИНТЕГРАЦИИ 1С'),
            BottomNavigationBarItem(icon: Icon(Icons.task_outlined), activeIcon: Icon(Icons.task), label: 'ЗАДАЧИ'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'ПРОФИЛЬ'),
          ],
        ),
      ),
    );
  }
}

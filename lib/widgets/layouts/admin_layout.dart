import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/admin/admin_integration_screen.dart';
import '../../screens/admin/admin_manager_tasks_screen.dart';
import '../../screens/manager/manager_clients_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../widgets/common/brand_icon.dart';

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

  // Главный менеджер видит клиентов всех регионов — тот же экран, что и
  // региональный менеджер, но сервер отдаёт ему полную выборку. Отсюда же
  // работает выгрузка списка в Excel, Word, PDF и CSV.
  final List<Widget> _screens = [
    const AdminDashboardScreen(),
    ManagerClientsScreen(),
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
          border: Border(top: BorderSide(color: AppColors.brandBlack, width: 2)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: AppColors.brandBlack,
          selectedItemColor: AppColors.brandRed,
          unselectedItemColor: Colors.white.withValues(alpha: 0.5),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'ДАШБОРД'),
            BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'КЛИЕНТЫ'),
            BottomNavigationBarItem(icon: Icon(Icons.sync_alt_outlined), activeIcon: Icon(Icons.sync_alt), label: 'ИНТЕГРАЦИИ 1С'),
            BottomNavigationBarItem(icon: Icon(Icons.task_outlined), activeIcon: Icon(Icons.task), label: 'ЗАДАЧИ'),
            BottomNavigationBarItem(icon: BrandIcon(BrandIcons.person), activeIcon: BrandIcon(BrandIcons.person), label: 'ПРОФИЛЬ'),
          ],
        ),
      ),
    );
  }
}

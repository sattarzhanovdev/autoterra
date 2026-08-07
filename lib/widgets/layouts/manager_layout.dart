import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../screens/manager/manager_clients_screen.dart';
import '../../screens/manager/manager_tasks_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../core/theme.dart';

class ManagerLayout extends StatefulWidget {
  const ManagerLayout({super.key});

  @override
  State<ManagerLayout> createState() => _ManagerLayoutState();
}

class _ManagerLayoutState extends State<ManagerLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ManagerClientsScreen(),
    ManagerTasksScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandWhite,
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
          unselectedItemColor: Colors.white.withOpacity(0.5),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.person_2_fill, size: 24),
              label: 'КЛИЕНТЫ',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.checkmark_square_fill, size: 24),
              label: 'ЗАДАЧИ',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.person_fill, size: 24),
              label: 'ПРОФИЛЬ',
            ),
          ],
        ),
      ),
    );
  }
}

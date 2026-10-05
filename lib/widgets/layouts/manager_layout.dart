import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../screens/manager/manager_clients_screen.dart';
import '../../screens/manager/manager_tasks_screen.dart';
import '../../screens/manager/manager_dashboard_screen.dart';
import '../../screens/manager/manager_orders_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../core/theme.dart';
import '../../widgets/common/brand_icon.dart';

class ManagerLayout extends StatefulWidget {
  const ManagerLayout({super.key});

  @override
  State<ManagerLayout> createState() => _ManagerLayoutState();
}

class _ManagerLayoutState extends State<ManagerLayout> {
  int _currentIndex = 0;
  String? _clientFilter;
  String? _orderFilter;

  void _openClients(String? filter) => setState(() { _clientFilter = filter; _currentIndex = 1; });
  void _openOrders(String? filter) => setState(() { _orderFilter = filter; _currentIndex = 2; });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandWhite,
      body: [
        ManagerDashboardScreen(openClients: _openClients, openOrders: _openOrders),
        ManagerClientsScreen(key: ValueKey('clients-$_clientFilter'), initialStatus: _clientFilter),
        ManagerOrdersScreen(key: ValueKey('orders-$_orderFilter'), statusFilter: _orderFilter),
        const ManagerTasksScreen(),
        const ProfileScreen(),
      ][_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.brandBlack, width: 2)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() {
            if (index == 1) _clientFilter = null;
            if (index == 2) _orderFilter = null;
            _currentIndex = index;
          }),
          backgroundColor: AppColors.brandBlack,
          selectedItemColor: AppColors.brandRed,
          unselectedItemColor: Colors.white.withValues(alpha: 0.5),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'ОБЗОР'),
            // «Клиенты» — группа людей, такой иконки в фирменном паке нет,
            // а одиночная фигура уже занята «Профилем» ниже.
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline, size: 24),
              label: 'КЛИЕНТЫ',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: 'ЗАКАЗЫ'),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.checkmark_square_fill, size: 24),
              label: 'ЗАДАЧИ',
            ),
            BottomNavigationBarItem(
              icon: Icon(BrandIcons.person, size: 24),
              label: 'ПРОФИЛЬ',
            ),
          ],
        ),
      ),
    );
  }
}

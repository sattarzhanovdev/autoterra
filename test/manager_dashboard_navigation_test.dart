import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autoterra/screens/manager/manager_dashboard_screen.dart';
import 'package:autoterra/services/data_repository.dart';

class DashboardRepository extends DataRepository {
  @override
  Future<Map<String, dynamic>> managerDashboard({String? regionId, String? distributorId}) async => {
    'totalClients': 2, 'newRegistrations': 1, 'activeOrders': 3,
    'totalOrders': 4, 'fulfilledOrders': 1, 'totalTurnover': 1000,
  };
}

void main() {
  testWidgets('manager dashboard cards open matching filtered sections', (tester) async {
    String? selectedSection;
    String? selectedFilter;
    await tester.pumpWidget(MaterialApp(home: ManagerDashboardScreen(
      repository: DashboardRepository(),
      openClients: (filter) { selectedSection = 'clients'; selectedFilter = filter; },
      openOrders: (filter) { selectedSection = 'orders'; selectedFilter = filter; },
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('НОВЫЕ РЕГИСТРАЦИИ'));
    expect(selectedSection, 'clients');
    expect(selectedFilter, 'pending');
    await tester.tap(find.text('АКТИВНЫЕ ЗАКАЗЫ'));
    expect(selectedSection, 'orders');
    expect(selectedFilter, 'active');
  });
}

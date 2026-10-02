import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autoterra/models/models.dart';
import 'package:autoterra/services/auth_service.dart';
import 'package:autoterra/widgets/common/role_switcher_wrapper.dart';

void main() {
  testWidgets('Debug role switcher updates its selected role', (tester) async {
    authService.setRole(UserRole.client);
    await tester.pumpWidget(const MaterialApp(home: RoleSwitcherWrapper(child: Scaffold())));
    await tester.longPress(find.byIcon(Icons.admin_panel_settings));
    await tester.pump();
    await tester.tap(find.text('КУРЬЕР'));
    await tester.pump();
    expect(authService.currentRole, UserRole.courier);
    authService.setRole(UserRole.client);
  });
}

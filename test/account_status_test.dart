import 'package:autoterra/screens/auth/account_status_screen.dart';
import 'package:autoterra/services/api_client.dart';
import 'package:autoterra/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});
    await ApiClient.loadSavedToken();
  });
  tearDown(() async {
    await ApiClient.clearToken();
  });

  test('Client access fails closed until backend confirms active status', () {
    for (final status in [null, 'new', 'under_review', 'blocked', 'archived']) {
      authService.updateFromBackendUser({
        'role': 'autoservice',
        'status': status,
      });
      expect(authService.needsApproval, isTrue);
    }
    authService.updateFromBackendUser({
      'role': 'autoservice',
      'status': 'active',
    });
    expect(authService.needsApproval, isFalse);
    authService.restrictAccount('blocked');
    expect(authService.needsApproval, isTrue);
    authService.updateFromBackendUser({'role': 'admin', 'status': 'active'});
    expect(authService.needsApproval, isFalse);
  });

  testWidgets('Pending account has a status retry and no business actions', (
    tester,
  ) async {
    authService.updateFromBackendUser({'role': 'autoservice', 'status': 'new'});
    await tester.pumpWidget(const MaterialApp(home: AccountStatusScreen()));
    await tester.pump();
    expect(find.text('АККАУНТ НА ПРОВЕРКЕ'), findsOneWidget);
    expect(find.text('ПРОВЕРИТЬ СТАТУС'), findsOneWidget);
    expect(find.text('ВЫЙТИ'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'approval is refreshed automatically and stops after leaving screen',
    (tester) async {
      var refreshes = 0;
      authService.updateFromBackendUser({
        'role': 'autoservice',
        'status': 'new',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: AccountStatusScreen(
            refreshUser: () async {
              refreshes++;
              authService.updateFromBackendUser({
                'role': 'autoservice',
                'status': 'active',
              });
            },
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 15));
      await tester.pump();
      expect(refreshes, 1);
      expect(authService.needsApproval, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
      expect(refreshes, 1);
    },
  );

  testWidgets('Blocked account displays manager contact guidance', (
    tester,
  ) async {
    authService.updateFromBackendUser({
      'role': 'autoservice',
      'status': 'blocked',
    });
    await tester.pumpWidget(const MaterialApp(home: AccountStatusScreen()));
    await tester.pump();
    expect(find.text('ДОСТУП ОГРАНИЧЕН'), findsOneWidget);
    expect(
      find.text(
        'Доступ к аккаунту ограничен. Обратитесь к менеджеру AutoTerra.',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });
}

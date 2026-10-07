import 'dart:convert';
import 'package:autoterra/models/models.dart';
import 'package:autoterra/screens/finance/yookassa_finance_screen.dart';
import 'package:autoterra/services/api_client.dart';
import 'package:autoterra/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> report({bool unknown = false}) => {
  'summary': {
    'paidOrders': 1,
    'sales': '1000.00',
    'commission': unknown ? null : '30.00',
    'refunds': '0.00',
    'net': unknown ? null : '970.00',
    'confirmedNet': unknown ? '0.00' : '970.00',
    'status': unknown ? 'discrepancies' : 'matched',
    'discrepancies': unknown ? 1 : 0,
  },
  'operations': [
    {
      'date': '2026-10-05T12:00:00+03:00',
      'orderId': 1,
      'client': 'СТО',
      'distributor': 'Дист',
      'providerPaymentId': 'pay-1',
      'amount': '1000.00',
      'fee': unknown ? null : '30.00',
      'refund': '0.00',
      'net': unknown ? null : '970.00',
      'status': unknown ? 'not_in_registry' : 'matched',
    },
  ],
  'discrepancies': [],
  'count': 1,
  'distributors': [
    {'id': 2, 'name': 'Второй дистрибьютор'},
  ],
};

void main() {
  tearDown(() => authService.setRole(UserRole.client));

  testWidgets('Clients and managers cannot open finance or request data', (
    tester,
  ) async {
    var calls = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    for (final role in [UserRole.client, UserRole.manager, UserRole.courier]) {
      authService.setRole(role);
      await tester.pumpWidget(
        MaterialApp(
          home: YooKassaFinanceScreen(key: ValueKey(role), api: api),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Нет доступа к финансовому учету'), findsOneWidget);
      expect(find.text('Импорт CSV / XLSX'), findsNothing);
    }
    expect(calls, 0);
  });

  testWidgets(
    'Distributor sees unknown fees explicitly and no distributor filter',
    (tester) async {
      authService.setRole(UserRole.distributor);
      final api = ApiClient(
        client: MockClient((request) async {
          expect(request.url.path.endsWith('/finance/yookassa/'), isTrue);
          expect(request.url.queryParameters['date_from'], isNotNull);
          expect(
            request.url.queryParameters.containsKey('distributor_id'),
            isFalse,
          );
          return http.Response(
            jsonEncode(report(unknown: true)),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: YooKassaFinanceScreen(api: api)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Не сверено'), findsWidgets);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.text('Импорт CSV / XLSX'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Admin filter sends selected distributor to server', (
    tester,
  ) async {
    authService.setRole(UserRole.admin);
    final requests = <http.Request>[];
    final api = ApiClient(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(report()),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await tester.pumpWidget(MaterialApp(home: YooKassaFinanceScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Второй дистрибьютор').last);
    await tester.pumpAndSettle();
    expect(requests.last.url.queryParameters['distributor_id'], '2');
    expect(tester.takeException(), isNull);
  });

  test('Excel and import use finance endpoint and same filter', () async {
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.url.path.endsWith('/finance/yookassa/export/'), isTrue);
        expect(request.url.queryParameters['distributor_id'], '2');
        return http.Response.bytes(
          [1, 2, 3],
          200,
          headers: {
            'content-disposition': 'attachment; filename="finance.xlsx"',
          },
        );
      }),
    );
    final result = await api.exportFinance({
      'distributor_id': '2',
      'date_from': '2026-10-01',
      'date_to': '2026-10-31',
    });
    expect(result.fileName, 'finance.xlsx');
    expect(result.bytes, [1, 2, 3]);
  });
}

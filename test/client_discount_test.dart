import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:autoterra/screens/clients/client_discount_card.dart';
import 'package:autoterra/services/api_client.dart';
import 'package:autoterra/services/data_repository.dart';

class DiscountRepo extends Mock implements DataRepository {}

void main() {
  late DiscountRepo repo;
  Map<String, dynamic> data(String? value, {bool edit = true}) => {
    'personalDiscountPercent': value,
    'canEdit': edit,
  };

  setUp(() {
    repo = DiscountRepo();
    when(() => repo.clientDiscount('1')).thenAnswer((_) async => data('20.00'));
    when(
      () => repo.updateClientDiscount('1', any()),
    ).thenAnswer((call) async => data(call.positionalArguments[1] as String?));
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClientDiscountCard(clientId: '1', repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows current discount and saves edited percentage', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('20.00% на весь ассортимент'), findsOneWidget);
    await tester.tap(find.byTooltip('Изменить скидку'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '15');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('15% на весь ассортимент'), findsOneWidget);
    verify(() => repo.updateClientDiscount('1', '15')).called(1);
  });

  testWidgets('zero is explicit; reset sends null', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Изменить скидку'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    verify(() => repo.updateClientDiscount('1', '0')).called(1);
    await tester.tap(find.byTooltip('Изменить скидку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('По рангу'));
    await tester.pumpAndSettle();
    verify(() => repo.updateClientDiscount('1', null)).called(1);
    expect(find.text('Не задана — действует скидка по рангу'), findsOneWidget);
  });

  testWidgets('rejects invalid values and accepts 100', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Изменить скидку'));
    await tester.pumpAndSettle();
    for (final value in ['-1', '101', 'NaN', 'Infinity', '1.001', '']) {
      await tester.enterText(find.byType(TextField), value);
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(
        find.text('Введите число от 0 до 100, до двух знаков после запятой'),
        findsOneWidget,
      );
    }
    verifyNever(() => repo.updateClientDiscount('1', any()));
    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    verify(() => repo.updateClientDiscount('1', '100')).called(1);
  });

  testWidgets('distributor sees value without edit controls', (tester) async {
    when(
      () => repo.clientDiscount('1'),
    ).thenAnswer((_) async => data('15', edit: false));
    await open(tester);
    expect(find.text('15% на весь ассортимент'), findsOneWidget);
    expect(find.byTooltip('Изменить скидку'), findsNothing);
    verifyNever(() => repo.updateClientDiscount('1', any()));
  });

  testWidgets('failed save keeps editor and original value', (tester) async {
    when(
      () => repo.updateClientDiscount('1', any()),
    ).thenThrow(Exception('403'));
    await open(tester);
    await tester.tap(find.byTooltip('Изменить скидку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось сохранить скидку'), findsOneWidget);
    expect(find.text('20.00% на весь ассортимент'), findsOneWidget);
  });

  test('API GET PATCH and null reset preserve percentage semantics', () async {
    final requests = <http.Request>[];
    final repo = DataRepository(
      api: ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode(data('20.00')), 200);
        }),
      ),
    );
    await repo.clientDiscount('1');
    await repo.updateClientDiscount('1', '15');
    await repo.updateClientDiscount('1', null);
    expect(requests[0].url.path, '/api/clients/1/discount/');
    expect(requests[0].method, 'GET');
    expect(requests[1].method, 'PATCH');
    expect(jsonDecode(requests[1].body), {'personalDiscountPercent': '15'});
    expect(jsonDecode(requests[2].body), {'personalDiscountPercent': null});
  });
}

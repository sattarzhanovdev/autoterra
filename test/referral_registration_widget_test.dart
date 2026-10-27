import 'dart:convert';
import 'package:autoterra/screens/auth/register_screen.dart';
import 'package:autoterra/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final code in ['', 'at-abc123', 'prefilled']) {
    testWidgets(
      'registration field accepts Android text and submits optional code: $code',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Map<String, dynamic>? submitted;
        final api = ApiClient(
          client: MockClient((request) async {
            if (request.method == 'GET') {
              return http.Response(
                jsonEncode({
                  'results': [
                    {'id': '1', 'name': 'Test region'},
                  ],
                }),
                200,
              );
            }
            submitted = Map<String, dynamic>.from(
              jsonDecode(request.body) as Map,
            );
            return http.Response('{"requires_approval":true}', 201);
          }),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: RegisterScreen(
              api: api,
              referralCode: code == 'prefilled' ? ' at-abc123 ' : null,
            ),
          ),
        );
        await tester.pumpAndSettle();
        Finder field(String label) => find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == label,
        );
        Future<void> enter(String label, String text) async {
          final input = field(label);
          await tester.ensureVisible(input);
          await tester.tap(input);
          await tester.enterText(input, text);
        }

        await enter('ИНН ОРГАНИЗАЦИИ *', '7778889990');
        await enter('НАЗВАНИЕ ОРГАНИЗАЦИИ *', 'Test company');
        await enter('АДРЕС МАГАЗИНА/ТОЧКИ *', 'Test address');
        await tester.tap(find.byType(DropdownButtonFormField<String>).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Test region').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('ДАЛЕЕ'));
        await tester.pumpAndSettle();
        await enter('ФИО КОНТАКТНОГО ЛИЦА *', 'Test User');
        await enter('ТЕЛЕФОН (ЛОГИН) *', '+79002223344');
        await enter('EMAIL *', 'client@example.test');
        if (code == 'prefilled') {
          expect(
            tester.widget<TextField>(field('Реферальный код')).controller!.text,
            'AT-ABC123',
          );
        } else {
          await enter('Реферальный код', code);
        }
        expect(
          tester.widget<TextField>(field('Реферальный код')).autocorrect,
          isFalse,
        );
        expect(
          tester.widget<TextField>(field('Реферальный код')).controller!.text,
          code == 'prefilled' ? 'AT-ABC123' : code,
        );
        await enter('ПАРОЛЬ *', 'verysecret123');
        for (final checkbox in find.byType(Checkbox).evaluate().toList()) {
          final finder = find.byWidget(checkbox.widget);
          await tester.ensureVisible(finder);
          await tester.tap(finder);
          await tester.pump();
        }
        await tester.ensureVisible(find.text('ЗАРЕГИСТРИРОВАТЬСЯ'));
        await tester.tap(find.text('ЗАРЕГИСТРИРОВАТЬСЯ'));
        await tester.pumpAndSettle();
        expect(submitted, isNotNull);
        expect(submitted!['referralCode'], code.isEmpty ? null : 'AT-ABC123');
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

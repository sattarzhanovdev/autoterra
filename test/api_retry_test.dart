import 'dart:async';
import 'dart:convert';

import 'package:autoterra/services/api_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Клиенты работают из России через Cloudflare — обрыв по дороге тут норма.
/// GET после такого повторяется сам, а POST повторять нельзя: второй заход
/// завёл бы дубль заказа.
void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.test/api/');
  });

  http.Response ok() => http.Response(
        jsonEncode({'status': 'ok'}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  test('GET повторяется после обрыва связи и проходит со второй попытки', () async {
    var attempts = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        attempts++;
        if (attempts == 1) throw TimeoutException('оборвалось');
        return ok();
      }),
    );

    final result = await api.dashboard();

    expect(attempts, 2);
    expect(result['status'], 'ok');
  });

  test('GET сдаётся, если обрыв повторяется, и отдаёт понятный текст', () async {
    var attempts = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        attempts++;
        throw TimeoutException('оборвалось');
      }),
    );

    await expectLater(
      api.dashboard(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('Превышено время ожидания'),
        ),
      ),
    );
    expect(attempts, 2, reason: 'одна попытка плюс один повтор');
  });

  test('GET не повторяет ответ сервера с ошибкой — он придёт таким же', () async {
    var attempts = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        attempts++;
        return http.Response(
          jsonEncode({'detail': 'Доступ запрещён'}),
          403,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await expectLater(api.dashboard(), throwsA(isA<ApiException>()));
    expect(attempts, 1);
  });

  test('POST не повторяется — иначе можно завести дубль заказа', () async {
    var attempts = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        attempts++;
        throw TimeoutException('оборвалось');
      }),
    );

    await expectLater(
      api.createOrder(items: const [], comment: ''),
      throwsA(isA<ApiException>()),
    );
    expect(attempts, 1);
  });

  test('таймаут обычного запроса заметно больше прежних 15 секунд', () {
    expect(ApiClient.defaultTimeout.inSeconds, greaterThanOrEqualTo(30));
    expect(ApiClient.longTimeout, greaterThan(ApiClient.defaultTimeout));
  });
}

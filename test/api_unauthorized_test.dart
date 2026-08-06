import 'dart:convert';

import 'package:autoterra/services/api_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Протухший токен показывался сырым «Unauthorized» прямо в форме, и человек
/// тыкал в кнопку, которая уже не могла сработать. Теперь сессия сбрасывается,
/// а роутер уводит на экран входа.
void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.test/api/');
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    // Токен лежит в SharedPreferences — в тестах его нужно подменить.
    SharedPreferences.setMockInitialValues({});
    ApiClient.onUnauthorized = null;
    await ApiClient.clearToken();
  });

  http.Response unauthorized() => http.Response(
        jsonEncode({'detail': 'Unauthorized'}),
        401,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  ApiClient clientReturning(http.Response Function() build) =>
      ApiClient(client: MockClient((_) async => build()));

  test('401 без токена — это неверный пароль, а не протухшая сессия', () async {
    var called = 0;
    ApiClient.onUnauthorized = () => called++;

    final api = clientReturning(unauthorized);

    await expectLater(
      api.login(phone: '+79000000000', password: 'wrong'),
      throwsA(
        isA<ApiException>().having((e) => e.message, 'message', 'Unauthorized'),
      ),
    );

    expect(called, 0, reason: 'выходить неоткуда — на вход мы уже смотрим');
  });

  test('401 с токеном: сессия сброшена, сообщение понятное, колбэк вызван', () async {
    // Сначала логинимся успешно, чтобы в клиенте появился токен.
    final loginApi = ApiClient(
      client: MockClient((_) async => http.Response(
            jsonEncode({
              'token': 'live-token',
              'user': {'role': 'client'},
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )),
    );
    await loginApi.login(phone: '+79000000000', password: 'ok');
    expect(ApiClient.isAuthorized, isTrue);

    var called = 0;
    ApiClient.onUnauthorized = () => called++;

    String? sentAuthHeader;
    final api = ApiClient(
      client: MockClient((request) async {
        sentAuthHeader = request.headers['Authorization'];
        return unauthorized();
      }),
    );

    await expectLater(
      api.dashboard(),
      throwsA(
        isA<ApiException>().having((e) => e.message, 'message', contains('Сессия истекла')),
      ),
    );

    expect(sentAuthHeader, 'Bearer live-token');
    expect(called, 1);
    expect(ApiClient.isAuthorized, isFalse, reason: 'токен должен быть сброшен');
  });
}

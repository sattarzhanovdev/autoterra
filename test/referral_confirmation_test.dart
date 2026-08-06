import 'dart:convert';

import 'package:autoterra/models/models.dart';
import 'package:autoterra/services/api_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ручную заявку по чужому ИНН может подать кто угодно, поэтому подарок она
/// даёт только после подтверждения самим приглашённым.
void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.test/api/');
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.clearToken();
  });

  group('PendingReferralClaim.fromJson', () {
    test('разбирает заявку', () {
      final claim = PendingReferralClaim.fromJson({
        'id': '7',
        'inviterName': 'СТО Пример',
        'inviterCity': 'Пермь',
      });

      expect(claim, isNotNull);
      expect(claim!.id, '7');
      expect(claim.inviterName, 'СТО Пример');
      expect(claim.inviterCity, 'Пермь');
    });

    test('город необязателен', () {
      final claim = PendingReferralClaim.fromJson({'id': '7', 'inviterName': 'СТО'});
      expect(claim?.inviterCity, '');
    });

    test('нет заявки — нет объекта', () {
      expect(PendingReferralClaim.fromJson(null), isNull);
      expect(PendingReferralClaim.fromJson('чепуха'), isNull);
      expect(PendingReferralClaim.fromJson({'id': '7'}), isNull);
      expect(PendingReferralClaim.fromJson({'id': '7', 'inviterName': ''}), isNull);
    });
  });

  group('Referral.confirmation', () {
    Referral build(String confirmation) => Referral(
          id: '1',
          inviterId: '2',
          inviteeInn: '7736050003',
          inviteeName: 'СТО',
          region: 'Пермь - Урал',
          confirmation: confirmation,
          createdAt: DateTime(2026),
        );

    test('ждёт подтверждения', () {
      expect(build('pending').awaitingConfirmation, isTrue);
      expect(build('pending').confirmationDeclined, isFalse);
    });

    test('приглашённый отказался', () {
      expect(build('declined').confirmationDeclined, isTrue);
      expect(build('declined').awaitingConfirmation, isFalse);
    });

    test('пришёл по коду — подтверждать нечего', () {
      expect(build('auto').awaitingConfirmation, isFalse);
      expect(build('auto').confirmationDeclined, isFalse);
    });
  });

  group('confirmReferral', () {
    test('шлёт решение на нужный адрес', () async {
      String? path;
      Object? body;
      final api = ApiClient(
        client: MockClient((request) async {
          path = request.url.path;
          body = jsonDecode(request.body);
          return http.Response(
            jsonEncode({'referral': <String, dynamic>{}}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      await api.confirmReferral('42', confirmed: true);

      expect(path, '/api/referrals/42/confirm/');
      expect(body, {'confirmed': true});
    });

    test('сразу после регистрации ходит с выданным токеном', () async {
      // Пользователь ещё не вошёл — в клиенте токена нет, но регистрация уже
      // вернула свой. Без этого подтверждение упёрлось бы в 401.
      expect(ApiClient.isAuthorized, isFalse);

      String? auth;
      final api = ApiClient(
        client: MockClient((request) async {
          auth = request.headers['Authorization'];
          return http.Response(
            jsonEncode({'referral': <String, dynamic>{}}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      await api.confirmReferral('42', confirmed: false, authToken: 'fresh-token');

      expect(auth, 'Bearer fresh-token');
    });
  });
}

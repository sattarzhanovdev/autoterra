import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:autoterra/services/api_client.dart';
import 'package:autoterra/services/data_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

/// Ответ `/dashboard/`. Код приглашения и счётчики рефералов приходят вместе с
/// профилем — иначе в профиле было бы нечего показать, кроме заглушки.
Map<String, dynamic> _response({
  String? referralCode,
  Map<String, dynamic>? referralSummary,
}) {
  return {
    'client': {
      'id': '1',
      'inn': '1234567890',
      'name': 'СТО Тест',
      'category': 'B',
      'region': 'Москва',
      'city': 'Москва',
      'contact': 'Иван',
      'phone': '+79001112233',
      'distributorId': '1',
      'status': 'active',
      'createdAt': '2026-01-01T00:00:00Z',
      if (referralCode != null) 'referralCode': referralCode,
    },
    'distributor': {
      'id': '1',
      'name': 'Дистрибьютор',
      'inn': '7701000001',
      'regions': <String>[],
      'phone': '1',
      'email': 'd@e.co',
    },
    'unreadCount': 0,
    'recentPurchases': <Map<String, dynamic>>[],
    'activeColorRequests': <Map<String, dynamic>>[],
    if (referralSummary != null) 'referralSummary': referralSummary,
  };
}

void main() {
  late MockApiClient api;
  late DataRepository repo;

  setUp(() {
    api = MockApiClient();
    repo = DataRepository(api: api);
  });

  void respond(Map<String, dynamic> body) {
    when(() => api.dashboard()).thenAnswer((_) async => body);
  }

  test('код приглашения доходит до профиля', () async {
    respond(_response(referralCode: 'AT-K7M2QX'));

    final data = await repo.dashboard();

    expect(data.client.referralCode, 'AT-K7M2QX');
  });

  test('счётчики рефералов разбираются из сводки', () async {
    respond(_response(
      referralCode: 'AT-K7M2QX',
      referralSummary: {'invitedCount': 3, 'buyersCount': 2, 'giftCount': 1},
    ));

    final data = await repo.dashboard();

    expect(data.referralInvitedCount, 3);
    expect(data.referralGiftCount, 1);
  });

  test('старый бэкенд без сводки не роняет дашборд', () async {
    // Приложение обновляется раньше сервера — профиль должен открыться и без
    // новых полей, просто с нулями.
    respond(_response());

    final data = await repo.dashboard();

    expect(data.client.referralCode, isNull);
    expect(data.referralInvitedCount, 0);
    expect(data.referralGiftCount, 0);
  });
}

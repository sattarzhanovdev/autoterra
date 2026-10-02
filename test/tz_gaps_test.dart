import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:autoterra/models/paginated.dart';
import 'package:autoterra/services/api_client.dart';
import 'package:autoterra/services/data_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

/// Пункты ТЗ, которых не хватало: согласование подарка (п. 7 шаг 6) и
/// обучающие материалы (п. 10).
Map<String, dynamic> _referral({String? gift, double bonusEarned = 0}) {
  return {
    'id': '1',
    'inviterId': '1',
    'inviteeInn': '7778889990',
    'inviteeName': 'СТО Пётр',
    'region': 'Москва',
    'isRegistered': true,
    'hasPurchase': true,
    'purchaseAmount': 35000,
    'conditionMet': true,
    'gift': gift,
    'bonusEarned': bonusEarned,
    'createdAt': '2026-01-01T00:00:00Z',
  };
}

Paginated<Map<String, dynamic>> _page(List<Map<String, dynamic>> items) {
  return Paginated<Map<String, dynamic>>(
    items: items,
    pageInfo: PageInfo.single(items.length),
  );
}

void main() {
  late MockApiClient api;
  late DataRepository repo;

  setUp(() {
    api = MockApiClient();
    repo = DataRepository(api: api);
  });

  group('Реферальный бонус', () {
    Future<dynamic> firstReferral(Map<String, dynamic> json) async {
      when(() => api.referrals(page: any(named: 'page'), pageSize: any(named: 'pageSize')))
          .thenAnswer((_) async => (_page([json]), <String, dynamic>{}));
      final (result, _) = await repo.referrals();
      return result.items.first;
    }

    test('бонус приходит сам, без согласования дистрибьютором', () async {
      final referral = await firstReferral(_referral(bonusEarned: 1750));

      expect(referral.conditionMet, isTrue);
      expect(referral.bonusEarned, 1750);
    });

    test('пока покупок нет, начисления тоже нет', () async {
      final referral = await firstReferral(_referral());

      expect(referral.bonusEarned, 0);
    });

    test('плоский подарок старых связок показывается как есть', () async {
      final referral = await firstReferral(_referral(gift: 'Отсрочка 14 дней'));

      expect(referral.gift, 'Отсрочка 14 дней');
    });

    test('старый бэкенд без поля bonusEarned не роняет экран', () async {
      final json = _referral()..remove('bonusEarned');

      final referral = await firstReferral(json);

      expect(referral.bonusEarned, 0);
    });
  });

  group('Обучающие материалы', () {
    test('материал разбирается со ссылками и длительностью', () async {
      when(() => api.learningMaterials(
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
            kind: any(named: 'kind'),
          )).thenAnswer((_) async => _page([
            {
              'id': '5',
              'title': 'Подготовка поверхности',
              'kind': 'webinar',
              'kindLabel': 'Запись вебинара',
              'category': 'Покраска',
              'summary': 'Разбор типовых ошибок',
              'body': 'Текст',
              'videoUrl': 'https://example.com/v.mp4',
              'fileUrl': null,
              'durationMinutes': 42,
              'createdAt': '2026-07-01T00:00:00Z',
            }
          ]));

      final result = await repo.learningMaterials();
      final material = result.items.single;

      expect(material.title, 'Подготовка поверхности');
      expect(material.kindLabel, 'Запись вебинара');
      expect(material.videoUrl, 'https://example.com/v.mp4');
      expect(material.fileUrl, isNull);
      expect(material.durationMinutes, 42);
    });

    test('фильтр по типу уходит в запрос', () async {
      when(() => api.learningMaterials(
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
            kind: any(named: 'kind'),
          )).thenAnswer((_) async => _page([]));

      await repo.learningMaterials(kind: 'checklist');

      verify(() => api.learningMaterials(page: 1, pageSize: 20, kind: 'checklist'))
          .called(1);
    });
  });

  group('Бонусный счёт', _bonusTests);
}

/// Бонусный счёт: разбор ответов сервера и запуск оплаты.
void _bonusTests() {
  late MockApiClient api;
  late DataRepository repo;

  setUp(() {
    api = MockApiClient();
    repo = DataRepository(api: api);
  });

  test('баланс приходит с дашборда', () async {
    when(() => api.dashboard()).thenAnswer((_) async => {
          'client': {
            'id': '1', 'inn': '1', 'name': 'СТО', 'category': 'B',
            'region': 'Мск', 'city': 'Мск', 'contact': 'И', 'phone': '1',
            'distributorId': '1', 'status': 'active',
            'createdAt': '2026-01-01T00:00:00Z',
          },
          'distributor': {
            'id': '1', 'name': 'Д', 'inn': '1', 'regions': <String>[],
            'phone': '1', 'email': 'd@e.co',
          },
          'unreadCount': 0,
          'recentPurchases': <Map<String, dynamic>>[],
          'activeColorRequests': <Map<String, dynamic>>[],
          'bonusBalance': 5000,
        });

    final data = await repo.dashboard();

    expect(data.bonusBalance, 5000);
  });

  test('оплата с бонусом отдаёт ссылку и списанную сумму', () async {
    when(() => api.payOrder(any(), useBonus: any(named: 'useBonus')))
        .thenAnswer((_) async => {
              'payment': {'confirmationUrl': 'https://pay.example/1'},
              'bonusApplied': 5000,
            });

    final result = await repo.payOrder('7', useBonus: 5000);

    expect(result.confirmationUrl, 'https://pay.example/1');
    expect(result.bonusApplied, 5000);
    expect(result.fullyCoveredByBonus, isFalse);
  });

  test('успешный нулевой платёж покрыт бонусом целиком', () async {
    // Сервер не создаёт платёж в ЮKassa, когда платить нечего.
    when(() => api.payOrder(any(), useBonus: any(named: 'useBonus')))
        .thenAnswer((_) async => {
              'payment': {'confirmationUrl': null, 'status': 'succeeded', 'amount': 0, 'provider': 'bonus'},
              'bonusApplied': 4000,
            });

    final result = await repo.payOrder('7', useBonus: 4000);

    expect(result.fullyCoveredByBonus, isTrue);
    expect(result.bonusApplied, 4000);
  });

  test('сумма бонуса уходит в запрос', () async {
    when(() => api.payOrder(any(), useBonus: any(named: 'useBonus')))
        .thenAnswer((_) async => {'payment': {}, 'bonusApplied': 0});

    await repo.payOrder('7', useBonus: 1500);

    verify(() => api.payOrder('7', useBonus: 1500)).called(1);
  });
}

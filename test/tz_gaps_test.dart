import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:autoterra/models/paginated.dart';
import 'package:autoterra/services/api_client.dart';
import 'package:autoterra/services/data_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

/// Пункты ТЗ, которых не хватало: согласование подарка (п. 7 шаг 6) и
/// обучающие материалы (п. 10).
Map<String, dynamic> _referral({
  String giftStatus = 'none',
  String? gift,
  String? giftComment,
}) {
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
    'giftStatus': giftStatus,
    'giftComment': giftComment,
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

  group('Согласование подарка', () {
    Future<dynamic> firstReferral(Map<String, dynamic> json) async {
      when(() => api.referrals(page: any(named: 'page'), pageSize: any(named: 'pageSize')))
          .thenAnswer((_) async => (_page([json]), <String, dynamic>{}));
      final (result, _) = await repo.referrals();
      return result.items.first;
    }

    test('до решения дистрибьютора подарок не показывается', () async {
      // Сервер намеренно не присылает gift, пока решение не принято.
      final referral = await firstReferral(_referral(giftStatus: 'pending'));

      expect(referral.giftPending, isTrue);
      expect(referral.giftApproved, isFalse);
      expect(referral.gift, isNull);
    });

    test('после согласования подарок виден', () async {
      final referral = await firstReferral(
        _referral(giftStatus: 'approved', gift: 'Отсрочка 14 дней'),
      );

      expect(referral.giftApproved, isTrue);
      expect(referral.gift, 'Отсрочка 14 дней');
    });

    test('отказ доносит причину до клиента', () async {
      final referral = await firstReferral(
        _referral(giftStatus: 'declined', giftComment: 'Клиент уже на спеццене'),
      );

      expect(referral.giftDeclined, isTrue);
      expect(referral.giftComment, 'Клиент уже на спеццене');
    });

    test('старый бэкенд без поля не роняет экран', () async {
      final json = _referral()..remove('giftStatus');

      final referral = await firstReferral(json);

      expect(referral.giftStatus, 'none');
      expect(referral.giftApproved, isFalse);
    });

    test('решение уходит на сервер с комментарием', () async {
      when(() => api.decideReferralGift(any(),
              approved: any(named: 'approved'), comment: any(named: 'comment')))
          .thenAnswer((_) async => <String, dynamic>{});

      await repo.decideReferralGift('7', approved: false, comment: 'Нет бюджета');

      verify(() => api.decideReferralGift('7', approved: false, comment: 'Нет бюджета'))
          .called(1);
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

  test('без ссылки заказ считается покрытым бонусом целиком', () async {
    // Сервер не создаёт платёж в ЮKassa, когда платить нечего.
    when(() => api.payOrder(any(), useBonus: any(named: 'useBonus')))
        .thenAnswer((_) async => {
              'payment': {'confirmationUrl': null},
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

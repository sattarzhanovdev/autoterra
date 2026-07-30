import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:autoterra/services/api_client.dart';
import 'package:autoterra/services/data_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

/// Ответ `/order-config/`. Справочники приходят списками строк — разбор не
/// должен пытаться привести их к Map.
Map<String, dynamic> _response({
  List<String>? categories,
  List<String>? brands,
  bool legacyProducts = false,
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
    },
    'distributor': {
      'id': '1',
      'name': 'Дистрибьютор',
      'inn': '7701000001',
      'regions': <String>[],
      'phone': '1',
      'email': 'd@e.co',
    },
    'stores': <Map<String, dynamic>>[],
    if (categories != null) 'categories': categories,
    if (brands != null) 'brands': brands,
    // Старый бэкенд дополнительно присылал весь каталог.
    if (legacyProducts) 'products': <Map<String, dynamic>>[],
  };
}

void main() {
  late MockApiClient api;
  late DataRepository repo;

  setUp(() {
    api = MockApiClient();
    repo = DataRepository(api: api);
  });

  test('справочники разбираются как списки строк', () async {
    when(() => api.orderConfig()).thenAnswer(
      (_) async => _response(
        categories: ['Грунтовки', 'Лаки'],
        brands: ['AutoTerra', 'Novol'],
      ),
    );

    final config = await repo.orderConfig();

    expect(config.categories, ['Грунтовки', 'Лаки']);
    expect(config.brands, ['AutoTerra', 'Novol']);
  });

  test('ответ старого бэкенда не роняет экран', () async {
    // На сервере может быть ещё не развёрнута новая версия: там есть products
    // и categories, но нет brands.
    when(() => api.orderConfig()).thenAnswer(
      (_) async => _response(categories: ['Грунтовки'], legacyProducts: true),
    );

    final config = await repo.orderConfig();

    expect(config.categories, ['Грунтовки']);
    expect(config.brands, isEmpty);
  });

  test('отсутствующие справочники дают пустые списки', () async {
    when(() => api.orderConfig()).thenAnswer((_) async => _response());

    final config = await repo.orderConfig();

    expect(config.categories, isEmpty);
    expect(config.brands, isEmpty);
  });
}

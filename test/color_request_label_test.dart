import 'package:autoterra/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// В заголовке заявки на подбор цвета вместо марки и модели выводилось
/// «$CARBRAND $CARMODEL»: знаки доллара были экранированы, и строка
/// подставлялась буквально.
void main() {
  ColorRequest build({
    String brand = 'BMW',
    String model = 'X5',
    PaintCoatingType paint = PaintCoatingType.baseClear,
    String? note,
  }) {
    return ColorRequest(
      id: '1',
      clientId: '2',
      carBrand: brand,
      carModel: model,
      vin: 'VIN1',
      colorCode: '300',
      colorName: 'RED',
      paintType: paint,
      paintTypeNote: note,
      status: ColorRequestStatus.created,
      transferMethod: 'courier',
      createdAt: DateTime(2026),
    );
  }

  group('carLabel', () {
    test('марка и модель подставляются, а не печатаются как есть', () {
      expect(build().carLabel, 'BMW X5');
    });

    test('без модели — только марка', () {
      expect(build(model: '').carLabel, 'BMW');
    });

    test('в заголовке не остаётся шаблонных подстановок', () {
      expect(build().carLabel, isNot(contains(r'$')));
    });
  });

  group('paintTypeLabel', () {
    test('без уточнения — название типа', () {
      expect(build().paintTypeLabel, 'База + лак');
    });

    test('с уточнением обе части подставляются', () {
      expect(build(note: 'перламутр').paintTypeLabel, 'База + лак · перламутр');
    });

    test('в подписи не остаётся шаблонных подстановок', () {
      expect(build(note: 'перламутр').paintTypeLabel, isNot(contains(r'$')));
    });
  });
}

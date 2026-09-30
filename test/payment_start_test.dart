import 'package:flutter_test/flutter_test.dart';
import 'package:autoterra/services/data_repository.dart';

void main() {
  test('a missing confirmation URL never proves payment', () {
    expect(const PaymentStart().fullyCoveredByBonus, isFalse);
    expect(const PaymentStart(status: 'canceled').fullyCoveredByBonus, isFalse);
    expect(const PaymentStart(status: 'succeeded').fullyCoveredByBonus, isFalse);
    expect(const PaymentStart(provider: 'bonus').fullyCoveredByBonus, isFalse);
    expect(const PaymentStart(provider: 'bonus', status: 'succeeded')
        .fullyCoveredByBonus, isTrue);
  });
}

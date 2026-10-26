import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';

/// All thresholds, progress and amounts come from the authenticated order quote.
class OrderDiscountSummary extends StatelessWidget {
  final Map<String, dynamic> details;
  const OrderDiscountSummary({super.key, required this.details});
  double number(String key) => double.tryParse('${details[key]}') ?? 0;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat('#,##0.00', 'ru_RU');
    final pct = NumberFormat('0.##', 'ru_RU');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Доп. скидка за объём заказа: ${pct.format(number('orderDiscountPercent'))}%',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.brandRed,
            ),
          ),
          Text(
            'Товары по вашей цене: ${money.format(number('subtotalBeforeOrderDiscount'))} ₽',
          ),
          Text('Скидка за объём: −${money.format(number('discountAmount'))} ₽'),
          Text(
            'Итого: ${money.format(number('total'))} ₽',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (details['maximumReached'] == true) ...[
            const Text('Максимальная скидка 40%'),
            const Text('Вы получили максимальную доступную скидку.'),
          ] else if (details['nextThreshold'] != null) ...[
            Text(
              'До скидки ${pct.format(number('nextDiscountPercent'))}% осталось ${money.format(number('amountToNextThreshold'))} ₽',
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: number('progress').clamp(0, 1),
              color: AppColors.brandRed,
            ),
            Text('Следующий порог: ${money.format(number('nextThreshold'))} ₽'),
          ] else if (details['hasEligibleItems'] == false)
            const Text(
              'Для товаров с договорной ценой дополнительная скидка не применяется.',
            ),
        ],
      ),
    );
  }
}

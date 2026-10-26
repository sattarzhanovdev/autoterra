import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/data_repository.dart';

/// Displays server prices; never derives a final price from a discount.
class ClientProductPrice extends StatelessWidget {
  final ProductData product;
  const ClientProductPrice({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'ru_RU');
    final discounted =
        product.basePrice != null && product.basePrice! > product.price;
    final percent = NumberFormat(
      '0.##',
      'ru_RU',
    ).format(product.effectiveDiscountPercent);
    final label = switch (product.priceSource) {
      'personal' => 'Персональная цена',
      'brand_discount' => 'Скидка по бренду',
      'rank' => 'Скидка по рангу',
      _ => 'Персональная скидка',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (discounted)
          Text(
            '$label${product.effectiveDiscountPercent > 0 ? ' −$percent%' : ''}',
            style: const TextStyle(color: AppColors.brandRed, fontSize: 12),
          ),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${product.markupPercent != null ? 'Закупочная цена: ' : ''}${fmt.format(product.price)} ₽',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            if (discounted)
              Text(
                '${fmt.format(product.basePrice)} ₽',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

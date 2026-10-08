import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/shop_pricing.dart';
import '../../services/data_repository.dart';

/// Shared by the catalog and product card; saving markup rebuilds both.
class ShopSalePrice extends StatelessWidget {
  final ProductData product;
  const ShopSalePrice({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    if (product.markupPercent == null || product.markupClientId == null) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<Map<String, double>>(
      valueListenable: DataRepository.markupChanges,
      builder: (context, changes, _) {
        final percent =
            changes[product.markupClientId] ?? product.markupPercent!;
        final fmt = NumberFormat('#,##0.00', 'ru_RU');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Наценка: ${NumberFormat('0.##', 'ru_RU').format(percent)}%'),
            Text(
              'Цена продажи: ${fmt.format(shopSalePrice(product.price, percent))} ₽',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        );
      },
    );
  }
}

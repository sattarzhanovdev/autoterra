import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReferralProgress extends StatelessWidget {
  final double volume;
  final List<({double from, double rate})> tiers;
  const ReferralProgress({
    super.key,
    required this.volume,
    required this.tiers,
  });

  @override
  Widget build(BuildContext context) {
    if (tiers.isEmpty) return const SizedBox.shrink();
    final ordered = [...tiers]..sort((a, b) => a.from.compareTo(b.from));
    final current = ordered.lastWhere(
      (t) => volume >= t.from,
      orElse: () => ordered.first,
    );
    final next = ordered.where((t) => t.from > volume).firstOrNull;
    final money = NumberFormat('#,##0', 'ru_RU');
    final percent = NumberFormat('0.##', 'ru_RU');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Оборот: ${money.format(volume)} ₽'),
          Text('Текущая ставка: ${percent.format(current.rate)}%'),
          if (next == null)
            Text('Максимальная ставка — ${percent.format(current.rate)}%')
          else ...[
            Text(
              'До ставки ${percent.format(next.rate)}% осталось ${money.format(next.from - volume)} ₽',
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: ((volume - current.from) / (next.from - current.from))
                  .clamp(0.0, 1.0),
            ),
          ],
        ],
      ),
    );
  }
}

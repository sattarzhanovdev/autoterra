import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/paginated_list_view.dart';
import '../../widgets/common/premium_icon_badge.dart';

/// Согласование реферальных подарков (п. 7 шаг 6 ТЗ).
///
/// Подарок может быть скидкой или отсрочкой — это деньги дистрибьютора,
/// поэтому выдать его без его решения нельзя.
class DistributorReferralGiftsScreen extends StatefulWidget {
  const DistributorReferralGiftsScreen({super.key});

  @override
  State<DistributorReferralGiftsScreen> createState() =>
      _DistributorReferralGiftsScreenState();
}

class _DistributorReferralGiftsScreenState
    extends State<DistributorReferralGiftsScreen> {
  late final PaginationController<Map<String, dynamic>> _controller;

  @override
  void initState() {
    super.initState();
    _controller = PaginationController<Map<String, dynamic>>(
      fetchPage: (page) => DataRepository().pendingReferralGifts(page: page),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _decide(Map<String, dynamic> item, bool approved) async {
    final comment = await _askComment(approved);
    if (comment == null) return;

    try {
      await DataRepository().decideReferralGift(
        item['id'].toString(),
        approved: approved,
        comment: comment,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approved ? 'ПОДАРОК СОГЛАСОВАН' : 'ПОДАРОК ОТКЛОНЁН')),
      );
      _controller.refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppColors.brandRed),
      );
    }
  }

  /// Возвращает комментарий, либо null — если отменили.
  Future<String?> _askComment(bool approved) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(),
        title: Text(
          approved ? 'СОГЛАСОВАТЬ ПОДАРОК' : 'ОТКЛОНИТЬ ПОДАРОК',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              approved
                  ? 'Клиент увидит подарок в приложении.'
                  : 'Клиент увидит, что подарок не согласован.',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Комментарий (необязательно)',
                border: OutlineInputBorder(borderRadius: BorderRadius.zero),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ОТМЕНА'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(
              approved ? 'СОГЛАСОВАТЬ' : 'ОТКЛОНИТЬ',
              style: TextStyle(
                color: approved ? AppColors.success : AppColors.brandRed,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'ru_RU');

    return Scaffold(
      appBar: AppBar(title: const Text('ПОДАРКИ НА СОГЛАСОВАНИИ')),
      body: PaginatedListView<Map<String, dynamic>>(
        controller: _controller,
        emptyMessage: 'НЕТ ПОДАРКОВ НА СОГЛАСОВАНИИ',
        itemBuilder: (context, item, _) => _GiftCard(
          item: item,
          fmt: fmt,
          onApprove: () => _decide(item, true),
          onDecline: () => _decide(item, false),
        ),
      ),
    );
  }
}

class _GiftCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final NumberFormat fmt;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  const _GiftCard({
    required this.item,
    required this.fmt,
    required this.onApprove,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final amount = (item['purchaseAmount'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.brandRed, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PremiumIconBadge(
                icon: Icons.card_giftcard_outlined,
                size: 42,
                iconSize: 22,
                iconColor: AppColors.brandRed,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (item['inviterName'] ?? '').toString().toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                    Text(
                      'ИНН: ${item['inviterInn'] ?? '—'}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _row('ПРИГЛАСИЛ', (item['inviteeName'] ?? '—').toString()),
          _row('ИНН ПРИГЛАШЁННОГО', (item['inviteeInn'] ?? '—').toString()),
          _row('СУММА ПОКУПОК', '${fmt.format(amount)} ₽'),
          _row('ПОДАРОК', (item['proposedGift'] ?? '—').toString()),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(
                    shape: const BeveledRectangleBorder(),
                    foregroundColor: AppColors.brandRed,
                  ),
                  child: const Text(
                    'ОТКЛОНИТЬ',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandBlack,
                    shape: const BeveledRectangleBorder(),
                  ),
                  child: const Text(
                    'СОГЛАСОВАТЬ',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

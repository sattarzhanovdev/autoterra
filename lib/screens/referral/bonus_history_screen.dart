import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/paginated_list_view.dart';

class BonusHistoryScreen extends StatefulWidget {
  final DataRepository repository;
  const BonusHistoryScreen({super.key, required this.repository});
  @override
  State<BonusHistoryScreen> createState() => _BonusHistoryScreenState();
}

class _BonusHistoryScreenState extends State<BonusHistoryScreen> {
  late final PaginationController<Map<String, dynamic>> _controller;
  @override
  void initState() {
    super.initState();
    _controller = PaginationController(
      fetchPage: (page) async =>
          (await widget.repository.bonusAccount(page: page)).$1,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('История бонусов')),
    body: PaginatedListView<Map<String, dynamic>>(
      controller: _controller,
      emptyMessage: 'Операций пока нет',
      itemBuilder: (context, row, _) {
        final amount = double.tryParse('${row['amount']}') ?? 0;
        final date = DateTime.tryParse('${row['createdAt']}')?.toLocal();
        final label = switch (row['kind']) {
          'referral' => 'Реферальный бонус',
          'order' => 'Использовано в заказе',
          'refund' => 'Возврат бонусов',
          'manual' => amount < 0 ? 'Ручное списание' : 'Ручное начисление',
          'expired' => 'Сгорание бонусов',
          _ => row['kindLabel'] ?? 'Операция',
        };
        return ListTile(
          title: Text(
            '${amount > 0 ? '+' : ''}${NumberFormat('#,##0.00', 'ru_RU').format(amount)} ₽  $label',
            style: TextStyle(color: amount > 0 ? Colors.green : null),
          ),
          subtitle: Text(
            '${row['comment'] ?? ''}${row['orderId'] == null ? '' : '\nORD-${row['orderId'].toString().padLeft(5, '0')}'}\n${date == null ? '' : DateFormat('dd.MM.yyyy').format(date)}',
          ),
        );
      },
    ),
  );
}

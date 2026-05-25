import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/premium_icon_badge.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  late Future<_PurchasesPageData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PurchasesPageData> _load() async {
    final repo = const DataRepository();
    final results = await Future.wait([repo.orders(), repo.purchases()]);
    return _PurchasesPageData(orders: results[0], purchases: results[1]);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'ru_RU');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Покупки и заказы'),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
        ],
      ),
      body: FutureBuilder<_PurchasesPageData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final data = snapshot.data!;
          final purchases = data.purchases;
          final orders = data.orders;
          final total = purchases.fold<double>(0, (s, p) => s + p.totalAmount);
          return Column(
            children: [
              _buildSummary(purchases, total, fmt),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: purchases.isEmpty && orders.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 220),
                            Center(child: Text('Покупок и заказов пока нет')),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: orders.length + purchases.length + 2,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            if (i == 0) {
                              return const SectionHeader(
                                title: 'Отправленные заказы',
                              );
                            }
                            if (i <= orders.length) {
                              return _OrderCard(order: orders[i - 1], fmt: fmt);
                            }
                            if (i == orders.length + 1) {
                              return const SectionHeader(
                                title: 'Подтвержденные покупки',
                              );
                            }
                            return _PurchaseCard(
                              purchase: purchases[i - orders.length - 2],
                              fmt: fmt,
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.addPurchase),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Добавить',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildSummary(
    List<Purchase> purchases,
    double total,
    NumberFormat fmt,
  ) {
    final verified = purchases
        .where((p) => p.status == PurchaseStatus.verified)
        .length;
    final pending = purchases
        .where((p) => p.status == PurchaseStatus.pending)
        .length;

    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        children: [
          _summaryItem('Всего покупок', '${fmt.format(total)} ₽', Colors.white),
          _vDiv(),
          _summaryItem('Подтверждено', '$verified', AppColors.success),
          _vDiv(),
          _summaryItem('На проверке', '$pending', AppColors.warning),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _vDiv() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withOpacity(0.2),
    );
  }
}

class _PurchasesPageData {
  final List<Purchase> orders;
  final List<Purchase> purchases;

  const _PurchasesPageData({required this.orders, required this.purchases});
}

class _OrderCard extends StatelessWidget {
  final Purchase order;
  final NumberFormat fmt;

  const _OrderCard({required this.order, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final status = _orderStatus(order);
    return AppCard(
      onTap: () => _showDetails(context),
      child: Row(
        children: [
          const PremiumIconBadge(
            icon: Icons.shopping_bag_outlined,
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
                  order.documentNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${order.items.length} позиций · ${DateFormat('dd.MM.yyyy', 'ru_RU').format(order.date)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${fmt.format(order.totalAmount)} ₽',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                status.label,
                style: TextStyle(
                  color: status.color,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  _OrderStatusView _orderStatus(Purchase order) {
    return _orderStatusView(order.orderStatus);
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailsSheet(order: order, fmt: fmt),
    );
  }
}

class _OrderDetailsSheet extends StatelessWidget {
  final Purchase order;
  final NumberFormat fmt;

  const _OrderDetailsSheet({required this.order, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final status = _orderStatusView(order.orderStatus);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.86,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const PremiumIconBadge(
                  icon: Icons.shopping_bag_outlined,
                  size: 44,
                  iconSize: 22,
                  iconColor: AppColors.brandRed,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.documentNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        status.description,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  status.label,
                  style: TextStyle(
                    color: status.color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                InfoRow(label: 'Статус', value: status.label),
                InfoRow(
                  label: 'Дата заказа',
                  value: DateFormat(
                    'dd.MM.yyyy HH:mm',
                    'ru_RU',
                  ).format(order.date),
                ),
                InfoRow(label: 'Позиций', value: '${order.items.length}'),
                InfoRow(
                  label: 'Итого',
                  value: '${fmt.format(order.totalAmount)} ₽',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Состав заказа',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 12),
                ...order.items.map(
                  (item) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.brandWhite,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.sku} · ${item.category} · ${item.brand}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${item.quantity} шт.',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${fmt.format(item.total)} ₽',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Обновите страницу потягиванием вниз, чтобы увидеть новый статус после изменения в админке.',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderStatusView {
  final String label;
  final String description;
  final Color color;

  const _OrderStatusView(this.label, this.description, this.color);
}

_OrderStatusView _orderStatusView(String? status) {
  switch (status) {
    case 'accepted':
      return const _OrderStatusView(
        'Принят',
        'Дистрибьютор принял заказ в работу',
        AppColors.info,
      );
    case 'done':
      return const _OrderStatusView(
        'Выполнен',
        'Заказ выполнен дистрибьютором',
        AppColors.success,
      );
    case 'rejected':
      return const _OrderStatusView(
        'Отклонён',
        'Дистрибьютор отклонил заказ',
        AppColors.error,
      );
    case 'pending':
    default:
      return const _OrderStatusView(
        'Отправлен',
        'Заказ отправлен дистрибьютору',
        AppColors.warning,
      );
  }
}

class _PurchaseCard extends StatelessWidget {
  final Purchase purchase;
  final NumberFormat fmt;
  const _PurchaseCard({required this.purchase, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => _showDetails(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PremiumIconBadge(
                icon: Icons.receipt_outlined,
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
                      purchase.documentNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      DateFormat('dd MMMM yyyy', 'ru_RU').format(purchase.date),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${fmt.format(purchase.totalAmount)} ₽',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StatusBadge.fromPurchaseStatus(purchase.status),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            '${purchase.items.length} позиций',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: purchase.items
                .map(
                  (item) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.sku,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PurchaseDetailsSheet(purchase: purchase, fmt: fmt),
    );
  }
}

class _PurchaseDetailsSheet extends StatelessWidget {
  final Purchase purchase;
  final NumberFormat fmt;
  const _PurchaseDetailsSheet({required this.purchase, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    purchase.documentNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                StatusBadge.fromPurchaseStatus(purchase.status),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                InfoRow(
                  label: 'Дата',
                  value: DateFormat(
                    'dd.MM.yyyy',
                    'ru_RU',
                  ).format(purchase.date),
                ),
                InfoRow(
                  label: 'Сумма',
                  value: '${fmt.format(purchase.totalAmount)} ₽',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Позиции',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 12),
                ...purchase.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${item.sku} · ${item.category}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${item.quantity} шт.',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${fmt.format(item.total)} ₽',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

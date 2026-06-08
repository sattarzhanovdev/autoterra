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

import '../../services/auth_service.dart';

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
    final repo = DataRepository();
    final results = await Future.wait([repo.orders(), repo.purchases()]);
    return _PurchasesPageData(
      orders: results[0] as List<Order>,
      purchases: results[1] as List<Purchase>,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'ru_RU');
    final isDistributor = authService.currentRole == UserRole.distributor;

    return Scaffold(
      appBar: AppBar(
        title: Text(isDistributor ? 'Заказы клиентов' : 'Покупки и заказы'),
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
          
          // Logic fix: Only sum non-rejected purchases
          final total = purchases
              .where((p) => p.status != PurchaseStatus.rejected)
              .fold<double>(0, (s, p) => s + p.totalAmount);
              
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
                              return SectionHeader(
                                title: isDistributor ? 'НОВЫЕ ЗАКАЗЫ' : 'Отправленные заказы',
                              );
                            }
                            if (i <= orders.length) {
                              return _OrderCard(
                                order: orders[i - 1],
                                fmt: fmt,
                                isDistributor: isDistributor,
                                onUpdate: _refresh,
                              );
                            }
                            if (i == orders.length + 1) {
                              return SectionHeader(
                                title: isDistributor ? 'ПРОВЕРКА ПОКУПОК' : 'Подтвержденные покупки',
                              );
                            }
                            return _PurchaseCard(
                              purchase: purchases[i - orders.length - 2],
                              fmt: fmt,
                              isDistributor: isDistributor,
                              onUpdate: _refresh,
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: isDistributor
          ? null
          : FloatingActionButton.extended(
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
    
    // Logic fix: 'Pending' means things you actually need to look at
    final pending = purchases
        .where((p) => 
          p.status == PurchaseStatus.newPurchase || 
          p.status == PurchaseStatus.pending || 
          p.status == PurchaseStatus.pendingVerification || 
          p.status == PurchaseStatus.underReview || 
          p.status == PurchaseStatus.duplicateReview)
        .length;

    return Container(
      color: AppColors.brandBlack,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        children: [
          _summaryItem('Всего покупок', '${fmt.format(total)} ₽', Colors.white),
          _vDiv(),
          _summaryItem('Подтверждено', '$verified', Colors.white),
          _vDiv(),
          _summaryItem('Ожидает', '$pending', Colors.white),
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
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
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
      height: 32,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}

class _PurchasesPageData {
  final List<Order> orders;
  final List<Purchase> purchases;

  const _PurchasesPageData({required this.orders, required this.purchases});
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final NumberFormat fmt;
  final bool isDistributor;
  final VoidCallback? onUpdate;

  const _OrderCard({
    required this.order,
    required this.fmt,
    this.isDistributor = false,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final status = _orderStatus(order);
    final canAction = isDistributor && order.status == OrderStatus.newOrder;

    return AppCard(
      onTap: () => _showDetails(context),
      child: Column(
        children: [
          Row(
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
                      isDistributor
                          ? (order.clientName ?? order.documentNumber)
                          : order.documentNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      isDistributor
                          ? order.documentNumber
                          : '${order.items.length} позиций · ${DateFormat('dd.MM.yyyy', 'ru_RU').format(order.date)}',
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
          if (canAction) ...[
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleUpdate(context, 'rejected'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('ОТКЛОНИТЬ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleUpdate(context, 'accepted'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlack),
                    child: const Text('В РАБОТУ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleUpdate(BuildContext context, String status) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(status == 'rejected' ? 'Отклонить заказ?' : 'Взять в работу?'),
        content: Text(status == 'rejected' ? 'Заказ будет отменен.' : 'Статус заказа изменится на "Принят".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ОТМЕНА')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: status == 'rejected' ? AppColors.error : AppColors.brandBlack),
            child: const Text('ПОДТВЕРДИТЬ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await DataRepository().updateOrderStatus(order.id, status: status);
      onUpdate?.call();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  _OrderStatusView _orderStatus(Order order) {
    return _orderStatusView(order.status);
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailsSheet(order: order, fmt: fmt, isDistributor: isDistributor, onUpdate: onUpdate),
    );
  }
}

class _OrderDetailsSheet extends StatelessWidget {
  final Order order;
  final NumberFormat fmt;
  final bool isDistributor;
  final VoidCallback? onUpdate;

  const _OrderDetailsSheet({required this.order, required this.fmt, this.isDistributor = false, this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final status = _orderStatusView(order.status);
    final canAction = isDistributor && order.status == OrderStatus.newOrder;
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.zero,
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.zero,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
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
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textHint),
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
                if (order.estimatedDeliveryDate != null)
                  InfoRow(
                    label: 'Ожидаемая дата доставки',
                    value: DateFormat('dd.MM.yyyy', 'ru_RU').format(order.estimatedDeliveryDate!),
                  ),
                if (order.courierName != null && order.courierName!.isNotEmpty)
                  InfoRow(
                    label: 'Курьер',
                    value: order.courierName!,
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
                if (canAction) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _handleUpdate(context, 'rejected'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            minimumSize: const Size(0, 50),
                          ),
                          child: const Text('ОТКЛОНИТЬ', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleUpdate(context, 'accepted'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandBlack,
                            minimumSize: const Size(0, 50),
                          ),
                          child: const Text('В РАБОТУ', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Future<void> _handleUpdate(BuildContext context, String status) async {
    if (status == 'rejected') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Отклонить заказ?'),
          content: const Text('Заказ будет отменен.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ОТМЕНА')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('ПОДТВЕРДИТЬ'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      try {
        await DataRepository().updateOrderStatus(order.id, status: status);
        if (context.mounted) Navigator.pop(context); // Close sheet
        onUpdate?.call();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
        }
      }
      return;
    }

    // For 'accepted' status, show a detailed dialog
    String? selectedCourierId;
    DateTime? selectedDate = DateTime.now().add(const Duration(days: 1)); // Default tomorrow
    bool loadingCouriers = true;
    List<Map<String, dynamic>> couriers = [];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setS) {
          if (loadingCouriers) {
            DataRepository().distributorCouriers().then((data) {
              if (ctx.mounted) {
                setS(() {
                  couriers = data;
                  loadingCouriers = false;
                });
              }
            }).catchError((e) {
              if (ctx.mounted) {
                setS(() => loadingCouriers = false);
              }
            });
          }

          return AlertDialog(
            title: const Text('Принять заказ в работу', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Укажите детали доставки (необязательно):', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  const Text('КУРЬЕР', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: AppColors.brandRed)),
                  const SizedBox(height: 4),
                  if (loadingCouriers)
                    const CircularProgressIndicator()
                  else
                    DropdownButtonFormField<String>(
                      value: selectedCourierId,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Не назначен')),
                        ...couriers.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name']))),
                      ],
                      onChanged: (v) => setS(() => selectedCourierId = v),
                    ),
                  const SizedBox(height: 16),
                  const Text('ОЖИДАЕМАЯ ДАТА', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: AppColors.brandRed)),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setS(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(4)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(selectedDate != null ? DateFormat('dd.MM.yyyy').format(selectedDate!) : 'Не указана'),
                          const Icon(Icons.calendar_today, size: 18, color: AppColors.brandRed),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ОТМЕНА', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx, {
                    'courierId': selectedCourierId,
                    'date': selectedDate != null ? DateFormat('yyyy-MM-dd').format(selectedDate!) : null,
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlack),
                child: const Text('В РАБОТУ', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          );
        },
      ),
    );

    if (result == null) return;

    try {
      await DataRepository().updateOrderStatus(
        order.id, 
        status: status,
        courierId: result['courierId'] as String?,
        estimatedDeliveryDate: result['date'] as String?,
      );
      if (context.mounted) Navigator.pop(context); // Close sheet
      onUpdate?.call();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }
}

class _OrderStatusView {
  final String label;
  final String description;
  final Color color;

  const _OrderStatusView(this.label, this.description, this.color);
}

_OrderStatusView _orderStatusView(OrderStatus status) {
  switch (status) {
    case OrderStatus.accepted:
      return const _OrderStatusView(
        'Принят',
        'Дистрибьютор принял заказ в работу',
        AppColors.info,
      );
    case OrderStatus.fulfilled:
      return const _OrderStatusView(
        'Выполнен',
        'Заказ выполнен дистрибьютором',
        AppColors.success,
      );
    case OrderStatus.rejected:
      return const _OrderStatusView(
        'Отклонён',
        'Дистрибьютор отклонил заказ',
        AppColors.error,
      );
    case OrderStatus.newOrder:
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
  final bool isDistributor;
  final VoidCallback? onUpdate;

  const _PurchaseCard({
    required this.purchase,
    required this.fmt,
    this.isDistributor = false,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final needsAction = isDistributor && (
      purchase.status == PurchaseStatus.newPurchase ||
      purchase.status == PurchaseStatus.pending || 
      purchase.status == PurchaseStatus.pendingVerification || 
      purchase.status == PurchaseStatus.underReview ||
      purchase.status == PurchaseStatus.duplicateReview
    );

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
                      isDistributor
                          ? (purchase.clientName ?? purchase.documentNumber)
                          : purchase.documentNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      isDistributor
                          ? purchase.documentNumber
                          : DateFormat('dd MMMM yyyy', 'ru_RU').format(
                              purchase.date,
                            ),
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
          if (needsAction) ...[
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleVerify(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('ОТКЛОНИТЬ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleVerify(context, true),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                    child: const Text('ПОДТВЕРДИТЬ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ],
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
                      color: AppColors.primary.withValues(alpha: 0.06),
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

  Future<void> _handleVerify(BuildContext context, bool verify) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(verify ? 'Подтвердить покупку?' : 'Отклонить покупку?'),
        content: Text(verify ? 'Баллы будут начислены клиенту.' : 'Покупка будет аннулирована.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ОТМЕНА')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: verify ? AppColors.success : AppColors.error),
            child: const Text('ПОДТВЕРДИТЬ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await DataRepository().verifyPurchase(purchase.id, verify: verify);
      onUpdate?.call();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PurchaseDetailsSheet(purchase: purchase, fmt: fmt, isDistributor: isDistributor, onUpdate: onUpdate),
    );
  }
}

class _PurchaseDetailsSheet extends StatelessWidget {
  final Purchase purchase;
  final NumberFormat fmt;
  final bool isDistributor;
  final VoidCallback? onUpdate;

  const _PurchaseDetailsSheet({required this.purchase, required this.fmt, this.isDistributor = false, this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final needsAction = isDistributor && (
      purchase.status == PurchaseStatus.newPurchase ||
      purchase.status == PurchaseStatus.pending || 
      purchase.status == PurchaseStatus.pendingVerification || 
      purchase.status == PurchaseStatus.underReview ||
      purchase.status == PurchaseStatus.duplicateReview
    );

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.zero,
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.zero,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
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
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textHint),
                  ),
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
                if (needsAction) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _handleVerify(context, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            minimumSize: const Size(0, 50),
                          ),
                          child: const Text('ОТКЛОНИТЬ', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleVerify(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            minimumSize: const Size(0, 50),
                          ),
                          child: const Text('ПОДТВЕРДИТЬ', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
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
    ),
  );
}

  Future<void> _handleVerify(BuildContext context, bool verify) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(verify ? 'Подтвердить покупку?' : 'Отклонить покупку?'),
        content: Text(verify ? 'Баллы будут начислены клиенту.' : 'Покупка будет аннулирована.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ОТМЕНА')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: verify ? AppColors.success : AppColors.error),
            child: const Text('ПОДТВЕРДИТЬ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await DataRepository().verifyPurchase(purchase.id, verify: verify);
      if (context.mounted) Navigator.pop(context); // Close sheet
      onUpdate?.call();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }
}

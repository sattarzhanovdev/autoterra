import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/data_repository.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/premium_icon_badge.dart';
import '../../widgets/delivery/assign_courier_sheet.dart';
import '../../widgets/delivery/assign_order_courier_sheet.dart';
import '../../services/auth_service.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  _PurchasesPageData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = DataRepository();
      final results = await Future.wait([
        repo.orders(),
        repo.purchases(),
        repo.courierTasks(),
      ]);
      if (mounted) {
        setState(() {
          _data = _PurchasesPageData(
            orders: results[0] as List<Order>,
            purchases: results[1] as List<Purchase>,
            courierTasks: results[2] as List<CourierTask>,
          );
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'ru_RU');
    final isDistributor = authService.currentRole == UserRole.distributor;

    if (_loading && _data == null) {
      return Scaffold(
        appBar: AppBar(title: Text(isDistributor ? 'Заказы клиентов' : 'Покупки и заказы')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _data == null) {
      return Scaffold(
        appBar: AppBar(title: Text(isDistributor ? 'Заказы клиентов' : 'Покупки и заказы')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('ПОВТОРИТЬ')),
            ],
          ),
        ),
      );
    }

    final data = _data!;
    final purchases = data.purchases;
    final orders = data.orders;
    final deliveries = data.courierTasks;
    
    final total = purchases
        .where((p) => p.status != PurchaseStatus.rejected)
        .fold<double>(0, (s, p) => s + p.totalAmount);

    final itemCount = isDistributor 
        ? (orders.length + purchases.length + deliveries.length + 3)
        : (orders.length + purchases.length + 2);

    return Scaffold(
      appBar: AppBar(
        title: Text(isDistributor ? 'Заказы клиентов' : 'Покупки и заказы'),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          if (!isDistributor) _buildSummary(purchases, total, fmt),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: purchases.isEmpty && orders.isEmpty && deliveries.isEmpty
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
                      itemCount: itemCount,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return SectionHeader(
                            title: isDistributor ? 'НОВЫЕ ЗАКАЗЫ' : 'Отправленные заказы',
                          );
                        }
                        if (i <= orders.length) {
                          return OrderCard(
                            order: orders[i - 1],
                            fmt: fmt,
                            isDistributor: isDistributor,
                            onUpdate: _refresh,
                          );
                        }
                        
                        if (isDistributor) {
                          final deliveryIdx = orders.length + 1;
                          if (i == deliveryIdx) {
                            return const SectionHeader(title: 'ЗАЯВКИ НА ДОСТАВКУ');
                          }
                          if (i <= orders.length + deliveries.length + 1) {
                            return _DeliveryCard(
                              task: deliveries[i - deliveryIdx - 1],
                              onUpdate: _refresh,
                            );
                          }
                          
                          final purchaseIdx = orders.length + deliveries.length + 2;
                          if (i == purchaseIdx) {
                            return const SectionHeader(title: 'ПРОВЕРКА ПОКУПОК');
                          }
                          return PurchaseCard(
                            purchase: purchases[i - purchaseIdx - 1],
                            fmt: fmt,
                            isDistributor: isDistributor,
                            onUpdate: _refresh,
                          );
                        } else {
                          if (i == orders.length + 1) {
                            return const SectionHeader(title: 'Подтвержденные покупки');
                          }
                          return PurchaseCard(
                            purchase: purchases[i - orders.length - 2],
                            fmt: fmt,
                            isDistributor: isDistributor,
                            onUpdate: _refresh,
                          );
                        }
                      },
                    ),
            ),
          ),
        ],
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

  Widget _buildSummary(List<Purchase> purchases, double total, NumberFormat fmt) {
    final verified = purchases.where((p) => p.status == PurchaseStatus.verified).length;
    final pending = purchases.where((p) => 
        p.status == PurchaseStatus.newPurchase || 
        p.status == PurchaseStatus.pending || 
        p.status == PurchaseStatus.pendingVerification || 
        p.status == PurchaseStatus.underReview || 
        p.status == PurchaseStatus.duplicateReview).length;

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
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18),
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
  final List<CourierTask> courierTasks;

  const _PurchasesPageData({
    required this.orders,
    required this.purchases,
    required this.courierTasks,
  });
}

class OrderCard extends StatelessWidget {
  final Order order;
  final NumberFormat fmt;
  final bool isDistributor;
  final VoidCallback? onUpdate;

  const OrderCard({
    super.key,
    required this.order,
    required this.fmt,
    this.isDistributor = false,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final status = _orderStatusView(order.status);
    final canAction = isDistributor && order.status == OrderStatus.newOrder;
    final canEdit = !isDistributor && order.status == OrderStatus.newOrder;

    return AppCard(
      onTap: () {
        if (canEdit) {
          context.push(AppRoutes.order, extra: order).then((_) => onUpdate?.call());
        } else {
          _showDetails(context);
        }
      },
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
                      isDistributor ? (order.clientName ?? order.documentNumber) : order.documentNumber,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    Text(
                      isDistributor
                          ? order.documentNumber
                          : '${order.items.length} позиций · ${DateFormat('dd.MM.yyyy', 'ru_RU').format(order.date)}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
                    style: TextStyle(color: status.color, fontWeight: FontWeight.w800, fontSize: 12),
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

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailsSheet(order: order, fmt: fmt, isDistributor: isDistributor, onUpdate: onUpdate),
    );
  }

  Future<void> _handleUpdate(BuildContext context, String status) async {
    if (status == 'accepted') {
      // Styled bottom sheet handles courier + date (or direct self-pickup
      // accept) and performs the status update itself.
      final ok = await showAssignOrderCourierSheet(context, order, fmt);
      if (ok == true) onUpdate?.call();
      return;
    }

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
      onUpdate?.call();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }
}

class _DeliveryCard extends StatelessWidget {
  final CourierTask task;
  final VoidCallback? onUpdate;

  const _DeliveryCard({required this.task, this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => _showDetails(context),
      child: Column(
        children: [
          Row(
            children: [
              const PremiumIconBadge(
                icon: Icons.local_shipping_outlined,
                size: 42,
                iconSize: 22,
                iconColor: AppColors.info,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (task.clientName).toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    Text(
                      task.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              StatusBadge.fromCourierStatus(task.status),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeliveryDetailsSheet(task: task, onUpdate: onUpdate),
    );
  }
}

class _DeliveryDetailsSheet extends StatelessWidget {
  final CourierTask task;
  final VoidCallback? onUpdate;

  const _DeliveryDetailsSheet({required this.task, this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final statusBadge = StatusBadge.fromCourierStatus(task.status);
    final isNew = task.status == CourierTaskStatus.created;
    final isAssigned = task.status == CourierTaskStatus.assigned;
    final canAction = isNew || isAssigned;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.zero),
        child: Column(
          children: [
            Container(
              width: 36, height: 4, margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.zero),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
              child: Row(
                children: [
                  const PremiumIconBadge(icon: Icons.local_shipping_outlined, size: 44, iconSize: 22, iconColor: AppColors.info),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(task.typeDisplay.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                        Text(task.clientName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: AppColors.textHint)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  InfoRow(label: 'Статус', value: statusBadge.label),
                  InfoRow(label: 'Адрес', value: task.address),
                  if (task.contactName != null) InfoRow(label: 'Контакт', value: task.contactName!),
                  if (task.contactPhone != null) InfoRow(label: 'Телефон', value: task.contactPhone!),
                  if (task.courierName != null) InfoRow(label: 'Назначен курьер', value: task.courierName!),
                  if (task.comment != null && task.comment!.isNotEmpty) InfoRow(label: 'Комментарий', value: task.comment!),
                  
                  if (canAction) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _handleUpdate(context, 'cancelled'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              minimumSize: const Size(0, 50),
                            ),
                            child: const Text('ОТМЕНИТЬ ЗАЯВКУ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _handleAssign(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandBlack,
                              minimumSize: const Size(0, 50),
                            ),
                            child: Text(
                              isAssigned ? 'ИЗМЕНИТЬ КУРЬЕРА' : 'НАЗНАЧИТЬ КУРЬЕРА',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                            ),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отменить заявку?'),
        content: const Text('Заявка на доставку будет аннулирована.'),
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
      await DataRepository().updateDeliveryStatus(task.id, status: status);
      if (context.mounted) Navigator.pop(context);
      onUpdate?.call();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  Future<void> _handleAssign(BuildContext context) async {
    final assigned = await showAssignCourierSheet(context, task);
    if (assigned == true) {
      if (context.mounted) Navigator.pop(context);
      onUpdate?.call();
    }
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
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.zero),
        child: Column(
          children: [
            Container(
              width: 36, height: 4, margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.zero),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
              child: Row(
                children: [
                  const PremiumIconBadge(icon: Icons.shopping_bag_outlined, size: 44, iconSize: 22, iconColor: AppColors.brandRed),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.documentNumber, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                        Text(status.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: AppColors.textHint)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  InfoRow(label: 'Статус', value: status.label),
                  InfoRow(label: 'Дата заказа', value: DateFormat('dd.MM.yyyy HH:mm', 'ru_RU').format(order.date)),
                  if (order.estimatedDeliveryDate != null)
                    InfoRow(label: 'Ожидаемая дата доставки', value: DateFormat('dd.MM.yyyy', 'ru_RU').format(order.estimatedDeliveryDate!)),
                  if (order.courierName != null && order.courierName!.isNotEmpty)
                    InfoRow(label: 'Курьер', value: order.courierName!),
                  InfoRow(label: 'Позиций', value: '${order.items.length}'),
                  InfoRow(label: 'Итого', value: '${fmt.format(order.totalAmount)} ₽'),
                  const SizedBox(height: 16),
                  const Text('Состав заказа', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 12),
                  ...order.items.map((item) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.brandWhite, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                              const SizedBox(height: 2),
                              Text('${item.sku} · ${item.category} · ${item.brand}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${item.quantity} шт.', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            Text('${fmt.format(item.total)} ₽', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  )),
                  if (canAction) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _handleUpdate(context, 'rejected'),
                            style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error), minimumSize: const Size(0, 50)),
                            child: const Text('ОТКЛОНИТЬ', style: TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _handleUpdate(context, 'accepted'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlack, minimumSize: const Size(0, 50)),
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
    if (status == 'accepted') {
      // Styled bottom sheet handles courier + date (or direct self-pickup
      // accept) and performs the status update itself.
      final ok = await showAssignOrderCourierSheet(context, order, fmt);
      if (ok == true) {
        if (context.mounted) Navigator.pop(context);
        onUpdate?.call();
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отклонить заказ?'),
        content: const Text('Заказ будет отменен.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ОТМЕНА')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error), child: const Text('ПОДТВЕРДИТЬ')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await DataRepository().updateOrderStatus(order.id, status: status);
      if (context.mounted) Navigator.pop(context);
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
    case OrderStatus.accepted: return const _OrderStatusView('Принят', 'Принят в работу', AppColors.info);
    case OrderStatus.fulfilled: return const _OrderStatusView('Выполнен', 'Заказ выполнен', AppColors.success);
    case OrderStatus.rejected: return const _OrderStatusView('Отклонён', 'Заказ отклонен', AppColors.error);
    case OrderStatus.newOrder: return const _OrderStatusView('Отправлен', 'Ожидает обработки', AppColors.warning);
  }
}

class PurchaseCard extends StatelessWidget {
  final Purchase purchase;
  final NumberFormat fmt;
  final bool isDistributor;
  final VoidCallback? onUpdate;

  const PurchaseCard({super.key, required this.purchase, required this.fmt, this.isDistributor = false, this.onUpdate});

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
              const PremiumIconBadge(icon: Icons.receipt_outlined, size: 42, iconSize: 22, iconColor: AppColors.brandRed),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isDistributor ? (purchase.clientName ?? purchase.documentNumber) : purchase.documentNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(isDistributor ? purchase.documentNumber : DateFormat('dd MMMM yyyy', 'ru_RU').format(purchase.date), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${fmt.format(purchase.totalAmount)} ₽', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
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
        ],
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PurchaseDetailsSheet(purchase: purchase, fmt: fmt, isDistributor: isDistributor, onUpdate: onUpdate),
    );
  }

  Future<void> _handleVerify(BuildContext context, bool verify) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(verify ? 'Подтвердить покупку?' : 'Отклонить покупку?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ОТМЕНА')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: verify ? AppColors.success : AppColors.error), child: const Text('ПОДТВЕРДИТЬ')),
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
}

class PurchaseDetailsSheet extends StatelessWidget {
  final Purchase purchase;
  final NumberFormat fmt;
  final bool isDistributor;
  final VoidCallback? onUpdate;
  const PurchaseDetailsSheet({super.key, required this.purchase, required this.fmt, this.isDistributor = false, this.onUpdate});

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
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.zero),
        child: Column(
          children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12), decoration: BoxDecoration(color: AppColors.border)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
              child: Row(
                children: [
                  Expanded(child: Text(purchase.documentNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18))),
                  StatusBadge.fromPurchaseStatus(purchase.status),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  InfoRow(label: 'Дата', value: DateFormat('dd.MM.yyyy', 'ru_RU').format(purchase.date)),
                  InfoRow(label: 'Сумма', value: '${fmt.format(purchase.totalAmount)} ₽'),
                  _buildPhotoSection(),
                  if (needsAction) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: OutlinedButton(onPressed: () => _handleVerify(context, false), style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error), minimumSize: const Size(0, 50)), child: const Text('ОТКЛОНИТЬ'))),
                        const SizedBox(width: 12),
                        Expanded(child: ElevatedButton(onPressed: () => _handleVerify(context, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, minimumSize: const Size(0, 50)), child: const Text('ПОДТВЕРДИТЬ'))),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text('Позиции', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ...purchase.items.map((item) => Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)), Text(item.sku, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11))])),
                        Text('${item.quantity} шт.', style: const TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    String? imageUrl = purchase.documentUrl;
    if ((imageUrl == null || imageUrl.isEmpty) && purchase.attachments.isNotEmpty) {
      imageUrl = purchase.attachments.first.url;
    }

    if (imageUrl == null || imageUrl.isEmpty) return const SizedBox.shrink();

    // Backend media URLs come back relative (MEDIA_URL has no leading slash),
    // so resolve to an absolute URL before loading.
    imageUrl = ApiClient.mediaUrl(imageUrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'ФОТО ЧЕКА',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.canvas,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image_outlined, color: AppColors.textHint, size: 40),
                  SizedBox(height: 8),
                  Text('ОШИБКА ЗАГРУЗКИ ФОТО', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleVerify(BuildContext context, bool verify) async {
    try {
      await DataRepository().verifyPurchase(purchase.id, verify: verify);
      if (context.mounted) Navigator.pop(context);
      onUpdate?.call();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }
}

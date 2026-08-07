import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/paginated_list_view.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/premium_icon_badge.dart';
import '../../widgets/delivery/assign_courier_sheet.dart';
import '../../services/auth_service.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final DataRepository _repo = DataRepository();

  /// Три независимые ленты: у каждой секции своя пагинация и своя кнопка
  /// «показать ещё». Склеивать их в один список нельзя — подгрузка одной
  /// секции сдвигала бы индексы остальных.
  late final PaginationController<Order> _ordersController;
  late final PaginationController<Purchase> _purchasesController;
  late final PaginationController<CourierTask> _deliveriesController;

  /// Итоги приходят с сервера и считаются по всей выборке, а не по
  /// загруженным страницам.
  Map<String, dynamic> _stats = const {};

  @override
  void initState() {
    super.initState();
    _ordersController = PaginationController<Order>(
      fetchPage: (page) => _repo.orders(page: page),
    );
    _purchasesController = PaginationController<Purchase>(
      fetchPage: (page) async {
        final (result, stats) = await _repo.purchases(page: page);
        if (mounted && stats.isNotEmpty) setState(() => _stats = stats);
        return result;
      },
    );
    _deliveriesController = PaginationController<CourierTask>(
      fetchPage: (page) => _repo.courierTasks(page: page),
    );
  }

  @override
  void dispose() {
    _ordersController.dispose();
    _purchasesController.dispose();
    _deliveriesController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait([
      _ordersController.refresh(),
      _purchasesController.refresh(),
      if (authService.currentRole == UserRole.distributor)
        _deliveriesController.refresh(),
    ]);
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
      body: Column(
        children: [
          if (!isDistributor) _buildSummary(fmt),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  ...PaginatedSliverSection<Order>(
                    controller: _ordersController,
                    title: isDistributor ? 'НОВЫЕ ЗАКАЗЫ' : 'Отправленные заказы',
                    emptyMessage: 'Заказов пока нет',
                    itemBuilder: (context, order) => OrderCard(
                      order: order,
                      fmt: fmt,
                      isDistributor: isDistributor,
                      onUpdate: _refresh,
                    ),
                  ).build(),
                  if (isDistributor)
                    ...PaginatedSliverSection<CourierTask>(
                      controller: _deliveriesController,
                      title: 'ЗАЯВКИ НА ДОСТАВКУ',
                      emptyMessage: 'Заявок на доставку пока нет',
                      itemBuilder: (context, task) =>
                          _DeliveryCard(task: task, onUpdate: _refresh),
                    ).build(),
                  ...PaginatedSliverSection<Purchase>(
                    controller: _purchasesController,
                    title: isDistributor ? 'ПРОВЕРКА ПОКУПОК' : 'Подтвержденные покупки',
                    emptyMessage: 'Покупок пока нет',
                    itemBuilder: (context, purchase) => PurchaseCard(
                      purchase: purchase,
                      fmt: fmt,
                      isDistributor: isDistributor,
                      onUpdate: _refresh,
                    ),
                  ).build(),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
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

  Widget _buildSummary(NumberFormat fmt) {
    final total = (_stats['totalAmount'] as num? ?? 0).toDouble();
    final verified = (_stats['verifiedCount'] as num? ?? 0).toInt();
    final pending = (_stats['pendingCount'] as num? ?? 0).toInt();

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
    final tier = _orderTier(order.status);
    // Новый заказ оператор не «берёт в работу» одной кнопкой, а разбирает:
    // сверяет позиции с остатками и решает — подтвердить или скорректировать.
    final needsReview = isDistributor && order.status == OrderStatus.newOrder;
    // Клиенту нужно ответить на корректировку или оплатить подтверждённый заказ.
    final needsClientAction = !isDistributor &&
        (order.status == OrderStatus.adjusted || order.status.isPayable);

    final isNew = tier == _OrderTier.fresh;
    final isDone = tier == _OrderTier.processed;

    return AppCard(
      onTap: () => _openOrder(context),
      // Новый заказ — единственное, что в списке светится красным: в палитре
      // приложения это и есть «требует внимания». Обработанный уходит в серый.
      redAccent: isNew,
      accentBar: isDone ? AppColors.border : null,
      background: isDone ? AppColors.canvas : null,
      child: Column(
        children: [
          if (isNew || isDone) ...[
            Row(
              children: [
                StatusBadge(
                  label: isNew ? 'Новый' : 'Обработан',
                  color: isNew ? AppColors.brandRed : AppColors.textHint,
                  filled: isNew,
                ),
                const Spacer(),
                Text(
                  DateFormat('dd.MM.yyyy', 'ru_RU').format(order.date),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              PremiumIconBadge(
                icon: Icons.shopping_bag_outlined,
                size: 42,
                iconSize: 22,
                iconColor: isDone ? AppColors.textHint : AppColors.brandRed,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDistributor ? (order.clientName ?? order.documentNumber) : order.documentNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: isDone ? AppColors.textSecondary : AppColors.textPrimary,
                      ),
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
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isDone ? AppColors.textSecondary : AppColors.textPrimary,
                    ),
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
          if (needsReview) ...[
            const Divider(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _openOrder(context),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandRed),
                child: const Text(
                  'РАЗОБРАТЬ ЗАКАЗ',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
            ),
          ],
          if (needsClientAction) ...[
            const Divider(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _openOrder(context),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandRed),
                child: Text(
                  order.status == OrderStatus.adjusted
                      ? 'ПОСМОТРЕТЬ ИЗМЕНЕНИЯ'
                      : 'ОПЛАТИТЬ ЗАКАЗ',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Оператор идёт на разбор, клиент — на карточку заказа с оплатой.
  void _openOrder(BuildContext context) {
    final path = isDistributor
        ? '${AppRoutes.orders}/${order.id}/review'
        : '${AppRoutes.orders}/${order.id}';
    context.push(path, extra: order).then((changed) {
      if (changed == true) onUpdate?.call();
    });
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

class _OrderStatusView {
  final String label;
  final String description;
  final Color color;
  const _OrderStatusView(this.label, this.description, this.color);
}

/// Насколько заказ ещё «живой». В списке важны три состояния, а не девять
/// статусов: свежий требует реакции, обработанный уже не требует ничего.
enum _OrderTier { fresh, inProgress, processed }

_OrderTier _orderTier(OrderStatus status) {
  switch (status) {
    case OrderStatus.newOrder:
      return _OrderTier.fresh;
    // Заказ доехал или закрыт — реагировать больше не на что.
    case OrderStatus.fulfilled:
    case OrderStatus.rejected:
    case OrderStatus.cancelled:
      return _OrderTier.processed;
    case OrderStatus.confirmed:
    case OrderStatus.adjusted:
    case OrderStatus.accepted:
    case OrderStatus.paid:
    case OrderStatus.shipped:
      return _OrderTier.inProgress;
  }
}

_OrderStatusView _orderStatusView(OrderStatus status) {
  switch (status) {
    case OrderStatus.newOrder: return const _OrderStatusView('Ожидает подтверждения', 'Оператор проверяет наличие', AppColors.warning);
    case OrderStatus.confirmed: return const _OrderStatusView('Подтверждён', 'Готов к оплате', AppColors.success);
    case OrderStatus.adjusted: return const _OrderStatusView('Скорректирован', 'Требуется ваше согласие', AppColors.warning);
    case OrderStatus.accepted: return const _OrderStatusView('Принят', 'Принят в работу', AppColors.info);
    case OrderStatus.paid: return const _OrderStatusView('Оплачен', 'Ожидает отправки', AppColors.info);
    case OrderStatus.shipped: return const _OrderStatusView('Отправлен', 'В пути', AppColors.info);
    case OrderStatus.fulfilled: return const _OrderStatusView('Доставлен', 'Заказ выполнен', AppColors.success);
    case OrderStatus.rejected: return const _OrderStatusView('Отклонён', 'Заказ отклонён', AppColors.error);
    case OrderStatus.cancelled: return const _OrderStatusView('Отменён', 'Заказ отменён', AppColors.error);
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
          borderRadius: AppShapes.cut(AppShapes.chamferSm),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.canvas,
                border: Border.all(color: AppColors.border),
                borderRadius: AppShapes.cut(AppShapes.chamferSm),
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

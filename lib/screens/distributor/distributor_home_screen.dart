import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/premium_icon_badge.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/status_badge.dart';
import '../purchases/purchases_screen.dart';

class DistributorHomeScreen extends StatefulWidget {
  const DistributorHomeScreen({super.key});

  @override
  State<DistributorHomeScreen> createState() => _DistributorHomeScreenState();
}

class _DistributorHomeScreenState extends State<DistributorHomeScreen> {
  DistributorDashboardData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await DataRepository().distributorDashboard();
      if (mounted) {
        setState(() {
          _data = data;
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
    
    if (_loading && _data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    if (_error != null && _data == null) {
      return Scaffold(
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
    
    return Scaffold(
      backgroundColor: AppColors.brandWhite,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 118,
              pinned: true,
              backgroundColor: AppColors.brandBlack,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: AppColors.brandBlack,
                  padding: const EdgeInsets.fromLTRB(16, 48, 20, 12),
                  child: const Center(
                    child: AppLogo(height: 28),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'ЧТО НУЖНО СДЕЛАТЬ?'),
                    const SizedBox(height: 20),
                    _buildMetricsGrid(data.metrics),
                    const SizedBox(height: 24),
                    const SectionHeader(title: 'НОВЫЕ ЗАКАЗЫ'),
                    const SizedBox(height: 12),
                    if (data.recentOrders.isEmpty)
                      const Center(child: Text('Нет новых заказов'))
                    else
                      ...data.recentOrders.take(3).map((o) => _OrderTile(order: o, fmt: fmt, onUpdate: _refresh)),
                    const SizedBox(height: 24),
                    const SectionHeader(title: 'ЗАЯВКИ НА ДОСТАВКУ'),
                    const SizedBox(height: 12),
                    if (data.recentDeliveryTasks.isEmpty)
                      const Center(child: Text('Нет новых заявок'))
                    else
                      ...data.recentDeliveryTasks.take(3).map((t) => _DeliveryTile(task: t, onUpdate: _refresh)),
                    const SizedBox(height: 24),
                    const SectionHeader(title: 'COLOR LAB (ПОДБОР)'),
                    const SizedBox(height: 12),
                    if (data.pendingColorRequests.isEmpty)
                      const Center(child: Text('Нет активных подборов'))
                    else
                      ...data.pendingColorRequests.take(3).map((r) => _ColorLabTile(request: r, onUpdate: _refresh)),
                    const SizedBox(height: 24),
                    const SectionHeader(title: 'ОЖИДАЮТ ПРОВЕРКИ'),
                    const SizedBox(height: 12),
                    if (data.pendingPurchases.isEmpty)
                      const Center(child: Text('Все покупки проверены'))
                    else
                      ...data.pendingPurchases.take(3).map((p) => _PurchaseTile(purchase: p, fmt: fmt, onUpdate: _refresh)),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(DistributorDashboardMetrics metrics) {
    return Column(
      children: [
        GridView.count(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _metricCard(
              'Заказы',
              metrics.ordersToProcess.toString(),
              Icons.shopping_bag_outlined,
              AppColors.brandRed,
              () => context.go(AppRoutes.purchases),
            ),
            _metricCard(
              'Доставки',
              metrics.deliveriesToAssign.toString(),
              Icons.local_shipping_outlined,
              AppColors.info,
              () => context.push(AppRoutes.distributorDeliveries),
            ),
            _metricCard(
              'Проверка',
              metrics.purchasesToVerify.toString(),
              Icons.verified_outlined,
              AppColors.warning,
              () => context.go(AppRoutes.purchases),
            ),
            _metricCard(
              'Клиенты',
              metrics.clients.toString(),
              Icons.people_outline,
              AppColors.textPrimary,
              () => context.push(AppRoutes.distributorClients),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _metricCard(
          'Color Lab (Подбор)',
          metrics.colorLabPending.toString(),
          Icons.colorize_outlined,
          AppColors.accent,
          () => context.push(AppRoutes.distributorColorLab),
          fullWidth: true,
        ),
        const SizedBox(height: 12),
        _metricCard(
          'Склад и ассортимент',
          'OK',
          Icons.inventory_2_outlined,
          AppColors.success,
          () => context.push(AppRoutes.distributorStock),
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color, VoidCallback onTap, {bool fullWidth = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label.toUpperCase(),
                    softWrap: true,
                    style: const TextStyle(
                      color: AppColors.textSecondary, 
                      fontSize: 10, 
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22, 
                      fontWeight: FontWeight.w900, 
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(icon, color: color, size: 24),
          ],
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final Order order;
  final NumberFormat fmt;
  final VoidCallback onUpdate;
  const _OrderTile({required this.order, required this.fmt, required this.onUpdate});

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailSheet(order: order, fmt: fmt, onUpdate: onUpdate),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const PremiumIconBadge(icon: Icons.shopping_cart_outlined, size: 36, iconSize: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.documentNumber.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  Text(
                    (order.clientName ?? 'ID: ${order.clientId}').toUpperCase(),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge.fromOrderStatus(order.status),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _DeliveryTile extends StatelessWidget {
  final CourierTask task;
  final VoidCallback onUpdate;
  const _DeliveryTile({required this.task, required this.onUpdate});

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeliveryDetailSheet(task: task, onUpdate: onUpdate),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const PremiumIconBadge(icon: Icons.local_shipping_outlined, size: 36, iconSize: 18, iconColor: AppColors.info),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.typeDisplay.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  Text(
                    task.clientName.toUpperCase(),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge.fromCourierStatus(task.status),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _ColorLabTile extends StatelessWidget {
  final ColorRequest request;
  final VoidCallback onUpdate;
  const _ColorLabTile({required this.request, required this.onUpdate});

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ColorRequestDetailSheet(request: request, onUpdate: onUpdate),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const PremiumIconBadge(icon: Icons.colorize_outlined, size: 36, iconSize: 18, iconColor: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${request.carBrand} ${request.carModel}'.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  Text(
                    'Код: ${request.colorCode} · ${request.clientName ?? "Клиент"}'.toUpperCase(),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge.fromColorStatus(request.status),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Delivery task detail sheet
// ─────────────────────────────────────────────────────────────────────────────
class _DeliveryDetailSheet extends StatelessWidget {
  final CourierTask task;
  final VoidCallback onUpdate;
  const _DeliveryDetailSheet({required this.task, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final isNew = task.status == CourierTaskStatus.created;

    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const PremiumIconBadge(icon: Icons.local_shipping_outlined, size: 40, iconSize: 20, iconColor: AppColors.info),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.typeDisplay.toUpperCase(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                    StatusBadge.fromCourierStatus(task.status),
                  ],
                ),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const Divider(height: 24),
          _DetailRow(icon: Icons.person_outline, label: 'Клиент', value: task.clientName),
          if (task.contactName != null)
            _DetailRow(icon: Icons.badge_outlined, label: 'Контакт', value: task.contactName!),
          if (task.contactPhone != null)
            _DetailRow(icon: Icons.phone_outlined, label: 'Телефон', value: task.contactPhone!),
          _DetailRow(icon: Icons.location_on_outlined, label: 'Адрес', value: task.address),
          if (task.timeSlot.isNotEmpty)
            _DetailRow(icon: Icons.schedule_outlined, label: 'Время', value: task.timeSlot),
          if (task.courierName != null)
            _DetailRow(icon: Icons.delivery_dining_outlined, label: 'Курьер', value: task.courierName!),
          if (task.comment != null && task.comment!.isNotEmpty)
            _DetailRow(icon: Icons.comment_outlined, label: 'Комментарий', value: task.comment!),
          if (task.courierComment != null && task.courierComment!.isNotEmpty)
            _DetailRow(icon: Icons.chat_bubble_outline, label: 'Отчёт курьера', value: task.courierComment!),
          if (isNew) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _handleCancel(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('ОТМЕНИТЬ', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _handleAssign(context);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlack),
                    child: const Text('НАЗНАЧИТЬ КУРЬЕРА', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отменить заявку?'),
        content: const Text('Заявка на доставку будет аннулирована.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('НЕТ')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('ОТМЕНИТЬ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await DataRepository().updateDeliveryStatus(task.id, status: 'cancelled');
      onUpdate();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _handleAssign(BuildContext context) async {
    String? selectedCourierId;
    bool loadingCouriers = true;
    List<Map<String, dynamic>> couriers = [];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          if (loadingCouriers) {
            DataRepository().distributorCouriers().then((data) {
              if (ctx.mounted) setS(() { couriers = data; loadingCouriers = false; });
            }).catchError((_) { if (ctx.mounted) setS(() => loadingCouriers = false); });
          }
          return AlertDialog(
            title: const Text('Назначить курьера', style: TextStyle(fontWeight: FontWeight.w900)),
            content: loadingCouriers
                ? const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()))
                : DropdownButtonFormField<String>(
                    value: selectedCourierId,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Не назначен')),
                      ...couriers.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name']))),
                    ],
                    onChanged: (v) => setS(() => selectedCourierId = v),
                  ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ОТМЕНА')),
              ElevatedButton(
                onPressed: selectedCourierId == null ? null : () => Navigator.pop(ctx, {'courierId': selectedCourierId}),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlack),
                child: const Text('НАЗНАЧИТЬ', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          );
        },
      ),
    );

    if (result == null) return;
    try {
      await DataRepository().updateDeliveryStatus(task.id, status: 'assigned', courierId: result['courierId'] as String?);
      onUpdate();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order detail sheet
// ─────────────────────────────────────────────────────────────────────────────
class _OrderDetailSheet extends StatelessWidget {
  final Order order;
  final NumberFormat fmt;
  final VoidCallback onUpdate;
  const _OrderDetailSheet({required this.order, required this.fmt, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final isPending = order.status == OrderStatus.newOrder;

    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const PremiumIconBadge(icon: Icons.shopping_cart_outlined, size: 40, iconSize: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.documentNumber.toUpperCase(),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                    StatusBadge.fromOrderStatus(order.status),
                  ],
                ),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const Divider(height: 24),
          _DetailRow(icon: Icons.person_outline, label: 'Клиент', value: order.clientName ?? 'ID: ${order.clientId}'),
          if (order.clientInn != null)
            _DetailRow(icon: Icons.badge_outlined, label: 'ИНН', value: order.clientInn!),
          _DetailRow(icon: Icons.store_outlined, label: 'Магазин', value: order.storeName),
          _DetailRow(icon: Icons.calendar_today_outlined, label: 'Дата', value: DateFormat('dd.MM.yyyy').format(order.date)),
          _DetailRow(
            icon: Icons.payments_outlined,
            label: 'Сумма',
            value: '${fmt.format(order.totalAmount)} ₽',
            valueColor: AppColors.brandRed,
          ),
          _DetailRow(
            icon: Icons.local_shipping_outlined,
            label: 'Доставка',
            value: order.deliveryMethod == 'self_pickup' ? 'Самовывоз' : 'Курьером',
          ),
          if (order.courierName != null)
            _DetailRow(icon: Icons.delivery_dining_outlined, label: 'Курьер', value: order.courierName!),
          if (order.estimatedDeliveryDate != null)
            _DetailRow(
              icon: Icons.event_available_outlined,
              label: 'Ожид. дата',
              value: DateFormat('dd.MM.yyyy').format(order.estimatedDeliveryDate!),
            ),
          if (order.comment != null && order.comment!.isNotEmpty)
            _DetailRow(icon: Icons.comment_outlined, label: 'Комментарий', value: order.comment!),
          if (order.rejectionReason != null && order.rejectionReason!.isNotEmpty)
            _DetailRow(
              icon: Icons.cancel_outlined,
              label: 'Причина отмены',
              value: order.rejectionReason!,
              valueColor: AppColors.error,
            ),
          if (order.items.isNotEmpty) ...[
            const Divider(height: 24),
            const Text('ПОЗИЦИИ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: AppColors.textSecondary, letterSpacing: 1)),
            const SizedBox(height: 8),
            ...order.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        Text(item.sku, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Text('${item.quantity} шт.', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            )),
          ],
          if (isPending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleReject(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('ОТМЕНИТЬ', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleAccept(context),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlack),
                    child: const Text('В РАБОТУ', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleReject(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отклонить заказ?'),
        content: const Text('Заказ будет отменён.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('НАЗАД')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('ОТМЕНИТЬ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await DataRepository().updateOrderStatus(order.id, status: 'rejected');
      onUpdate();
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _handleAccept(BuildContext context) async {
    if (order.deliveryMethod == 'self_pickup') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Взять в работу?'),
          content: const Text('Заказ будет принят (Самовывоз).'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('НАЗАД')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlack),
              child: const Text('ПОДТВЕРДИТЬ'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      try {
        await DataRepository().updateOrderStatus(order.id, status: 'accepted');
        onUpdate();
        if (context.mounted) Navigator.pop(context);
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
      return;
    }

    // Courier delivery: open styled bottom sheet for courier + date selection.
    final success = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CourierAssignmentSheet(order: order, fmt: fmt, onUpdate: onUpdate),
    );

    // Sheet already called onUpdate and closed itself on success.
    // Close the order detail sheet too.
    if (success == true && context.mounted) Navigator.pop(context);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Courier assignment bottom sheet (replaces old showDialog for Task 3)
// ─────────────────────────────────────────────────────────────────────────────

class _CourierAssignmentSheet extends StatefulWidget {
  final Order order;
  final NumberFormat fmt;
  final VoidCallback onUpdate;
  const _CourierAssignmentSheet({required this.order, required this.fmt, required this.onUpdate});

  @override
  State<_CourierAssignmentSheet> createState() => _CourierAssignmentSheetState();
}

class _CourierAssignmentSheetState extends State<_CourierAssignmentSheet> {
  String? _selectedCourierId;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  bool _loadingCouriers = true;
  bool _saving = false;
  List<Map<String, dynamic>> _couriers = [];

  @override
  void initState() {
    super.initState();
    DataRepository().distributorCouriers().then((data) {
      if (mounted) setState(() { _couriers = data; _loadingCouriers = false; });
    }).catchError((_) {
      if (mounted) setState(() => _loadingCouriers = false);
    });
  }

  Future<void> _submit() async {
    if (_selectedCourierId == null) return;
    setState(() => _saving = true);
    try {
      await DataRepository().updateOrderStatus(
        widget.order.id,
        status: 'accepted',
        courierId: _selectedCourierId,
        estimatedDeliveryDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
      );
      widget.onUpdate();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final fmt = widget.fmt;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                const PremiumIconBadge(icon: Icons.delivery_dining_outlined, size: 40, iconSize: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'НАЗНАЧИТЬ ДОСТАВКУ',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                      Text(
                        order.documentNumber.toUpperCase(),
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(height: 24),

            // Order summary
            const Text(
              'ДЕТАЛИ ЗАКАЗА',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: AppColors.brandRed, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.person_outline,
              label: 'Клиент',
              value: order.clientName ?? 'ID: ${order.clientId}',
            ),
            _DetailRow(icon: Icons.store_outlined, label: 'Магазин', value: order.storeName),
            _DetailRow(
              icon: Icons.payments_outlined,
              label: 'Сумма',
              value: '${fmt.format(order.totalAmount)} ₽',
              valueColor: AppColors.brandRed,
            ),
            if (order.items.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 5, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${item.name} × ${item.quantity}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )),
            ],
            const Divider(height: 24),

            // Courier section
            const Text(
              'КУРЬЕР',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: AppColors.brandRed, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            if (_loadingCouriers)
              const LinearProgressIndicator()
            else
              DropdownButtonFormField<String>(
                value: _selectedCourierId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                hint: const Text('Выберите курьера'),
                items: _couriers
                    .map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name'])))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCourierId = v),
              ),
            const SizedBox(height: 16),

            // Date section
            const Text(
              'ОЖИДАЕМАЯ ДАТА',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: AppColors.brandRed, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd.MM.yyyy').format(_selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Icon(Icons.calendar_today, size: 18, color: AppColors.brandRed),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: (_saving || _selectedCourierId == null) ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlack),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('В РАБОТУ', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Color request detail sheet
// ─────────────────────────────────────────────────────────────────────────────
class _ColorRequestDetailSheet extends StatelessWidget {
  final ColorRequest request;
  final VoidCallback onUpdate;
  const _ColorRequestDetailSheet({required this.request, required this.onUpdate});

  void _openComplete(BuildContext context) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompleteColorRequestSheet(request: request, onUpdate: onUpdate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canProcess = request.status == ColorRequestStatus.created ||
        request.status == ColorRequestStatus.pickedUp ||
        request.status == ColorRequestStatus.inProgress;
    final fmt = DateFormat('dd.MM.yyyy HH:mm');

    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const PremiumIconBadge(icon: Icons.colorize_outlined, size: 40, iconSize: 20, iconColor: AppColors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${request.carBrand} ${request.carModel}'.toUpperCase(),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                    Row(
                      children: [
                        StatusBadge.fromColorStatus(request.status),
                        if (request.urgent) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            color: AppColors.error,
                            child: const Text('СРОЧНО', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const Divider(height: 24),
          _DetailRow(icon: Icons.palette_outlined, label: 'Код цвета', value: request.colorCode),
          if (request.colorName.isNotEmpty)
            _DetailRow(icon: Icons.label_outline, label: 'Название цвета', value: request.colorName),
          if (request.vin.isNotEmpty)
            _DetailRow(icon: Icons.directions_car_outlined, label: 'VIN', value: request.vin),
          _DetailRow(icon: Icons.person_outline, label: 'Клиент', value: request.clientName ?? '—'),
          if (request.contactPerson != null)
            _DetailRow(icon: Icons.badge_outlined, label: 'Контакт', value: request.contactPerson!),
          if (request.contactPhone != null)
            _DetailRow(icon: Icons.phone_outlined, label: 'Телефон', value: request.contactPhone!),
          _DetailRow(
            icon: Icons.swap_horiz_outlined,
            label: 'Способ передачи',
            value: request.transferMethod == 'courier' ? 'Курьер' : 'Самовывоз',
          ),
          if (request.pickupAddress != null)
            _DetailRow(icon: Icons.location_on_outlined, label: 'Адрес', value: request.pickupAddress!),
          if (request.pickupTime != null)
            _DetailRow(icon: Icons.schedule_outlined, label: 'Время', value: fmt.format(request.pickupTime!)),
          if (request.slaDeadline != null)
            _DetailRow(
              icon: Icons.timer_outlined,
              label: 'Дедлайн SLA',
              value: fmt.format(request.slaDeadline!),
              valueColor: request.isOverdue ? AppColors.error : null,
            ),
          if (request.comment != null && request.comment!.isNotEmpty)
            _DetailRow(icon: Icons.comment_outlined, label: 'Комментарий', value: request.comment!),
          if (request.recipe != null && request.recipe!.isNotEmpty) ...[
            const Divider(height: 20),
            const Text('РЕЦЕПТ / ФОРМУЛА', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.brandRed)),
            const SizedBox(height: 6),
            Text(request.recipe!, style: const TextStyle(fontSize: 13, height: 1.5)),
          ],
          if (canProcess) ...[
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => _openComplete(context),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlack),
                child: const Text('ЗАВЕРШИТЬ ПОДБОР', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable detail row
// ─────────────────────────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _DetailRow({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: valueColor ?? AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _CompleteColorRequestSheet extends StatefulWidget {
  final ColorRequest request;
  final VoidCallback onUpdate;
  const _CompleteColorRequestSheet({required this.request, required this.onUpdate});

  @override
  State<_CompleteColorRequestSheet> createState() => _CompleteColorRequestSheetState();
}

class _CompleteColorRequestSheetState extends State<_CompleteColorRequestSheet> {
  final _recipeCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _recipeCtrl.text = widget.request.recipe ?? '';
  }

  @override
  void dispose() {
    _recipeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_recipeCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите формулу/рецепт')));
      return;
    }

    setState(() => _saving = true);
    try {
      await DataRepository().distributorUpdateColorRequest(widget.request.id, {
        'status': 'ready',
        'recipe': _recipeCtrl.text.trim(),
      });
      if (mounted) {
        widget.onUpdate();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Подбор завершен, клиент уведомлен'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      padding: EdgeInsets.fromLTRB(16, 20, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ЗАВЕРШЕНИЕ ПОДБОРА', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '${widget.request.carBrand} ${widget.request.carModel} · ${widget.request.colorCode}'.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _recipeCtrl,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'РЕЦЕПТ / ФОРМУЛА КРАСКИ',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlack),
              child: _saving 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('ГОТОВО (УВЕДОМИТЬ КЛИЕНТА)', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  final Purchase purchase;
  final NumberFormat fmt;
  final VoidCallback onUpdate;
  const _PurchaseTile({required this.purchase, required this.fmt, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const PremiumIconBadge(icon: Icons.receipt_outlined, size: 36, iconSize: 18, iconColor: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(purchase.documentNumber.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  Text(
                    (purchase.clientName ?? 'Сумма: ${fmt.format(purchase.totalAmount)} ₽').toUpperCase(),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge.fromPurchaseStatus(purchase.status),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PurchaseDetailsSheet(
        purchase: purchase,
        fmt: fmt,
        isDistributor: true,
        onUpdate: onUpdate,
      ),
    );
  }

}

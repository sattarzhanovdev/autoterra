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

class DistributorHomeScreen extends StatefulWidget {
  const DistributorHomeScreen({super.key});

  @override
  State<DistributorHomeScreen> createState() => _DistributorHomeScreenState();
}

class _DistributorHomeScreenState extends State<DistributorHomeScreen> {
  late Future<DistributorDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = DataRepository().distributorDashboard();
  }

  Future<void> _refresh() async {
    final next = DataRepository().distributorDashboard();
    setState(() {
      _future = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'ru_RU');
    return Scaffold(
      backgroundColor: AppColors.brandWhite,
      body: FutureBuilder<DistributorDashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final data = snapshot.data!;
          return RefreshIndicator(
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
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          AppLogo(height: 28),
                        ],
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
          );
        },
      ),
    );
  }

  Widget _buildMetricsGrid(DistributorDashboardMetrics metrics) {
    return GridView.count(
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
          AppColors.info,
          () => context.push(AppRoutes.distributorClients),
        ),
        _metricCard(
          'Склад',
          'OK',
          Icons.inventory_2_outlined,
          AppColors.success,
          () => context.push(AppRoutes.distributorStock),
        ),
      ],
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: ShapeDecoration(
          color: AppColors.surfaceCard,
          shape: BeveledRectangleBorder(
            side: const BorderSide(color: AppColors.border),
            borderRadius: BorderRadius.zero, // Chamfers are handled by BeveledRectangleBorder
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.textSecondary, 
                    fontSize: 10, 
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
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
    );
  }
}

class _OrderTile extends StatelessWidget {
  final Order order;
  final NumberFormat fmt;
  final VoidCallback onUpdate;
  const _OrderTile({required this.order, required this.fmt, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final isPending = order.status == OrderStatus.newOrder;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.surfaceCard,
      shape: const BeveledRectangleBorder(
        side: BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                const PremiumIconBadge(icon: Icons.shopping_cart_outlined, size: 36, iconSize: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.documentNumber.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                      Text(
                        (order.clientName ?? 'Клиент ID: ${order.clientId}').toUpperCase(),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Text('${fmt.format(order.totalAmount)} ₽', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              ],
            ),
            if (isPending) ...[
              const Divider(height: 24, thickness: 0.5),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _handleUpdate(context, 'rejected'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        minimumSize: const Size(0, 34),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('ОТМЕНИТЬ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleUpdate(context, 'accepted'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandBlack,
                        minimumSize: const Size(0, 34),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('В РАБОТУ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
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
        onUpdate();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
        }
      }
      return;
    }

    // For 'accepted' status
    if (order.deliveryMethod == 'self_pickup') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Взять в работу?'),
          content: const Text('Заказ будет отмечен как принятый (Самовывоз).'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ОТМЕНА')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlack),
              child: const Text('ПОДТВЕРДИТЬ'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      
      try {
        await DataRepository().updateOrderStatus(order.id, status: status);
        onUpdate();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
        }
      }
    } else {
      // Courier delivery: require assignment dialog
      String? selectedCourierId;
      DateTime? selectedDate = DateTime.now().add(const Duration(days: 1));
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
              title: const Text('Назначить доставку', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Выберите курьера и дату для заказа с доставкой:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    const Text('КУРЬЕР', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: AppColors.brandRed)),
                    const SizedBox(height: 4),
                    if (loadingCouriers)
                      const LinearProgressIndicator()
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
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ОТМЕНА')),
                ElevatedButton(
                  onPressed: selectedCourierId == null ? null : () {
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
        onUpdate();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
        }
      }
    }
  }
}

class _PurchaseTile extends StatelessWidget {
  final Purchase purchase;
  final NumberFormat fmt;
  final VoidCallback onUpdate;
  const _PurchaseTile({required this.purchase, required this.fmt, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final needsAction = purchase.status == PurchaseStatus.newPurchase ||
                        purchase.status == PurchaseStatus.pending || 
                        purchase.status == PurchaseStatus.pendingVerification ||
                        purchase.status == PurchaseStatus.underReview ||
                        purchase.status == PurchaseStatus.duplicateReview;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.surfaceCard,
      shape: const BeveledRectangleBorder(
        side: BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
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
                StatusBadge.fromPurchaseStatus(purchase.status),
              ],
            ),
            if (needsAction) ...[
              const Divider(height: 24, thickness: 0.5),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _handleVerify(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        minimumSize: const Size(0, 34),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('ОТКЛОНИТЬ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleVerify(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        minimumSize: const Size(0, 34),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('ПОДТВЕРДИТЬ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
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
      onUpdate();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }
}

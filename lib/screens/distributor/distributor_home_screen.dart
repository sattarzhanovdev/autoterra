import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/section_header.dart';

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
              () => context.push(AppRoutes.distributorOrders),
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
              () => context.push(AppRoutes.distributorPurchasesVerification),
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
        const SizedBox(height: 12),
        // Подарок по рекомендации — это скидка или отсрочка, то есть деньги
        // дистрибьютора. По п. 7 ТЗ он должен согласовать её лично.
        _metricCard(
          'Подарки на согласовании',
          '',
          Icons.card_giftcard_outlined,
          AppColors.brandRed,
          () => context.push(AppRoutes.distributorReferralGifts),
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

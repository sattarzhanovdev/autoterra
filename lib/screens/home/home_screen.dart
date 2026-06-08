import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/premium_icon_badge.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/common/section_header.dart';

import '../distributor/distributor_home_screen.dart';
import '../../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final role = authService.currentRole;
    if (role == UserRole.distributor) {
      return const DistributorHomeScreen();
    }
    return const ClientHomeScreen();
  }
}

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  late Future<DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = DataRepository().dashboard();
  }

  Future<void> _refresh() async {
    final next = DataRepository().dashboard();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'ru_RU');
    return Scaffold(
      backgroundColor: AppColors.brandWhite,
      body: FutureBuilder<DashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _BackendError(message: snapshot.error.toString());
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 118,
                  pinned: true,
                  backgroundColor: AppColors.brandBlack,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      color: AppColors.brandBlack,
                      padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
                      child: const Center(
                        child: AppLogo(height: 32),
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
                        _buildQuickActions(context),
                        const SizedBox(height: 20),
                        _buildRecentPurchases(
                          data.recentPurchases,
                          fmt,
                          context,
                        ),
                        const SizedBox(height: 20),
                        _buildStatusCard(
                          data.client,
                          data.distributor,
                          fmt,
                          context,
                        ),
                        const SizedBox(height: 20),
                        _buildColorRequests(data.activeColorRequests, context),
                        const SizedBox(height: 20),
                        _buildDistributorCard(data.distributor, context),
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

  Widget _buildStatusCard(
    Client client,
    Distributor distributor,
    NumberFormat fmt,
    BuildContext context,
  ) {
    return Card(
      color: AppColors.brandBlack,
      shape: const BeveledRectangleBorder(
        borderRadius: BorderRadius.only(topRight: Radius.circular(20)),
        side: BorderSide(color: AppColors.brandRed, width: 0.5),
      ),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.brandRed, width: 3)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CategoryBadge(category: client.categoryLabel),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client.name.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'ИНН: ${client.inn}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge.fromPartnerStatus(client.partnerStatus),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _statItem(
                  'ЗАКУПКИ',
                  '${fmt.format(client.totalPurchases)} ₽',
                  AppColors.brandRed,
                ),
                _vertDivider(),
                _statItem('РЕГИОН', client.region.toUpperCase(), Colors.white),
                _vertDivider(),
                _statItem('СТАТУС', 'АКТИВНЫЙ', AppColors.success),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 10,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _vertDivider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withValues(alpha: 0.15),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _QuickAction(
        Icons.shopping_bag_outlined,
        'Заказ и ассортимент',
        () => context.push(AppRoutes.order),
      ),
      _QuickAction(
        Icons.receipt_long_outlined,
        'Мои покупки',
        () => context.push(AppRoutes.purchases),
      ),
      _QuickAction(
        Icons.palette_outlined,
        'Подбор цвета',
        () => context.push(AppRoutes.colorCenter),
      ),
      _QuickAction(
        Icons.local_shipping_outlined,
        'Доставка',
        () => context.push(AppRoutes.delivery),
      ),
      _QuickAction(
        Icons.help_outline_rounded,
        'Мои обращения',
        () => context.push(AppRoutes.qa),
      ),
      _QuickAction(
        Icons.smart_toy_outlined,
        'AI-помощник',
        () => context.push(AppRoutes.aiAssistant),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Что нужно сделать?'),
        const SizedBox(height: 12),
        GridView.count(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.16,
          children: actions.map(_buildActionTile).toList(),
        ),
      ],
    );
  }

  Widget _buildActionTile(_QuickAction action) {
    return GestureDetector(
      onTap: action.onTap,
      child: Card(
        color: AppColors.surfaceCard,
        shape: const BeveledRectangleBorder(
          side: BorderSide(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PremiumIconBadge(icon: action.icon, size: 36, iconSize: 18),
            const SizedBox(height: 6),
            Text(
              action.label.toUpperCase(),
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPurchases(
    List<Purchase> purchases,
    NumberFormat fmt,
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'ПОСЛЕДНИЕ ПОКУПКИ',
          actionLabel: 'ВСЕ',
          onAction: () => context.push(AppRoutes.purchases),
        ),
        const SizedBox(height: 12),
        ...purchases.map((p) => _PurchaseListItem(purchase: p, fmt: fmt)),
      ],
    );
  }

  Widget _buildColorRequests(
    List<ColorRequest> requests,
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'ЦЕНТР ЦВЕТА',
          actionLabel: 'ВСЕ',
          onAction: () => context.push(AppRoutes.colorCenter),
        ),
        const SizedBox(height: 12),
        ...requests.take(2).map((r) => _ColorRequestItem(request: r)),
      ],
    );
  }

  Widget _buildDistributorCard(Distributor distributor, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'МОЙ ДИСТРИБЬЮТОР'),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => context.push(AppRoutes.distributor),
          child: Card(
            color: AppColors.surfaceCard,
            shape: const BeveledRectangleBorder(
              side: BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const PremiumIconBadge(
                    icon: Icons.store,
                    size: 40,
                    iconSize: 20,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          distributor.name.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          distributor.regions.join(', ').toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          distributor.phone,
                          style: const TextStyle(
                            color: AppColors.brandRed,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BackendError extends StatelessWidget {
  final String message;

  const _BackendError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40),
            const SizedBox(height: 12),
            const Text(
              'ОШИБКА ПОДКЛЮЧЕНИЯ К СЕРВЕРУ',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseListItem extends StatelessWidget {
  final Purchase purchase;
  final NumberFormat fmt;
  const _PurchaseListItem({required this.purchase, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.surfaceCard,
      shape: const BeveledRectangleBorder(
        side: BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const PremiumIconBadge(
              icon: Icons.receipt_outlined,
              size: 40,
              iconSize: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    purchase.documentNumber.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    DateFormat('dd.MM.yyyy', 'ru_RU').format(purchase.date),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
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
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                StatusBadge.fromPurchaseStatus(purchase.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorRequestItem extends StatelessWidget {
  final ColorRequest request;
  const _ColorRequestItem({required this.request});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.surfaceCard,
      shape: const BeveledRectangleBorder(
        side: BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const PremiumIconBadge(
              icon: Icons.palette_outlined,
              size: 40,
              iconSize: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${request.carBrand} ${request.carModel}'.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${request.colorCode} · ${request.colorName}'.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge.fromColorStatus(request.status),
                if (request.urgent) ...[
                  const SizedBox(height: 4),
                  const StatusBadge(
                    label: 'СРОЧНО',
                    color: AppColors.brandRed,
                    filled: true,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction(this.icon, this.label, this.onTap);
}

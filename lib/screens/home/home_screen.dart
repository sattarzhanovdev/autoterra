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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = const DataRepository().dashboard();
  }

  Future<void> _refresh() async {
    final next = const DataRepository().dashboard();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'ru_RU');
    return Scaffold(
      backgroundColor: AppColors.canvas,
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
                  expandedHeight: 120,
                  pinned: true,
                  backgroundColor: AppColors.brandBlack,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      color: AppColors.brandBlack,
                      padding: const EdgeInsets.fromLTRB(20, 48, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              const AppLogo(height: 32),
                              const Spacer(),
                              Stack(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.notifications_none_sharp,
                                      color: Colors.white,
                                    ),
                                    onPressed: () =>
                                        context.push(AppRoutes.notifications),
                                  ),
                                  if (data.unreadCount > 0)
                                    Positioned(
                                      right: 10,
                                      top: 10,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        color: AppColors.brandRed,
                                        child: Center(
                                          child: Text(
                                            '',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data.client.name.toUpperCase(),
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
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
                        _buildQuickActions(context),
                        const SizedBox(height: 24),
                        _buildRecentPurchases(
                          data.recentPurchases,
                          fmt,
                          context,
                        ),
                        const SizedBox(height: 24),
                        _buildStatusCard(
                          data.client,
                          data.distributor,
                          fmt,
                          context,
                        ),
                        const SizedBox(height: 24),
                        _buildColorRequests(data.activeColorRequests, context),
                        const SizedBox(height: 24),
                        _buildDistributorCard(data.distributor, context),
                        const SizedBox(height: 120),
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
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.brandBlack,
        border: Border(left: BorderSide(color: AppColors.brandRed, width: 4)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: ClipPath(
              clipper: const ChamferClipper(cut: 16),
              child: Container(width: 16, height: 16, color: AppColors.canvas),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    CategoryBadge(category: client.categoryLabel),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            client.name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'ИНН: ',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge.fromPartnerStatus(client.partnerStatus),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _statItem(
                      'ЗАКУПКИ',
                      ' ₽',
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
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white.withOpacity(0.4),
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w900,
              fontSize: 13,
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
      width: 1.5,
      height: 24,
      color: Colors.white12,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _QuickAction(
        Icons.shopping_bag_outlined,
        'ЗАКАЗ И ПРАЙС',
        () => context.push(AppRoutes.order),
      ),
      _QuickAction(
        Icons.receipt_long_outlined,
        'МОИ ПОКУПКИ',
        () => context.push(AppRoutes.purchases),
      ),
      _QuickAction(
        Icons.palette_outlined,
        'ПОДБОР ЦВЕТА',
        () => context.push(AppRoutes.colorCenter),
      ),
      _QuickAction(
        Icons.local_shipping_outlined,
        'ДОСТАВКА',
        () => context.push(AppRoutes.delivery),
      ),
      _QuickAction(
        Icons.help_center_outlined,
        'ВОПРОС-ОТВЕТ',
        () => context.push(AppRoutes.qa),
      ),
      _QuickAction(
        Icons.smart_toy_outlined,
        'AI-ПОМОЩНИК',
        () => context.push(AppRoutes.aiAssistant),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'БЫСТРЫЙ ДОСТУП'),
        const SizedBox(height: 12),
        GridView.count(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.1,
          children: actions.map(_buildActionTile).toList(),
        ),
      ],
    );
  }

  Widget _buildActionTile(_QuickAction action) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PremiumIconBadge(icon: action.icon, size: 36, iconSize: 18),
            const SizedBox(height: 8),
            Text(
              action.label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: 0.2,
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
        const SectionHeader(title: 'ДИСТРИБЬЮТОР'),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => context.push(AppRoutes.distributor),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.brandBlack, width: 1.5),
            ),
            child: Row(
              children: [
                const PremiumIconBadge(
                  icon: Icons.store_sharp,
                  size: 42,
                  iconSize: 20,
                  iconColor: AppColors.brandBlack,
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
                          fontSize: 14,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        distributor.regions.join(', ').toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        distributor.phone,
                        style: const TextStyle(
                          color: AppColors.brandRed,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_sharp, color: AppColors.brandBlack, size: 16),
              ],
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_sharp, size: 48, color: AppColors.brandRed),
            const SizedBox(height: 16),
            const Text(
              'ОШИБКА ПОДКЛЮЧЕНИЯ',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.0),
            ),
            const SizedBox(height: 12),
            Text(
              message.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
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
                    fontSize: 13,
                  ),
                ),
                Text(
                  DateFormat('dd.MM.yyyy', 'ru_RU').format(purchase.date),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                ' ₽',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: AppColors.brandBlack,
                ),
              ),
              const SizedBox(height: 6),
              StatusBadge.fromPurchaseStatus(purchase.status),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorRequestItem extends StatelessWidget {
  final ColorRequest request;
  const _ColorRequestItem({required this.request});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
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
                  ' '.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                Text(
                  ' · '.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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
                const SizedBox(height: 6),
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
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction(this.icon, this.label, this.onTap);
}
 final VoidCallback onTap;
  const _QuickAction(this.icon, this.label, this.onTap);
}

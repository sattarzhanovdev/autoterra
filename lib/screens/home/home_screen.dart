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
                      padding: const EdgeInsets.fromLTRB(20, 48, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              const AppLogo(height: 34),
                              const Spacer(),
                              Stack(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.notifications_outlined,
                                      color: Colors.white,
                                    ),
                                    onPressed: () =>
                                        context.push(AppRoutes.notifications),
                                  ),
                                  if (data.unreadCount > 0)
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        color: AppColors.brandRed,
                                        child: Center(
                                          child: Text(
                                            '${data.unreadCount}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            data.client.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
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
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.brandBlack,
        border: Border(left: BorderSide(color: AppColors.brandRed, width: 3)),
      ),
      child: Stack(
        children: [
          // Chamfer cut top-right
          Positioned(
            top: 0,
            right: 0,
            child: CustomPaint(
              size: const Size(24, 24),
              painter: _ChamferPainter(),
            ),
          ),
          Padding(
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
                            client.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'ИНН: ${client.inn}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
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
                      'Закупки',
                      '${fmt.format(client.totalPurchases)} ₽',
                      AppColors.brandRed,
                    ),
                    _vertDivider(),
                    _statItem('Регион', client.region, Colors.white),
                    _vertDivider(),
                    _statItem('Статус', 'Активный', AppColors.success),
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
        'Вопрос-ответ',
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
      child: Container(
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PremiumIconBadge(icon: action.icon, size: 38, iconSize: 19),
            const SizedBox(height: 6),
            Text(
              action.label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
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
          actionLabel: 'Все',
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
          actionLabel: 'Все',
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
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const PremiumIconBadge(
                  icon: Icons.store,
                  size: 44,
                  iconSize: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        distributor.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        distributor.regions.join(', '),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        distributor.phone,
                        style: const TextStyle(
                          color: AppColors.brandRed,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
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
              'Нет данных из backend',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
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
          const PremiumIconBadge(
            icon: Icons.receipt_outlined,
            size: 42,
            iconSize: 20,
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
                    fontSize: 13,
                  ),
                ),
                Text(
                  DateFormat('dd.MM.yyyy', 'ru_RU').format(purchase.date),
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
                '${fmt.format(purchase.totalAmount)} ₽',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
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
          const PremiumIconBadge(
            icon: Icons.palette_outlined,
            size: 42,
            iconSize: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${request.carBrand} ${request.carModel}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${request.colorCode} · ${request.colorName}',
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
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction(this.icon, this.label, this.onTap);
}

class _ChamferPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.brandWhite;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

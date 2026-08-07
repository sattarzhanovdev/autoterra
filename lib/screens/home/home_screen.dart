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
import '../../widgets/common/brand_icon.dart';

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
    // Тело блоком, а не стрелкой: `() => _future = next` возвращает сам Future,
    // и setState на это ругается ассертом «callback argument returned a Future».
    setState(() {
      _future = next;
    });
    // Ошибку глотаем намеренно: её показывает FutureBuilder по _future. Если
    // дать ей улететь отсюда, повторная неудачная попытка обвалится
    // необработанным исключением вместо того же экрана с кнопкой «Повторить».
    try {
      await next;
    } catch (_) {}
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
            return _BackendError(message: snapshot.error.toString(), onRetry: _refresh);
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
                        // Если при регистрации вопрос пропустили, спрашиваем
                        // здесь: иначе заявка навсегда останется висеть
                        // неподтверждённой, и пригласивший не получит подарок.
                        if (data.pendingReferralClaim != null) ...[
                          _PendingReferralBanner(
                            claim: data.pendingReferralClaim!,
                            onDecided: _refresh,
                          ),
                          const SizedBox(height: 20),
                        ],
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
          // Chamfer cut top-right (CustomPaint from main)
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
        BrandIcons.cart,
        'Заказ и ассортимент',
        () => context.push(AppRoutes.order),
      ),
      // «Мои покупки» и «AI-помощник» здесь не дублируем: у обоих есть свои
      // вкладки в нижней панели.
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
        Icons.card_giftcard_outlined,
        'Приведи друга',
        () => context.push(AppRoutes.referral),
      ),
      _QuickAction(
        Icons.school_outlined,
        'Обучение',
        () => context.push(AppRoutes.learning),
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
          childAspectRatio: 1.0,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
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
        ...requests.take(2).map((r) => _ColorRequestItem(
          request: r,
          onTap: () => _showColorDetails(r),
        )),
      ],
    );
  }

  void _showColorDetails(ColorRequest request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ColorRequestDetailsSheet(request: request),
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
      ],
    );
  }
}

/// Кто-то заявил, что привёл этого клиента. Пока клиент не ответит, заявка не
/// даёт права на подарок — иначе достаточно было бы вписать чужой ИНН.
class _PendingReferralBanner extends StatefulWidget {
  final PendingReferralClaim claim;
  final Future<void> Function() onDecided;

  const _PendingReferralBanner({required this.claim, required this.onDecided});

  @override
  State<_PendingReferralBanner> createState() => _PendingReferralBannerState();
}

class _PendingReferralBannerState extends State<_PendingReferralBanner> {
  bool _busy = false;

  Future<void> _decide(bool confirmed) async {
    setState(() => _busy = true);
    try {
      await DataRepository().confirmReferral(widget.claim.id, confirmed: confirmed);
      await widget.onDecided();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final claim = widget.claim;
    final where = claim.inviterCity.isEmpty ? '' : ', ${claim.inviterCity}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        border: Border.all(color: AppColors.brandRed),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ВАС ПРИГЛАСИЛИ?',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            '«${claim.inviterName}»$where указал, что пригласил вас в AutoTerra. '
            'Подтвердите, если это так — бонус получит тот, кто вас привёл.',
            style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (_busy)
            const Center(child: SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandRed),
            ))
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _decide(false),
                    child: const Text('НЕТ', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _decide(true),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandRed),
                    child: const Text('ДА', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BackendError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _BackendError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    // Раньше это был тупик: экран с ошибкой отдавался голым виджетом, кнопки
    // не было, а RefreshIndicator строился только в ветке успеха — обновить
    // было нечем, помогал только перезапуск приложения. Теперь и кнопка, и
    // жест «потянуть вниз» (для этого нужен прокручиваемый список).
    return RefreshIndicator(
      color: AppColors.brandRed,
      onRefresh: onRetry,
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
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
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: onRetry,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandBlack),
                        child: const Text(
                          'ПОВТОРИТЬ',
                          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
    );
  }
}

class _ColorRequestItem extends StatelessWidget {
  final ColorRequest request;
  final VoidCallback? onTap;
  const _ColorRequestItem({required this.request, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                      letterSpacing: 0.2,
                    ),
                  ),
                  Text(
                    request.paintType.label.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
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

class _ColorRequestDetailsSheet extends StatelessWidget {
  final ColorRequest request;
  const _ColorRequestDetailsSheet({required this.request});

  @override
  Widget build(BuildContext context) {
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
                    icon: Icons.palette_outlined,
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
                          '${request.carBrand} ${request.carModel}'.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          '${request.colorCode} · ${request.colorName}'.toUpperCase(),
                          style: const TextStyle(
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
                  InfoRow(label: 'СТАТУС', value: StatusBadge.fromColorStatus(request.status).label),
                  InfoRow(label: 'VIN', value: request.vin.toUpperCase()),
                  InfoRow(
                    label: 'ДАТА ЗАЯВКИ',
                    value: DateFormat('dd.MM.yyyy HH:mm', 'ru_RU').format(request.createdAt),
                  ),
                  if (request.comment != null && request.comment!.isNotEmpty)
                    InfoRow(label: 'КОММЕНТАРИЙ', value: request.comment!),
                  
                  if (request.status == ColorRequestStatus.ready && request.recipe != null) ...[
                    const Divider(height: 32),
                    const Text(
                      'РЕЦЕПТ ЦВЕТА',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.canvas,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        request.recipe!,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandBlack,
                      ),
                      child: const Text('ЗАКРЫТЬ'),
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

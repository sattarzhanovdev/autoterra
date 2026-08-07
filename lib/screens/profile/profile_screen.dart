import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/common/premium_icon_badge.dart';
import '../../widgets/common/section_header.dart';

import 'expert_profile_screen.dart';
import '../../widgets/common/brand_icon.dart';

class _StoreFormSheet extends StatefulWidget {
  final Store? store;
  final DataRepository repo;
  final VoidCallback onSaved;

  const _StoreFormSheet({this.store, required this.repo, required this.onSaved});

  @override
  State<_StoreFormSheet> createState() => _StoreFormSheetState();
}

class _StoreFormSheetState extends State<_StoreFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.store?.name ?? '');
    _addressCtrl = TextEditingController(text: widget.store?.address ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Введите название');
      return;
    }
    if (address.isEmpty) {
      setState(() => _error = 'Введите адрес');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      if (widget.store == null) {
        await widget.repo.createStore(name, address);
      } else {
        await widget.repo.updateStore(widget.store!.id, name, address);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = 'Ошибка: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.store != null;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
            decoration: const BoxDecoration(color: AppColors.brandBlack),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isEdit ? 'РЕДАКТИРОВАТЬ ТОЧКУ' : 'НОВАЯ ТОЧКА',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('НАЗВАНИЕ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'Например: Автосервис на Ленина',
                    filled: true,
                    fillColor: AppColors.canvas,
                    border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.border)),
                    focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.brandBlack, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('АДРЕС', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: _addressCtrl,
                  decoration: InputDecoration(
                    hintText: 'Улица, дом, город',
                    filled: true,
                    fillColor: AppColors.canvas,
                    border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.border)),
                    focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.brandBlack, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF0F0),
                      border: Border(left: BorderSide(color: AppColors.brandRed, width: 3)),
                    ),
                    child: Text(_error!, style: const TextStyle(color: AppColors.brandRed, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const BeveledRectangleBorder(),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            isEdit ? 'СОХРАНИТЬ' : 'ДОБАВИТЬ ТОЧКУ',
                            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 13),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<dynamic> _future;
  List<Store> _stores = [];
  bool _storesLoaded = false;
  final _repo = DataRepository();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final role = authService.currentRole;
    Future<dynamic> next;

    if (role == UserRole.client) {
      next = _repo.dashboard();
      _loadStores();
    } else if (role == UserRole.courier) {
      next = Future.value(authService.currentUserData);
    } else if (role == UserRole.aiExpert) {
      next = Future.value({});
    } else {
      next = _repo.me();
    }

    setState(() {
      _future = next;
    });
    await next;
  }

  Future<void> _loadStores() async {
    try {
      final stores = await _repo.clientStores();
      if (mounted) setState(() { _stores = stores; _storesLoaded = true; });
    } catch (_) {
      if (mounted) setState(() => _storesLoaded = true);
    }
  }

  void _showStoreForm({Store? store}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: AppShapes.border(size: AppShapes.chamferSm),
      useSafeArea: true,
      builder: (_) => _StoreFormSheet(
        store: store,
        repo: _repo,
        onSaved: _loadStores,
      ),
    );
  }

  Future<void> _deleteStore(Store store) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить точку?'),
        content: Text('«${store.name}» будет удалена.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: AppColors.brandRed)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _repo.deleteStore(store.id);
      _loadStores();
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = authService.currentRole;
    if (role == UserRole.aiExpert) {
      return const ExpertProfileScreen();
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('ПРОФИЛЬ', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: FutureBuilder<dynamic>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
          }

          final role = authService.currentRole;
          final data = snapshot.data;
          
          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildUnifiedHeader(role, data),
                  const SizedBox(height: 16),
                  _buildRoleSpecificSection(role, data),
                  const SizedBox(height: 16),
                  _buildUnifiedInfoSection(role, data),
                  if (role == UserRole.client && data is DashboardData) ...[
                    const SizedBox(height: 16),
                    _buildReferralSection(data),
                  ],
                  if (role == UserRole.client) ...[
                    const SizedBox(height: 16),
                    _buildStoresSection(),
                  ],
                  const SizedBox(height: 16),
                  _buildUnifiedSettingsSection(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Реферальная программа в профиле: код виден сразу, без захода в раздел —
  /// его чаще всего и диктуют коллеге по телефону.
  Widget _buildReferralSection(DashboardData data) {
    final code = data.client.referralCode;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                const Icon(Icons.card_giftcard_outlined, size: 18, color: AppColors.brandRed),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Реферальная программа', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                Text(
                  'ПРИГЛАШЕНО: ${data.referralInvitedCount}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (code == null || code.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Код приглашения ещё не выдан. Обновите страницу или обратитесь к своему дистрибьютору.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ВАШ КОД',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          code,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: 2,
                            color: AppColors.brandRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Скопировать код',
                    icon: const Icon(Icons.copy, size: 18, color: AppColors.textSecondary),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('КОД СКОПИРОВАН')),
                      );
                    },
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          // Бонусы — то, ради чего программа и нужна: ими оплачивается заказ.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'БОНУСНЫЙ СЧЁТ',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  '${NumberFormat('#,##0', 'ru_RU').format(data.bonusBalance)} ₽',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: data.bonusBalance > 0
                        ? AppColors.success
                        : AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          if (data.bonusBalance > 0)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                'Спишется при оплате заказа — уменьшит сумму к оплате.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
          const Divider(height: 1),
          ListTile(
            onTap: () => context.push(AppRoutes.referral),
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: AppShapes.cut(AppShapes.chamferSm),
              ),
              child: const Icon(Icons.groups_outlined, color: AppColors.primary, size: 20),
            ),
            title: const Text('Мои приглашения и бонусы', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: Text(
              data.referralGiftCount > 0
                  ? 'Бонусов начислено: ${data.referralGiftCount}'
                  : 'Пригласить сервис и отследить статус',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            dense: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStoresSection() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Row(
              children: [
                const Icon(Icons.store_outlined, size: 18, color: AppColors.brandRed),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Мои точки / магазины', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                TextButton.icon(
                  onPressed: () => _showStoreForm(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Добавить', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(foregroundColor: AppColors.brandRed, padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (!_storesLoaded)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (_stores.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('Нет добавленных точек', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _stores.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final store = _stores[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: AppShapes.cut(AppShapes.chamferSm),
                    ),
                    child: const Icon(BrandIcons.location, size: 18, color: AppColors.textSecondary),
                  ),
                  title: Text(store.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(store.address, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  trailing: PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'edit') _showStoreForm(store: store);
                      if (val == 'delete') _deleteStore(store);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Редактировать')])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 16, color: AppColors.brandRed), SizedBox(width: 8), Text('Удалить', style: TextStyle(color: AppColors.brandRed))])),
                    ],
                    icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textHint),
                  ),
                  dense: true,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildUnifiedHeader(UserRole role, dynamic data) {
    String name = '';
    String subLabel = '';
    IconData icon = BrandIcons.person;
    List<Widget> badges = [];

    if (role == UserRole.distributor && data != null) {
      final dist = DataRepository.distributorFromJson(data['distributor']);
      name = dist.name;
      subLabel = 'ДИСТРИБЬЮТОР AUTOTERRA';
      icon = Icons.store_outlined;
    } else if (role == UserRole.courier && data != null) {
      name = data['phone'] ?? 'Курьер';
      subLabel = 'ЛОГИСТИЧЕСКАЯ СЛУЖБА';
      icon = Icons.local_shipping_outlined;
    } else if (role == UserRole.aiExpert && data != null) {
      name = data['username']?.toString().toUpperCase() ?? 'ЭКСПЕРТ';
      subLabel = 'AI ТЕХНОЛОГ / ЭКСПЕРТ';
      icon = Icons.psychology_outlined;
    } else if (role == UserRole.manager && data != null) {
      name = data['username'] ?? 'Менеджер';
      subLabel = 'МЕНЕДЖЕР ПЛАТФОРМЫ';
      icon = Icons.manage_accounts_outlined;
    } else if (role == UserRole.admin && data != null) {
      name = data['username'] ?? 'Импортер';
      subLabel = 'ЦЕНТРАЛЬНЫЙ ОФИС / ИМПОРТЕР';
      icon = Icons.admin_panel_settings_outlined;
    } else if (data is DashboardData) {
      name = data.client.name;
      subLabel = 'АВТОСЕРВИС';
      icon = Icons.garage_outlined;
      badges = [
        StatusBadge.fromClientStatus(data.client.status),
        const SizedBox(width: 6),
        CategoryBadge(category: data.client.categoryLabel),
      ];
    }

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppShapes.cut(AppShapes.chamferSm),
                ),
                child: Icon(icon, color: AppColors.primary, size: 34),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subLabel,
                      style: const TextStyle(
                        color: AppColors.brandRed,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                    if (badges.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(children: badges),
                    ],
                  ],
                ),
              ),
              if (role == UserRole.client && data is DashboardData)
                StatusBadge.fromPartnerStatus(data.client.partnerStatus),
            ],
          ),
          if (role == UserRole.client && data is DashboardData) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                _headerStat('Покупки', '${NumberFormat('#,##0', 'ru_RU').format(data.client.totalPurchases)} ₽', AppColors.primary),
                _vDivider(),
                _headerStat('Рефералы', '${data.referralInvitedCount}', AppColors.success),
                _vDivider(),
                _headerStat('С нами с', DateFormat('MM.yyyy', 'ru_RU').format(data.client.createdAt), AppColors.textSecondary),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _vDivider() {
    return Container(width: 1, height: 32, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 4));
  }

  Widget _buildRoleSpecificSection(UserRole role, dynamic data) {
    if (role == UserRole.distributor && data != null) {
      return Column(
        children: [
          _buildActionCard(
            BrandIcons.person,
            'Мои клиенты',
            'Список всех автосервисов региона',
            () => context.push(AppRoutes.distributorClients),
            AppColors.info,
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            Icons.sync_alt,
            'Интеграция 1С',
            'Настройка обмена данными и остатков',
            () => context.push(AppRoutes.distributorIntegration),
            AppColors.brandRed,
          ),
        ],
      );
    } else if (role == UserRole.aiExpert && data != null) {
      final stats = data['stats'] as Map<String, dynamic>? ?? {};
      return Row(
        children: [
          Expanded(child: _expertStatCard('ОДОБРЕНО', stats['approvedCards']?.toString() ?? '0', Icons.verified_user_outlined)),
          const SizedBox(width: 12),
          Expanded(child: _expertStatCard('ОТВЕТОВ', stats['answeredTickets']?.toString() ?? '0', Icons.question_answer_outlined)),
          const SizedBox(width: 12),
          Expanded(child: _expertStatCard('РЕЙТИНГ', stats['rating']?.toString() ?? '0', BrandIcons.star)),
        ],
      );
    } else if (role == UserRole.client && data is DashboardData) {
      return _buildPartnerProgress(data.client);
    }
    return const SizedBox.shrink();
  }

  Widget _buildActionCard(IconData icon, String title, String subtitle, VoidCallback onTap, Color color) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: AppShapes.cut(AppShapes.chamferSm)),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        trailing: const Padding(
          padding: EdgeInsets.only(right: 12),
          child: Icon(Icons.chevron_right, size: 20),
        ),
        contentPadding: EdgeInsets.zero,
        dense: true,
      ),
    );
  }

  Widget _expertStatCard(String label, String value, IconData icon) {
    return AppCard(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 8, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildPartnerProgress(Client client) {
    final statuses = AppConstants.partnerStatuses;
    final currentIdx = statuses.indexOf(client.partnerStatus);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(BrandIcons.star, color: AppColors.brandRed, size: 20),
              const SizedBox(width: 8),
              const Text('Статус партнёра', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const Spacer(),
              StatusBadge.fromPartnerStatus(client.partnerStatus),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: statuses.asMap().entries.map((e) {
              final active = e.key <= currentIdx;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: active ? AppColors.primary : AppColors.border,
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            e.value,
                            style: TextStyle(
                              fontSize: 9,
                              color: active ? AppColors.primary : AppColors.textHint,
                              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    if (e.key < statuses.length - 1) const SizedBox(width: 4),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedInfoSection(UserRole role, dynamic data) {
    List<Widget> rows = [];
    String title = 'Данные аккаунта';

    if (role == UserRole.distributor && data != null) {
      final dist = DataRepository.distributorFromJson(data['distributor']);
      title = 'Данные организации';
      rows = [
        InfoRow(label: 'ИНН', value: dist.inn),
        InfoRow(label: 'Email', value: dist.email),
        InfoRow(label: 'Телефон', value: dist.phone),
        InfoRow(label: 'Регионы', value: dist.regions.join(', ')),
      ];
    } else if (role == UserRole.courier && data != null) {
      rows = [
        InfoRow(label: 'Телефон', value: data['phone'] ?? '-'),
        InfoRow(label: 'Роль', value: 'Курьер'),
      ];
    } else if ((role == UserRole.aiExpert || role == UserRole.manager || role == UserRole.admin) && data != null) {
      title = 'Личные данные';
      rows = [
        if (data['expertId'] != null) InfoRow(label: 'ID эксперта', value: data['expertId'].toString()),
        InfoRow(label: 'Email', value: data['email']?.toString() ?? '-'),
        InfoRow(label: 'Телефон', value: data['phone']?.toString() ?? '-'),
        if (data['specialty'] != null) InfoRow(label: 'Специализация', value: data['specialty']),
      ];
    } else if (data is DashboardData) {
      title = 'Данные сервиса';
      rows = [
        InfoRow(label: 'ИНН', value: data.client.inn),
        InfoRow(label: 'Регион', value: data.client.region),
        InfoRow(label: 'Контакт', value: data.client.contact),
        InfoRow(label: 'Телефон', value: data.client.phone),
      ];
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildUnifiedSettingsSection(BuildContext context) {
    final role = authService.currentRole;
    final hasSupportAccess = role != UserRole.distributor && role != UserRole.courier;

    return AppCard(
      child: Column(
        children: [
          _settingItem(
            Icons.notifications_outlined,
            'Уведомления',
            () => context.push(AppRoutes.notifications),
          ),
          if (hasSupportAccess) ...[
            const Divider(height: 1),
            _settingItem(
              Icons.help_outline,
              'Поддержка и FAQ',
              () => context.push(AppRoutes.qa),
            ),
          ],
          const Divider(height: 16),
          ListTile(
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: AppShapes.cut(AppShapes.chamferSm)),
              child: const Icon(Icons.logout, color: AppColors.error, size: 20),
            ),
            title: const Text('Выйти из аккаунта', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.error)),
            onTap: () => _showLogoutDialog(context),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ],
      ),
    );
  }

  Widget _settingItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: AppShapes.cut(AppShapes.chamferSm)),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.brandBlack, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24),
              PremiumIconBadge(
                icon: Icons.logout_rounded,
                size: 54,
                iconSize: 26,
              ),
              const SizedBox(height: 20),
              const Text(
                'ВЫХОД ИЗ СИСТЕМЫ',
                style: TextStyle(
                  fontFamily: 'TTOctosquares',
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1,
                  color: AppColors.brandBlack,
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Вы уверены, что хотите завершить сеанс? Для возобновления работы потребуется повторный вход.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'TTNeoris',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Divider(height: 1, color: AppColors.border),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.center,
                        child: const Text(
                          'ОТМЕНА',
                          style: TextStyle(
                            fontFamily: 'TTOctosquares',
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 0.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, height: 48, color: AppColors.border),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        await authService.logout();
                        if (context.mounted) {
                          context.go(AppRoutes.login);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.brandBlack,
                        ),
                        child: const Text(
                          'ВЫЙТИ',
                          style: TextStyle(
                            fontFamily: 'TTOctosquares',
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

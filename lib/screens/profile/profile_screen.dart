import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../services/data_repository.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/common/section_header.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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
      appBar: AppBar(
        title: const Text('Профиль сервиса'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () {}),
        ],
      ),
      body: FutureBuilder<DashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final client = snapshot.data!.client;
          final distributor = snapshot.data!.distributor;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(client, fmt, context),
                  const SizedBox(height: 16),
                  _buildPartnerProgress(client),
                  const SizedBox(height: 20),
                  _buildInfoSection(client),
                  const SizedBox(height: 16),
                  _buildDistributorSection(distributor, context),
                  const SizedBox(height: 16),
                  _buildSettingsSection(context),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(client, NumberFormat fmt, BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.garage_outlined,
                  color: AppColors.primary,
                  size: 34,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        StatusBadge.fromClientStatus(client.status),
                        const SizedBox(width: 6),
                        CategoryBadge(category: client.categoryLabel),
                      ],
                    ),
                  ],
                ),
              ),
              StatusBadge.fromPartnerStatus(client.partnerStatus),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              _headerStat(
                'Покупки',
                '${fmt.format(client.totalPurchases)} ₽',
                AppColors.primary,
              ),
              _vDivider(),
              _headerStat('Рефералы', '2', AppColors.success),
              _vDivider(),
              _headerStat(
                'Зарегистрирован',
                DateFormat('MM.yyyy', 'ru_RU').format(client.createdAt),
                AppColors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _vDivider() {
    return Container(
      width: 1,
      height: 32,
      color: AppColors.border,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildPartnerProgress(client) {
    final statuses = AppConstants.partnerStatuses;
    final currentIdx = statuses.indexOf(client.partnerStatus);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.stars_rounded,
                color: Color(0xFFD4A017),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Статус партнёра',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const Spacer(),
              StatusBadge.fromPartnerStatus(client.partnerStatus),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: statuses.asMap().entries.map((e) {
              final active = e.key <= currentIdx;
              final isLast = e.key == statuses.length - 1;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.primary
                                  : AppColors.border,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            e.value,
                            style: TextStyle(
                              fontSize: 9,
                              color: active
                                  ? AppColors.primary
                                  : AppColors.textHint,
                              fontWeight: active
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    if (!isLast) const SizedBox(width: 4),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            'Следующий уровень: Platinum · закупите ещё 150 000 ₽',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(client) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Данные сервиса',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          InfoRow(label: 'ИНН', value: client.inn),
          InfoRow(label: 'Регион', value: client.region),
          InfoRow(label: 'Город', value: client.city),
          InfoRow(label: 'Контакт', value: client.contact),
          InfoRow(label: 'Телефон', value: client.phone),
          InfoRow(
            label: 'Категория',
            value: '${client.categoryLabel} · ${client.categoryDescription}',
          ),
        ],
      ),
    );
  }

  Widget _buildDistributorSection(distributor, BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Мой дистрибьютор',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          InfoRow(label: 'Компания', value: distributor.name),
          InfoRow(label: 'ИНН', value: distributor.inn),
          InfoRow(label: 'Регионы', value: distributor.regions.join(', ')),
          InfoRow(
            label: 'Телефон',
            value: distributor.phone,
            valueColor: AppColors.primary,
          ),
          InfoRow(
            label: 'Email',
            value: distributor.email,
            valueColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    final items = [
      _SettingItem(
        Icons.notifications_outlined,
        'Уведомления',
        () => context.push(AppRoutes.notifications),
      ),
      _SettingItem(
        Icons.people_outline,
        'Рефералы',
        () => context.push(AppRoutes.referral),
      ),
      _SettingItem(Icons.security_outlined, 'Безопасность', () {}),
      _SettingItem(Icons.help_outline, 'Поддержка', () {}),
    ];

    return AppCard(
      child: Column(
        children: [
          ...items.asMap().entries.map(
            (e) => Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      e.value.icon,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    e.value.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.textHint,
                  ),
                  onTap: e.value.onTap,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                if (e.key < items.length - 1) const Divider(height: 1),
              ],
            ),
          ),
          const Divider(height: 16),
          ListTile(
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout, color: AppColors.error, size: 20),
            ),
            title: const Text(
              'Выйти из аккаунта',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.error,
              ),
            ),
            onTap: () => context.go(AppRoutes.login),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ],
      ),
    );
  }
}

class _SettingItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SettingItem(this.icon, this.label, this.onTap);
}

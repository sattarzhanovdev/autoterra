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
        title: const Text('ПРОФИЛЬ СЕРВИСА'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_sharp), onPressed: () {}),
        ],
      ),
      body: FutureBuilder<DashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString().toUpperCase()));
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
                  const SizedBox(height: 20),
                  _buildPartnerProgress(client),
                  const SizedBox(height: 24),
                  _buildInfoSection(client),
                  const SizedBox(height: 20),
                  _buildDistributorSection(distributor, context),
                  const SizedBox(height: 20),
                  _buildSettingsSection(context),
                  const SizedBox(height: 100),
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
                  color: AppColors.brandBlack,
                  borderRadius: BorderRadius.zero,
                ),
                child: const Icon(
                  Icons.garage_sharp,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        StatusBadge.fromClientStatus(client.status),
                        const SizedBox(width: 8),
                        CategoryBadge(category: client.categoryLabel),
                      ],
                    ),
                  ],
                ),
              ),
              StatusBadge.fromPartnerStatus(client.partnerStatus),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, thickness: 1.5),
          const SizedBox(height: 20),
          Row(
            children: [
              _headerStat(
                'ЗАКУПКИ',
                ' ₽',
                AppColors.brandRed,
              ),
              _vDivider(),
              _headerStat('РЕФЕРАЛЫ', '2', AppColors.brandBlack),
              _vDivider(),
              _headerStat(
                'РЕГИСТРАЦИЯ',
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
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
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

  Widget _vDivider() {
    return Container(
      width: 1.5,
      height: 28,
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
                Icons.stars_sharp,
                color: AppColors.brandBlack,
                size: 20,
              ),
              const SizedBox(width: 10),
              const Text(
                'СТАТУС ПАРТНЁРА',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
              ),
              const Spacer(),
              StatusBadge.fromPartnerStatus(client.partnerStatus),
            ],
          ),
          const SizedBox(height: 20),
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
                            height: 4,
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.brandRed
                                  : AppColors.border,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            e.value.toUpperCase(),
                            style: TextStyle(
                              fontSize: 8,
                              color: active
                                  ? AppColors.brandBlack
                                  : AppColors.textHint,
                              fontWeight: active
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                              letterSpacing: 0.3,
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
          const SizedBox(height: 12),
          Text(
            'СЛЕДУЮЩИЙ УРОВЕНЬ: PLATINUM · ЗАКУПИТЕ ЕЩЁ 150 000 ₽',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
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
            'ДАННЫЕ АВТОСЕРВИСА',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1.5),
          const SizedBox(height: 12),
          InfoRow(label: 'ИНН', value: client.inn),
          InfoRow(label: 'РЕГИОН', value: client.region.toUpperCase()),
          InfoRow(label: 'ГОРОД', value: client.city.toUpperCase()),
          InfoRow(label: 'КОНТАКТ', value: client.contact.toUpperCase()),
          InfoRow(label: 'ТЕЛЕФОН', value: client.phone),
          InfoRow(
            label: 'КАТЕГОРИЯ',
            value: ' · '.toUpperCase(),
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
            'МОЙ ДИСТРИБЬЮТОР',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1.5),
          const SizedBox(height: 12),
          InfoRow(label: 'КОМПАНИЯ', value: distributor.name.toUpperCase()),
          InfoRow(label: 'ИНН', value: distributor.inn),
          InfoRow(label: 'РЕГИОНЫ', value: distributor.regions.join(', ').toUpperCase()),
          InfoRow(
            label: 'ТЕЛЕФОН',
            value: distributor.phone,
            valueColor: AppColors.brandRed,
          ),
          InfoRow(
            label: 'EMAIL',
            value: distributor.email.toUpperCase(),
            valueColor: AppColors.brandBlack,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    final items = [
      _SettingItem(
        Icons.notifications_none_sharp,
        'УВЕДОМЛЕНИЯ',
        () => context.push(AppRoutes.notifications),
      ),
      _SettingItem(
        Icons.people_alt_sharp,
        'РЕФЕРАЛЬНАЯ ПРОГРАММА',
        () => context.push(AppRoutes.referral),
      ),
      _SettingItem(Icons.security_sharp, 'БЕЗОПАСНОСТЬ', () {}),
      _SettingItem(Icons.help_center_sharp, 'СЛУЖБА ПОДДЕРЖКИ', () {}),
    ];

    return AppCard(
      child: Column(
        children: [
          ...items.asMap().entries.map(
            (e) => Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.brandBlack,
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Icon(
                      e.value.icon,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    e.value.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_sharp,
                    size: 14,
                    color: AppColors.brandBlack,
                  ),
                  onTap: e.value.onTap,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                if (e.key < items.length - 1) const Divider(height: 1, thickness: 1),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 2, color: AppColors.brandBlack),
          const SizedBox(height: 8),
          ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.brandRed,
                borderRadius: BorderRadius.zero,
              ),
              child: const Icon(Icons.logout_sharp, color: Colors.white, size: 18),
            ),
            title: const Text(
              'ВЫЙТИ ИЗ АККАУНТА',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppColors.brandRed,
                letterSpacing: 0.5,
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

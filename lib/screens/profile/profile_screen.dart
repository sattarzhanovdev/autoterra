import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../services/auth_service.dart';
import '../../services/api_client.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/common/premium_icon_badge.dart';
import '../../widgets/common/section_header.dart';

import 'expert_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<dynamic> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final role = authService.currentRole;
    Future<dynamic> next;
    
    if (role == UserRole.client) {
      next = DataRepository().dashboard();
    } else if (role == UserRole.distributor) {
      next = ApiClient().me();
    } else if (role == UserRole.courier) {
      next = Future.value(authService.currentUserData);
    } else if (role == UserRole.aiExpert) {
      // Handled by returning different widget in build
      next = Future.value({}); 
    } else {
      // manager, admin
      next = DataRepository().me();
    }
    
    setState(() {
      _future = next;
    });
    await next;
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

  Widget _buildUnifiedHeader(UserRole role, dynamic data) {
    String name = '';
    String subLabel = '';
    IconData icon = Icons.person_outline;
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
                  borderRadius: BorderRadius.circular(16),
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
                _headerStat('Рефералы', '2', AppColors.success),
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
            Icons.people_outline,
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
          Expanded(child: _expertStatCard('РЕЙТИНГ', stats['rating']?.toString() ?? '0', Icons.star_outline)),
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
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
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
              const Icon(Icons.stars_rounded, color: AppColors.brandRed, size: 20),
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
                              borderRadius: BorderRadius.circular(3),
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
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
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
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../services/data_repository.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/premium_icon_badge.dart';

class ExpertProfileScreen extends StatefulWidget {
  const ExpertProfileScreen({super.key});

  @override
  State<ExpertProfileScreen> createState() => _ExpertProfileScreenState();
}

class _ExpertProfileScreenState extends State<ExpertProfileScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = DataRepository().me();
  }

  Future<void> _refresh() async {
    final next = DataRepository().me();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandWhite,
      appBar: AppBar(
        backgroundColor: AppColors.brandBlack,
        title: const Text(
          'ПРОФИЛЬ ЭКСПЕРТА',
          style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppColors.brandRed));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }
          
          final data = snapshot.data!;
          final stats = data['stats'] as Map<String, dynamic>? ?? {};
          
          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildExpertHeader(data),
                  const SizedBox(height: 16),
                  _buildStatsSection(stats),
                  const SizedBox(height: 16),
                  _buildInfoSection(data),
                  const SizedBox(height: 16),
                  _buildActionsSection(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExpertHeader(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: BeveledRectangleBorder(
          side: BorderSide(color: AppColors.brandBlack, width: 1),
          borderRadius: BorderRadius.zero,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const ShapeDecoration(
              color: AppColors.brandBlack,
              shape: BeveledRectangleBorder(),
            ),
            child: const Icon(Icons.psychology, color: AppColors.brandRed, size: 48),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['username']?.toString().toUpperCase() ?? 'ЭКСПЕРТ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: AppColors.brandRed,
                  child: const Text(
                    'AI ТЕХНОЛОГ / ЭКСПЕРТ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Специализация: ${data['specialty'] ?? 'ЛКМ и кузовной ремонт'}',
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(Map<String, dynamic> stats) {
    return Row(
      children: [
        Expanded(child: _statCard('ОДОБРЕНО', stats['approvedCards']?.toString() ?? '0', Icons.verified_user)),
        const SizedBox(width: 12),
        Expanded(child: _statCard('ОТВЕТОВ', stats['answeredTickets']?.toString() ?? '0', Icons.question_answer)),
        const SizedBox(width: 12),
        Expanded(child: _statCard('РЕЙТИНГ', stats['rating']?.toString() ?? '0', Icons.star)),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const ShapeDecoration(
        color: AppColors.brandBlack,
        shape: BeveledRectangleBorder(),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textHint,
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(Map<String, dynamic> data) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ЛИЧНЫЕ ДАННЫЕ',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          InfoRow(label: 'ID эксперта', value: data['expertId']?.toString() ?? '-'),
          InfoRow(label: 'Email', value: data['email']?.toString() ?? '-'),
          InfoRow(label: 'Телефон', value: data['phone']?.toString() ?? '-'),
          InfoRow(label: 'Регион', value: data['region']?.toString() ?? 'Все регионы'),
          InfoRow(label: 'Дата начала', value: data['dateJoined']?.toString() ?? '-'),
        ],
      ),
    );
  }

  Widget _buildActionsSection(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          _actionTile(
            Icons.notifications_none,
            'УВЕДОМЛЕНИЯ',
            () => context.push(AppRoutes.notifications),
          ),
          const Divider(),
          _actionTile(
            Icons.logout,
            'ВЫЙТИ ИЗ СИСТЕМЫ',
            () => _showLogoutDialog(context),
            isDestructive: true,
          ),
        ],
      ),
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

  Widget _actionTile(IconData icon, String label, VoidCallback onTap, {bool isDestructive = false}) {
    final color = isDestructive ? AppColors.brandRed : AppColors.brandBlack;
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 16),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}

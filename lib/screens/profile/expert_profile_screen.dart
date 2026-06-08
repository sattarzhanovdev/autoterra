import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../services/data_repository.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/section_header.dart';

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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
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
          side: BorderSide(color: Color(0xFF171717), width: 1),
          borderRadius: BorderRadius.zero,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const ShapeDecoration(
              color: Color(0xFF171717),
              shape: BeveledRectangleBorder(),
            ),
            child: const Icon(Icons.psychology, color: Color(0xFFF01D2C), size: 48),
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
                  color: const Color(0xFFF01D2C),
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
                    color: Colors.grey,
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
        color: Color(0xFF171717),
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
              color: Colors.grey,
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
            Icons.security,
            'БЕЗОПАСНОСТЬ',
            () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Раздел управления безопасностью в разработке')),
            ),
          ),
          const Divider(),
          _actionTile(
            Icons.logout,
            'ВЫЙТИ ИЗ СИСТЕМЫ',
            () async {
              await authService.logout();
              if (context.mounted) context.go(AppRoutes.login);
            },
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, VoidCallback onTap, {bool isDestructive = false}) {
    final color = isDestructive ? const Color(0xFFF01D2C) : const Color(0xFF171717);
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

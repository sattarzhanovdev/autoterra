import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/models.dart' as app_models;
import '../../services/data_repository.dart';
import '../../widgets/common/premium_icon_badge.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<app_models.Notification>> _future;

  @override
  void initState() {
    super.initState();
    _future = const DataRepository().notifications();
  }

  Future<void> _refresh() async {
    final next = const DataRepository().notifications();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text(
              'Прочитать все',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<app_models.Notification>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final notifications = snapshot.data!;
          final unread = notifications.where((n) => !n.isRead).toList();
          final read = notifications.where((n) => n.isRead).toList();
          if (notifications.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 220),
                  Center(child: Text('Уведомлений пока нет')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (unread.isNotEmpty) ...[
                  const Text(
                    'Новые',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...unread.map((n) => _NotifCard(notification: n)),
                  const SizedBox(height: 20),
                ],
                if (read.isNotEmpty) ...[
                  const Text(
                    'Ранее',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...read.map((n) => _NotifCard(notification: n)),
                ],
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final app_models.Notification notification;
  const _NotifCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(notification.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: notification.isRead
            ? Colors.white
            : config.color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.isRead
              ? AppColors.border
              : config.color.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PremiumIconBadge(
              icon: config.icon,
              size: 40,
              iconSize: 20,
              iconColor: config.color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: notification.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(notification.createdAt),
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 11,
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

  _NotifConfig _getConfig(dynamic type) {
    switch (type.toString()) {
      case 'NotificationType.color':
        return _NotifConfig(Icons.palette_outlined, const Color(0xFF8B5CF6));
      case 'NotificationType.referral':
        return _NotifConfig(Icons.people_outline, AppColors.success);
      case 'NotificationType.order':
        return _NotifConfig(Icons.receipt_outlined, AppColors.primary);
      case 'NotificationType.delivery':
        return _NotifConfig(
          Icons.local_shipping_outlined,
          const Color(0xFFF59E0B),
        );
      case 'NotificationType.ai':
        return _NotifConfig(Icons.smart_toy_outlined, AppColors.accent);
      default:
        return _NotifConfig(Icons.notifications_outlined, AppColors.info);
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays > 0) return '${diff.inDays} д. назад';
    if (diff.inHours > 0) return '${diff.inHours} ч. назад';
    return '${diff.inMinutes} мин. назад';
  }
}

class _NotifConfig {
  final IconData icon;
  final Color color;
  const _NotifConfig(this.icon, this.color);
}

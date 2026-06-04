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
        title: const Text('УВЕДОМЛЕНИЯ'),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text(
              'ПРОЧИТАТЬ ВСЕ',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
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
            return Center(child: Text(snapshot.error.toString().toUpperCase()));
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
                  Center(child: Text('УВЕДОМЛЕНИЙ ПОКА НЕТ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary))),
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
                    'НОВЫЕ',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...unread.map((n) => _NotifCard(notification: n)),
                  const SizedBox(height: 20),
                ],
                if (read.isNotEmpty) ...[
                  const Text(
                    'РАНЕЕ',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
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
            : config.color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.zero,
        border: Border.all(
          color: notification.isRead
              ? AppColors.border
              : config.color.withValues(alpha: 0.2),
          width: notification.isRead ? 1.0 : 1.5,
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
                          notification.title.toUpperCase(),
                          style: TextStyle(
                            fontWeight: notification.isRead
                                ? FontWeight.w700
                                : FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.brandRed,
                            shape: BoxShape.rectangle,
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
                    _formatTime(notification.createdAt).toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
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
        return _NotifConfig(Icons.palette_sharp, AppColors.brandBlack);
      case 'NotificationType.referral':
        return _NotifConfig(Icons.people_sharp, AppColors.brandBlack);
      case 'NotificationType.order':
        return _NotifConfig(Icons.receipt_sharp, AppColors.brandRed);
      case 'NotificationType.delivery':
        return _NotifConfig(
          Icons.local_shipping_sharp,
          AppColors.warning,
        );
      case 'NotificationType.ai':
        return _NotifConfig(Icons.smart_toy_sharp, AppColors.brandRed);
      default:
        return _NotifConfig(Icons.notifications_sharp, AppColors.brandBlack);
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays > 0) return '${diff.inDays} Д. НАЗАД';
    if (diff.inHours > 0) return '${diff.inHours} Ч. НАЗАД';
    return '${diff.inMinutes} МИН. НАЗАД';
  }
}

class _NotifConfig {
  final IconData icon;
  final Color color;
  const _NotifConfig(this.icon, this.color);
}

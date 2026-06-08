import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    _future = DataRepository().notifications();
  }

  Future<void> _refresh() async {
    final next = DataRepository().notifications();
    setState(() => _future = next);
    await next;
  }

  Future<void> _readAll() async {
    try {
      await DataRepository().markNotificationsRead();
      _refresh();
    } catch (e) {
      //
    }
  }

  void _handleTap(app_models.Notification n) {
    if (n.relatedLink != null && n.relatedLink!.isNotEmpty) {
      context.push(n.relatedLink!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('УВЕДОМЛЕНИЯ'),
        actions: [
          TextButton(
            onPressed: _readAll,
            child: const Text(
              'ПРОЧИТАТЬ ВСЕ',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
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
                    'НОВЫЕ',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...unread.map((n) => _NotifCard(notification: n, onTap: () => _handleTap(n))),
                  const SizedBox(height: 24),
                ],
                if (read.isNotEmpty) ...[
                  const Text(
                    'ПРОЧИТАННЫЕ',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...read.map((n) => _NotifCard(notification: n, onTap: () => _handleTap(n))),
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
  final VoidCallback? onTap;
  const _NotifCard({required this.notification, this.onTap});

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(notification.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: notification.isRead
            ? Colors.white
            : config.color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.zero,
        border: Border.all(
          color: notification.isRead
              ? AppColors.border
              : config.color,
          width: notification.isRead ? 1 : 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.brandRed,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.body,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _formatTime(notification.createdAt).toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _NotifConfig _getConfig(dynamic type) {
    switch (type.toString()) {
      case 'NotificationType.color':
        return _NotifConfig(Icons.palette_outlined, AppColors.brandBlack);
      case 'NotificationType.referral':
        return _NotifConfig(Icons.people_outline, AppColors.brandBlack);
      case 'NotificationType.order':
        return _NotifConfig(Icons.receipt_outlined, AppColors.brandBlack);
      case 'NotificationType.delivery':
        return _NotifConfig(
          Icons.local_shipping_outlined,
          AppColors.brandRed,
        );
      case 'NotificationType.ai':
        return _NotifConfig(Icons.smart_toy_outlined, AppColors.brandRed);
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

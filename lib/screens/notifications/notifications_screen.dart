import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/models.dart' as app_models;
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/paginated_list_view.dart';
import '../../widgets/common/premium_icon_badge.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final PaginationController<app_models.Notification> _controller;

  @override
  void initState() {
    super.initState();
    // Лента идёт сплошным хронологическим списком: делить её на «новые» и
    // «прочитанные» при постраничной подгрузке нельзя — секции перемешались бы
    // по мере догрузки. Непрочитанные подсвечены в самой карточке.
    _controller = PaginationController<app_models.Notification>(
      fetchPage: (page) => DataRepository().notifications(page: page),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() => _controller.refresh();

  Future<void> _readAll() async {
    try {
      await DataRepository().markNotificationsRead();
      await _refresh();
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
      body: PaginatedListView<app_models.Notification>(
        controller: _controller,
        emptyMessage: 'УВЕДОМЛЕНИЙ ПОКА НЕТ',
        itemBuilder: (context, notification, _) => _NotifCard(
          notification: notification,
          onTap: () => _handleTap(notification),
        ),
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

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../services/push_notification_manager.dart';
import '../../services/auth_service.dart';

class AccountStatusScreen extends StatefulWidget {
  const AccountStatusScreen({super.key});

  @override
  State<AccountStatusScreen> createState() => _AccountStatusScreenState();
}

class _AccountStatusScreenState extends State<AccountStatusScreen> with WidgetsBindingObserver {
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (kIsWeb || !mounted) return;
      try { await PushNotificationManager().init(GoRouter.of(context)); } catch (_) { /* Status can always be refreshed without push. */ }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      await authService.refreshUser();
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось обновить статус. Проверьте подключение и повторите.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final restricted = ['blocked', 'archived'].contains(authService.currentUserData?['status']);
    return Scaffold(
      appBar: AppBar(title: const Text('AutoTerra')),
      body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(restricted ? Icons.lock_outline : Icons.hourglass_top, size: 64),
          const SizedBox(height: 24),
          Text(restricted ? 'ДОСТУП ОГРАНИЧЕН' : 'АККАУНТ НА ПРОВЕРКЕ', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Text(restricted ? 'Доступ к аккаунту ограничен. Обратитесь к менеджеру AutoTerra.' : 'Ваша регистрация получена. После проверки менеджером мы уведомим вас.', textAlign: TextAlign.center),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_error!, textAlign: TextAlign.center)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _loading ? null : _refresh, child: Text(_loading ? 'ОБНОВЛЕНИЕ…' : 'ПРОВЕРИТЬ СТАТУС')),
          TextButton(onPressed: () => authService.logout(), child: const Text('ВЫЙТИ')),
        ],
      ))),
    );
  }
}

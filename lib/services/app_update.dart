import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_client.dart';

class UpdatePolicy {
  final int installed;
  final Map<String, dynamic> data;
  UpdatePolicy(this.installed, this.data);
  bool get available => installed < (data['latestBuildNumber'] as num? ?? 0);
  bool get mandatory =>
      installed < (data['minimumSupportedBuildNumber'] as num? ?? 0);
}

/// Mounted once above the router. Lifecycle checks never run on rebuild.
class AppUpdateGate extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  final ApiClient? api;
  const AppUpdateGate({
    super.key,
    required this.child,
    required this.navigatorKey,
    this.api,
  });
  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('autoterra/app-info');
  bool _checking = false;
  bool _dialogOpen = false;
  final Set<String> _shown = {};
  DateTime? _lastCheck;
  List<UpdatePolicy>? _requiredUpdates;
  String? _detectedStore;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        _checking ||
        _dialogOpen) {
      return;
    }
    if (_lastCheck != null &&
        DateTime.now().difference(_lastCheck!) < const Duration(minutes: 5)) {
      return;
    }
    _checking = true;
    try {
      final info = await _channel.invokeMapMethod<String, dynamic>('getInfo');
      final installed = (info?['build'] as num?)?.toInt();
      if (installed == null) return;
      final detected = info?['store'] as String?;
      // Unknown installers: offer explicit store choices; no guessed destination.
      final stores = detected == null ? ['google_play', 'rustore'] : [detected];
      final results = await Future.wait(
        stores.map((store) async {
          try {
            return await (widget.api ?? ApiClient()).appVersion(
              store,
              installed,
            );
          } catch (_) {
            return <String, dynamic>{};
          }
        }),
      );
      _lastCheck = DateTime.now();
      final policies = results
          .map((data) => UpdatePolicy(installed, data))
          .where((p) => p.available || p.mandatory)
          .toList();
      if (!mounted || policies.isEmpty) return;
      policies.sort(
        (a, b) => (b.mandatory ? 1 : 0).compareTo(a.mandatory ? 1 : 0),
      );
      final policy = policies.first;
      if (policy.mandatory) {
        setState(() {
          _requiredUpdates = policies;
          _detectedStore = detected;
        });
        return;
      }
      final key =
          '${policy.data['store']}:${policy.data['latestBuildNumber']}:${policy.mandatory}';
      if (_shown.contains(key)) return;
      final dialogContext = widget.navigatorKey.currentContext;
      if (dialogContext == null || !dialogContext.mounted) return;
      _shown.add(key);
      _dialogOpen = true;
      await showDialog<void>(
        context: dialogContext,
        barrierDismissible: !policy.mandatory,
        useRootNavigator: true,
        builder: (ctx) => PopScope(
          canPop: !policy.mandatory,
          child: AlertDialog(
            title: Text(
              policy.mandatory
                  ? 'Необходимо обновление'
                  : 'Доступно обновление',
            ),
            content: Text(
              (policy.data['message'] as String?)?.trim().isNotEmpty == true
                  ? policy.data['message'] as String
                  : 'Вышла новая версия AutoTerra. Обновите приложение, чтобы получить последние улучшения и исправления.',
            ),
            actions: [
              if (!policy.mandatory)
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('ПОЗЖЕ'),
                ),
              for (final p in detected == null ? policies : [policy])
                TextButton(
                  onPressed: () async {
                    final uri = Uri.tryParse('${p.data['storeUrl']}');
                    final validHosts = p.data['store'] == 'rustore'
                        ? ['rustore.ru', 'www.rustore.ru']
                        : ['play.google.com'];
                    final opened =
                        uri != null &&
                        uri.scheme == 'https' &&
                        validHosts.contains(uri.host) &&
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                    if (!opened && ctx.mounted) {
                      ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Не удалось открыть магазин. Попробуйте ещё раз.',
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(
                    detected == null
                        ? 'ОБНОВИТЬ · ${p.data['store'] == 'rustore' ? 'RuStore' : 'Google Play'}'
                        : policy.mandatory
                        ? 'ОБНОВИТЬ ПРИЛОЖЕНИЕ'
                        : 'ОБНОВИТЬ',
                  ),
                ),
            ],
          ),
        ),
      );
      _dialogOpen = false;
    } catch (_) {
      // An unavailable version service must not prevent an ordinary startup.
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final required = _requiredUpdates;
    if (required == null) return widget.child;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: Material(
            color: Colors.black54,
            child: PopScope(
              canPop: false,
              child: Center(
                child: AlertDialog(
                  title: const Text('Необходимо обновление'),
                  content: const Text(
                    'Обновите AutoTerra, чтобы продолжить работу.',
                  ),
                  actions: [
                    for (final policy
                        in _detectedStore == null ? required : [required.first])
                      TextButton(
                        onPressed: () async {
                          final uri = Uri.tryParse(
                            '${policy.data['storeUrl']}',
                          );
                          final hosts = policy.data['store'] == 'rustore'
                              ? ['rustore.ru', 'www.rustore.ru']
                              : ['play.google.com'];
                          if (uri != null &&
                              uri.scheme == 'https' &&
                              hosts.contains(uri.host)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        child: Text(
                          _detectedStore == null
                              ? 'ОБНОВИТЬ · ${policy.data['store'] == 'rustore' ? 'RuStore' : 'Google Play'}'
                              : 'ОБНОВИТЬ ПРИЛОЖЕНИЕ',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

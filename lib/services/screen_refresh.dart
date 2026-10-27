import 'dart:async';
import 'package:flutter/widgets.dart';

/// Background failures retain the last successful UI; manual actions own errors.
class ScreenRefresh extends WidgetsBindingObserver {
  final bool Function() active;
  final Future<void> Function() refresh;
  late final Timer _timer;
  bool _running = false;
  bool _disposed = false;
  ScreenRefresh({required this.active, required this.refresh}) {
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _run();
      }
    });
  }
  Future<void> _run() async {
    if (_disposed || _running || !active()) return;
    _running = true;
    try {
      await refresh();
    } catch (_) {
      /* Keep the last successful data. */
    } finally {
      _running = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _run();
  }

  void dispose() {
    _disposed = true;
    _timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device preference: it survives app restarts and account changes.
class TextSizeSettings extends ChangeNotifier {
  static const storageKey = 'app_text_size';
  static const factors = [1.0, 1.15, 1.3, 1.5];
  static const labels = ['Обычный', 'Крупный', 'Очень крупный', 'Максимальный'];
  int _index = 0;
  int get index => _index;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(storageKey) ?? 0;
    _index = saved >= 0 && saved < factors.length ? saved : 0;
    notifyListeners();
  }

  Future<void> select(int index) async {
    if (index < 0 || index >= factors.length || index == _index) return;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setInt(storageKey, index)) {
      throw StateError('Не удалось сохранить размер текста');
    }
    _index = index;
    notifyListeners();
  }

  TextScaler scaler(TextScaler system) =>
      ReadableTextScaler(system, factors[_index]);
}

/// Add two logical pixels by default, retaining Android's nonlinear font scale.
/// No upper clamp: larger accessibility fonts must remain available.
class ReadableTextScaler extends TextScaler {
  final TextScaler system;
  final double factor;
  const ReadableTextScaler(this.system, this.factor);

  @override
  double scale(double fontSize) =>
      fontSize == 0 ? 0 : system.scale(fontSize + 2) * factor;

  @override
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) =>
      other is ReadableTextScaler &&
      other.system == system &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(system, factor);
}

final textSizeSettings = TextSizeSettings();

class AppTextSize extends StatelessWidget {
  final Widget child;
  final TextSizeSettings? settings;
  const AppTextSize({super.key, required this.child, this.settings});

  @override
  Widget build(BuildContext context) {
    final preferences = settings ?? textSizeSettings;
    final media = MediaQuery.of(context);
    return ListenableBuilder(
      listenable: preferences,
      builder: (context, _) => MediaQuery(
        data: media.copyWith(textScaler: preferences.scaler(media.textScaler)),
        child: child,
      ),
    );
  }
}

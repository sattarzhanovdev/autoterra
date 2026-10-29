import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/text_size_settings.dart';

class TextSizeScreen extends StatelessWidget {
  final TextSizeSettings? settings;
  const TextSizeScreen({super.key, this.settings});

  @override
  Widget build(BuildContext context) {
    final preferences = settings ?? textSizeSettings;
    return Scaffold(
      appBar: AppBar(title: const Text('Размер текста')),
      body: ListenableBuilder(
        listenable: preferences,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Выберите удобный размер. Изменения применяются ко всему приложению и сохраняются автоматически.',
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < TextSizeSettings.labels.length; i++)
              ListTile(
                key: ValueKey('text-size-$i'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                title: Text(TextSizeSettings.labels[i]),
                trailing: Icon(
                  preferences.index == i
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: preferences.index == i
                      ? AppColors.brandRed
                      : AppColors.textSecondary,
                ),
                selected: preferences.index == i,
                onTap: () async {
                  try {
                    await preferences.select(i);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Не удалось сохранить размер текста. Попробуйте ещё раз.',
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            const SizedBox(height: 20),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Пример текста',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Подбирайте материалы, оформляйте заказы и приглашайте друзей в AutoTerra.',
                      style: TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Системный размер шрифта также учитывается.'),
          ],
        ),
      ),
    );
  }
}

class TextSizeTile extends StatelessWidget {
  const TextSizeTile({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.text_fields, color: AppColors.brandRed),
    title: const Text('Размер текста'),
    subtitle: ListenableBuilder(
      listenable: textSizeSettings,
      builder: (context, _) =>
          Text(TextSizeSettings.labels[textSizeSettings.index]),
    ),
    trailing: const Icon(Icons.chevron_right),
    contentPadding: EdgeInsets.zero,
    onTap: () => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TextSizeScreen())),
  );
}

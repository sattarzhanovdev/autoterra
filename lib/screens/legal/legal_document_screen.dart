import 'package:flutter/material.dart';

import '../../core/legal_documents.dart';
import '../../core/theme.dart';

/// Экран правового документа: политики конфиденциальности, условий
/// использования или текста согласия на обработку персональных данных.
///
/// Открывается без входа — на него ведут ссылки с экранов входа и регистрации:
/// прочитать документы нужно до того, как ставить галочки.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(document.shortTitle, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        top: false,
        // Текст можно выделить и скопировать — например, чтобы переслать юристу.
        child: SelectionArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            children: [
              Text(
                document.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                document.edition,
                style: const TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
              for (final section in document.sections) _SectionView(section: section),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionView extends StatelessWidget {
  const _SectionView({required this.section});

  final LegalSection section;

  static const _body = TextStyle(
    fontSize: 14,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (section.heading != null) ...[
            Text(
              section.heading!.toUpperCase(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
                color: AppColors.brandBlack,
              ),
            ),
            const SizedBox(height: 10),
          ],
          for (final (index, block) in section.blocks.indexed) ...[
            if (index > 0) const SizedBox(height: 10),
            switch (block) {
              LegalParagraph(:final text) => Text(text, style: _body),
              LegalList(:final items) => _BulletList(items: items, style: _body),
            },
          ],
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items, required this.style});

  final List<String> items;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(top: 8, right: 12),
                  color: AppColors.brandRed,
                ),
                Expanded(child: Text(item, style: style)),
              ],
            ),
          ),
      ],
    );
  }
}

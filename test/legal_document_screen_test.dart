import 'package:autoterra/core/legal_documents.dart';
import 'package:autoterra/screens/legal/legal_document_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _documents = [
  LegalDocuments.privacyPolicy,
  LegalDocuments.termsOfUse,
  LegalDocuments.personalDataConsent,
];

void main() {
  /// Документы открываются с экранов входа и регистрации. Если любой раздел
  /// упадёт при вёрстке, пользователь не сможет прочитать условия до того, как
  /// поставить галочки, — поэтому прокручиваем каждый документ до последнего
  /// раздела.
  for (final document in _documents) {
    testWidgets('«${document.title}» отрисовывается до последнего раздела', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: LegalDocumentScreen(document: document)),
      );

      expect(find.text(document.title), findsOneWidget);
      expect(find.text(document.edition), findsOneWidget);

      final lastHeading = find.text(document.sections.last.heading!.toUpperCase());
      await tester.scrollUntilVisible(lastHeading, 300);
      expect(lastHeading, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  /// Первую версию модерация отклонила как незавершённый продукт. Заглушки
  /// вида «[ИНН]» в документах читаются именно так, а согласие без названия и
  /// адреса оператора не соответствует 152-ФЗ.
  test('В документах не осталось заглушек вместо реквизитов', () {
    expect(LegalOperator.inn, matches(RegExp(r'^\d{10}$')));
    expect(LegalOperator.ogrn, matches(RegExp(r'^\d{13}$')));
    expect(LegalOperator.email, contains('@'));

    for (final document in _documents) {
      for (final section in document.sections) {
        for (final block in section.blocks) {
          final texts = switch (block) {
            LegalParagraph(:final text) => [text],
            LegalList(:final items) => items,
          };
          for (final text in texts) {
            expect(text, isNot(contains('[')), reason: document.title);
          }
        }
      }
    }
  });
}

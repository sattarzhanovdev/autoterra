import 'package:autoterra/models/models.dart';
import 'package:autoterra/models/paginated.dart';
import 'package:autoterra/screens/referral/referral_screen.dart';
import 'package:autoterra/services/data_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class ReferralCopyRepository extends DataRepository {
  List<Map<String, num>> tiers = [
    {'from': 0, 'rate': 0.75},
    {'from': 250000, 'rate': 1.25},
  ];

  @override
  Future<(Paginated<Referral>, Map<String, dynamic>)> referrals({
    int page = 1,
    int pageSize = 20,
  }) async => (
    const Paginated<Referral>.empty(),
    {
      'bonusTiers': tiers,
      'activityMin': 35000,
      'referralCode': 'AT-TEST',
      'inviteLink': 'https://example.test/register?ref=AT-TEST',
    },
  );
}

void main() {
  testWidgets(
    'program explains qualifying purchases and uses actual server terms',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ReferralScreen(repository: ReferralCopyRepository())),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('После подтверждения его заказов'),
        findsOneWidget,
      );
      expect(
        find.textContaining('каждого приглашённого участника'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Ранее начисленные бонусы не пересчитываются'),
        findsOneWidget,
      );
      expect(find.text('0,75%'), findsOneWidget);
      expect(find.text('1,25%'), findsOneWidget);
      expect(
        find.textContaining('35\u00a0000 ₽ за календарный месяц'),
        findsOneWidget,
      );
      expect(
        find.textContaining('бонусный баланс аннулируется'),
        findsOneWidget,
      );
      expect(find.textContaining('КАПАЕТ'), findsNothing);
      expect(find.textContaining('СГОРАЮТ'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'manual invitation does not promise a bonus just for confirmation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ReferralScreen(repository: ReferralCopyRepository())),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('ДОБАВИТЬ +'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('ДОБАВИТЬ +'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Бонусы начисляются за подтверждённые закупки и выполненные заказы после подтверждения приглашения.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Бонус начислится после того, как СТО при регистрации',
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a single rate has no fictitious upper threshold of zero', (
    tester,
  ) async {
    final repo = ReferralCopyRepository()
      ..tiers = [
        {'from': 0, 'rate': 0.75},
      ];
    await tester.pumpWidget(
      MaterialApp(home: ReferralScreen(repository: repo)),
    );
    await tester.pumpAndSettle();
    expect(find.text('От 0 ₽'), findsOneWidget);
    expect(find.text('До 0 ₽'), findsNothing);
    expect(find.text('0,75%'), findsOneWidget);
  });
}

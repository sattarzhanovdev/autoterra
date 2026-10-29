import 'dart:io';
import 'package:flutter/services.dart';
import 'package:autoterra/models/models.dart';
import 'package:autoterra/models/paginated.dart';
import 'package:autoterra/core/theme.dart';
import 'package:autoterra/screens/settings/text_size_screen.dart';
import 'package:autoterra/screens/referral/referral_screen.dart';
import 'package:autoterra/screens/orders/order_screen.dart';
import 'package:autoterra/services/text_size_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'referral_program_copy_test.dart' as referral;
import 'order_catalog_ux_test.dart' as catalog;

class PopulatedReferrals extends referral.ReferralCopyRepository {
  @override
  Future<(Paginated<Referral>, Map<String, dynamic>)> referrals({
    int page = 1,
    int pageSize = 20,
  }) async {
    final (_, stats) = await super.referrals(page: page, pageSize: pageSize);
    final rows = [
      Referral(
        id: '1',
        inviterId: '2',
        inviteeInn: '1234567890',
        inviteeName: 'Мастерская кузовного ремонта',
        region: 'Пермь',
        createdAt: DateTime(2026),
      ),
      Referral(
        id: '2',
        inviterId: '2',
        inviteeInn: '1234567891',
        inviteeName: 'Автосервис',
        region: 'Пермь',
        isRegistered: true,
        hasPurchase: true,
        purchaseAmount: 385000,
        bonusRate: 1.25,
        bonusEarned: 4812.5,
        createdAt: DateTime(2026),
      ),
    ];
    return (
      Paginated(items: rows, pageInfo: PageInfo.single(rows.length)),
      stats,
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'preference persists and invalid saved values use the default',
    () async {
      final settings = TextSizeSettings();
      await settings.load();
      expect(settings.index, 0);
      expect(settings.scaler(TextScaler.noScaling).scale(14), 16);
      await settings.select(2);
      final restored = TextSizeSettings();
      await restored.load();
      expect(restored.index, 2);
      expect(
        restored.scaler(TextScaler.noScaling).scale(14),
        closeTo(20.8, .001),
      );
      SharedPreferences.setMockInitialValues({TextSizeSettings.storageKey: 99});
      await restored.load();
      expect(restored.index, 0);
    },
  );

  test('system accessibility scale is retained with all font choices', () {
    const scaler = ReadableTextScaler(TextScaler.linear(2), 1.5);
    expect(scaler.scale(14), 48);
    expect(scaler.scale(0), 0);
  });

  Future<void> open(
    WidgetTester tester,
    Widget home,
    TextSizeSettings settings, {
    double system = 1,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (Platform.environment['AUTOTERRA_UX_SCREENSHOTS'] != null) {
      await tester.runAsync(() async {
        for (final font in {
          'TTNeoris': 'assets/fonts/TTNeoris-DemiBold.ttf',
          'TTOctosquares': 'assets/fonts/TTOctosquares-Medium.ttf',
          'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
        }.entries) {
          await (FontLoader(
            font.key,
          )..addFont(rootBundle.load(font.value))).load();
        }
      });
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(system)),
          child: AppTextSize(settings: settings, child: child!),
        ),
        home: RepaintBoundary(key: const ValueKey('screen'), child: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('size applies immediately to settings and survives recreation', (
    tester,
  ) async {
    final settings = TextSizeSettings();
    await open(tester, TextSizeScreen(settings: settings), settings);
    await tester.tap(find.byKey(const ValueKey('text-size-3')));
    await tester.pumpAndSettle();
    expect(settings.index, 3);
    await catalog.capture(tester, 'text-size-settings');
    final preview = tester.element(find.text('Пример текста'));
    expect(MediaQuery.textScalerOf(preview).scale(14), 24);
    final restored = TextSizeSettings();
    await restored.load();
    expect(restored.index, 3);
    expect(tester.takeException(), isNull);
  });

  for (final size in [0, 3]) {
    testWidgets('referral page readable without overflow at size $size', (
      tester,
    ) async {
      final settings = TextSizeSettings();
      await settings.select(size);
      await open(
        tester,
        ReferralScreen(repository: PopulatedReferrals()),
        settings,
      );
      expect(tester.takeException(), isNull);
      await catalog.capture(tester, 'referral-size-$size');
      for (var i = 0; i < 18; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -430));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('catalog and controls remain usable at size $size', (
      tester,
    ) async {
      final repo = catalog.CatalogRepository();
      final settings = TextSizeSettings();
      await settings.select(size);
      await open(tester, OrderScreen(repository: repo), settings);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('catalog-brand-filter')),
      );
      await tester.tap(find.byKey(const ValueKey('catalog-brand-filter')));
      await tester.pumpAndSettle();
      expect(find.text('Бренды каталога'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('AutoTerra').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('catalog-product-1')),
      );
      expect(tester.takeException(), isNull);
      await catalog.capture(tester, 'catalog-size-$size');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

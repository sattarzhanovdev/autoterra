import 'dart:convert';
import 'package:autoterra/services/api_client.dart';
import 'package:autoterra/services/app_update.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const channel = MethodChannel('autoterra/app-info');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => {'build': 22, 'store': 'google_play'},
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final latest in [21, 22, 23]) {
    testWidgets('update dialog for installed 22 / latest $latest', (
      tester,
    ) async {
      var requests = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          requests++;
          expect(request.url.queryParameters, {
            'store': 'google_play',
            'build': '22',
          });
          return http.Response(
            jsonEncode({
              'latestBuildNumber': latest,
              'minimumSupportedBuildNumber': 21,
              'store': 'google_play',
              'storeUrl': 'https://play.google.com/store/apps/details?id=test',
            }),
            200,
          );
        }),
      );
      final key = GlobalKey<NavigatorState>();
      Widget app() => MaterialApp(
        navigatorKey: key,
        home: const Scaffold(body: Text('Content')),
        builder: (_, child) =>
            AppUpdateGate(api: api, navigatorKey: key, child: child!),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(
        find.text('Доступно обновление'),
        latest > 22 ? findsOneWidget : findsNothing,
      );
      if (latest > 22) {
        await tester.tap(find.text('ПОЗЖЕ'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(find.text('Доступно обновление'), findsNothing);
        expect(requests, 1);
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

  testWidgets('mandatory update blocks content even after route change', (
    tester,
  ) async {
    final api = ApiClient(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'latestBuildNumber': 24,
            'minimumSupportedBuildNumber': 23,
            'store': 'google_play',
            'storeUrl': 'https://play.google.com/store/apps/details?id=test',
          }),
          200,
        ),
      ),
    );
    final key = GlobalKey<NavigatorState>();
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        home: Scaffold(
          body: TextButton(
            onPressed: () => taps++,
            child: const Text('Continue'),
          ),
        ),
        builder: (_, child) =>
            AppUpdateGate(api: api, navigatorKey: key, child: child!),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Необходимо обновление'), findsOneWidget);
    expect(find.text('ПОЗЖЕ'), findsNothing);
    await tester.tap(find.text('Continue'), warnIfMissed: false);
    expect(taps, 0);
    key.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Other route')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Необходимо обновление'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}

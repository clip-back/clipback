import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/notification_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'fixtures/notification_alignment_fixture.dart' as fixture;
import 'support/app_startup.dart';

Finder get _notification => find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == 'NotificationListScreen',
);
Future<void> _root(
  WidgetTester tester,
  Future<void> Function(fixture.NotificationServer server) body, {
  TargetPlatform platform = TargetPlatform.iOS,
  double width = 375,
  String kind = 'member',
}) async {
  final previous = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = platform;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 812);
  final top = platform == TargetPlatform.iOS ? 59.0 : 24.0,
      bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
  final server = fixture.NotificationServer(kind);
  addTearDown(server.client.close);
  await http.runWithClient(() async {
    try {
      await tester.pumpWidget(
        ClipbackApp(
          key: UniqueKey(),
          sessionStorage: fixture.NotificationMemoryStorage(),
          socialAuth: fixture.NotificationSocial(),
        ),
      );
      await completeAppStartup(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      final bell = find.descendant(
        of: find.byType(HomeHero),
        matching: find.byWidgetPredicate(
          (w) => w is SvgIconButton && w.asset == Assets.bell,
        ),
      );
      await tester.tap(bell);
      await tester.pumpAndSettle();
      await body(server);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = previous;
    }
  }, () => server.client);
}

void _expectOracle(WidgetTester tester) {
  final measure = fixture.notificationMeasure(tester.element(_notification)),
      judge = fixture.notificationJudgment(measure);
  for (final pair in {
    'stylePassed': 'styleFailures',
    'layoutPassed': 'layoutFailures',
    'assetPassed': 'assetFailures',
  }.entries) {
    expect(judge[pair.key], isTrue, reason: '${judge[pair.value]}');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await fixture.notificationLoadFonts(loadForTest: true);
  });
  setUp(() {
    var revision = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.huturu.app/share'), (
          call,
        ) async {
          switch (call.method) {
            case 'getState':
              return {
                'revision': revision,
                'drafts': <Object>[],
                'receipts': <Object>[],
              };
            case 'blockCredential':
              return ++revision;
            case 'publishCredential':
              return true;
            case 'presentDraft':
            case 'acknowledgeReceipts':
              return null;
            default:
              throw StateError(
                'Unexpected isolated share method ${call.method}',
              );
          }
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.huturu.app/share'),
          null,
        ),
  );
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      testWidgets(
        '${platform.name} $width C03 actual roles geometry source and three read-only notifications',
        (tester) async {
          for (final kind in ['member', 'guest']) {
            await _root(
              tester,
              (server) async {
                expect(_notification, findsOneWidget);
                expect(find.byType(NotificationSheet), findsNothing);
                // Fixed home/notification slots retain Home state in the root flow.
                _expectOracle(tester);
                final m = fixture.notificationMeasure(
                  tester.element(_notification),
                );
                expect(m['items'], [
                  for (final item in fixture.notificationExamples)
                    {'title': item.title, 'time': item.time},
                ]);
                final rows = m['rows'] as List;
                expect(rows.length, 3);
                for (final row in rows) {
                  expect(row['bounds']['height'], greaterThanOrEqualTo(76));
                }
                final requests = server.requests.length,
                    records = server.records.length;
                for (final item in fixture.notificationExamples) {
                  await tester.ensureVisible(find.text(item.title));
                  await tester.tap(find.text(item.title));
                  await tester.pumpAndSettle();
                  expect(_notification, findsOneWidget);
                }
                expect(server.requests.length, requests);
                expect(server.records.length, records);
                expect(server.writes, 0);
                expect(server.logoutCalls, 0);
                expect(tester.takeException(), isNull);
              },
              platform: platform,
              width: width,
              kind: kind,
            );
          }
        },
      );
    }
    testWidgets(
      '${platform.name} low C03 viewport exposes last row plus 24px and OS safety once',
      (tester) async {
        await _root(
          tester,
          (server) async {
            expect(_notification, findsOneWidget);
            tester.view.physicalSize = const Size(320, 360);
            await tester.pumpAndSettle();
            final p = fixture.notificationPosition(
              tester.element(_notification),
            )!;
            expect(p.maxScrollExtent, greaterThan(0));
            await tester.drag(
              find.byKey(const ValueKey('notification-viewport')),
              const Offset(0, -350),
            );
            await tester.pumpAndSettle();
            expect(p.pixels, closeTo(p.maxScrollExtent, .2));
            _expectOracle(tester);
            expect(
              find.text(fixture.notificationExamples.last.title).hitTestable(),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          },
          platform: platform,
          width: 320,
        );
      },
    );
  }
  test('C03 retains real bundled Pretendard declarations', () async {
    final fonts = await fixture.notificationLoadFonts();
    expect(fonts['available'], isTrue);
    expect(fonts['declared'], isTrue);
    expect(fonts['bytes'], greaterThan(1000));
  });
}

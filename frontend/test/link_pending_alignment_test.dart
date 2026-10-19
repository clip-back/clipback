import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'fixtures/link_pending_fixture.dart' as f;
import 'support/app_startup.dart';
import 'support/login_alignment_preview.dart' as login;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Pretendard');
    for (final w in ['Regular', 'Medium', 'SemiBold']) {
      font.addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
    }
    await font.load();
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 375.0]) {
      for (final height in [812.0, 520.0]) {
        testWidgets(
          '${platform.name} ${width}x$height D04 actual pending POST and saved input',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = Size(width, height);
            final top = platform == TargetPlatform.iOS ? 50.0 : 24.0,
                bottom = platform == TargetPlatform.iOS ? 34.0 : 0.0;
            tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
            tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
            debugDefaultTargetPlatformOverride = platform;
            final server = f.LinkPendingServer(),
                storage = login.LoginMemoryStorage()..value = f.pendingSession;
            try {
              await http.runWithClient(() async {
                await tester.pumpWidget(
                  ClipbackApp(
                    sessionStorage: storage,
                    socialAuth: login.LoginControlledSocial(platform),
                  ),
                );
                await completeAppStartup(tester);
                expect(find.byType(HomeScreen), findsOneWidget);
                await tester.tap(
                  find.byWidgetPredicate(
                    (w) => w.runtimeType.toString() == 'NavAddButton',
                  ),
                );
                await tester.pump();
                await tester.enterText(
                  find.byType(TextField),
                  '  ${f.pendingLink}  ',
                );
                await tester.pump(const Duration(milliseconds: 400));
                final stale = tester
                    .widget<SaveFlowButton>(find.byType(SaveFlowButton))
                    .onPressed;
                stale();
                await tester.pump(const Duration(milliseconds: 50));
                final root = tester.element(find.byType(ClipbackApp)),
                    m = f.linkPendingMeasure(root),
                    j = f.linkPendingJudgment(m);
                expect(
                  j['stylePassed'],
                  isTrue,
                  reason: '$m ${j['styleFailures']}',
                );
                expect(
                  j['layoutPassed'],
                  isTrue,
                  reason: '$m ${j['layoutFailures']}',
                );
                final target = tester.element(
                  find.byKey(const ValueKey('link-pending-skeleton')),
                );
                final scroll = target
                    .findAncestorStateOfType<ScrollableState>()!
                    .position;
                scroll.jumpTo(scroll.maxScrollExtent);
                await tester.pump();
                final end = f.linkPendingMeasure(root),
                    card = (end['category'] as Map)['bounds'] as Map,
                    viewport = end['viewport'] as Map;
                expect(
                  card['bottom'],
                  lessThanOrEqualTo((viewport['bottom'] as num) - 23.9),
                );
                if (scroll.maxScrollExtent > 0) {
                  expect(
                    (viewport['bottom'] as num) - (card['bottom'] as num),
                    closeTo(24, .15),
                  );
                }
                scroll.jumpTo(0);
                await tester.pump();
                expect(server.submissions, [f.pendingLink]);
                stale();
                await tester.pump();
                expect(server.submissions, [f.pendingLink]);
                await tester.tap(find.text('사진 첨부'));
                await tester.pump();
                expect(
                  find.byKey(const ValueKey('link-pending-skeleton')),
                  findsNothing,
                );
                expect(find.byType(PhotoSaveBody), findsOneWidget);
                await tester.tap(find.text('링크 첨부'));
                await tester.pump();
                expect(
                  find.byKey(const ValueKey('link-pending-skeleton')),
                  findsOneWidget,
                );
                await tester.enterText(
                  find.byType(TextField),
                  'https://example.com/edited',
                );
                await tester.pump(const Duration(milliseconds: 400));
                expect(
                  find.byKey(const ValueKey('link-pending-skeleton')),
                  findsNothing,
                );
                expect(
                  tester
                      .widget<SaveFlowButton>(find.byType(SaveFlowButton))
                      .loading,
                  isTrue,
                );
                server.resolve();
                await tester.pumpAndSettle();
                final result = tester.widget<SavedContentConfirmation>(
                  find.byType(SavedContentConfirmation),
                );
                expect(result.originalUrl, f.pendingLink);
                expect(server.submissions, [f.pendingLink]);
                expect(tester.takeException(), isNull);
                await tester.pumpWidget(const SizedBox.shrink());
                await tester.pump(const Duration(seconds: 1));
              }, () => server.controlledClient);
            } finally {
              server.resolve(success: false);
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump(const Duration(seconds: 1));
              server.close();
              tester.view.reset();
              debugDefaultTargetPlatformOverride = null;
            }
          },
        );
      }
    }
  }
}

import 'dart:async';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'fixtures/original_link_launcher.dart';
import 'support/app_startup.dart';
import 'support/archive_all_preview.dart' as isolated;
import 'support/original_link_preview.dart';

Future<void> _withDetail(
  WidgetTester tester,
  Future<void> Function(OriginalLinkPreviewServer, RecordingUrlLauncher)
  check, {
  String kind = 'link',
}) async {
  final server = OriginalLinkPreviewServer()..reset(kind);
  final old = UrlLauncherPlatform.instance, launcher = RecordingUrlLauncher();
  UrlLauncherPlatform.instance = launcher;
  addTearDown(() => UrlLauncherPlatform.instance = old);
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await http.runWithClient(() async {
    try {
      await tester.pumpWidget(
        ClipbackApp(
          sessionStorage: isolated.ArchiveAllMemoryStorage(),
          socialAuth: isolated.ArchiveAllSocialAuth(),
        ),
      );
      await completeAppStartup(tester);
      final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
      home.onOpenContent(home.contents.first);
      await tester.pumpAndSettle();
      await check(server, launcher);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      server.previewClient.close();
      server.client.close();
    }
  }, () => server.previewClient);
}

Finder get _original => find.byKey(const ValueKey('detail-original-button'));
Iterable<Map<String, dynamic>> _events(OriginalLinkPreviewServer s) =>
    s.metrics.where((e) => e['event_type'] == 'original_link_opened');

void main() {
  testWidgets(
    'actual root opens external URL once, keeps expanded detail and ignores old callbacks',
    (tester) async {
      await _withDetail(tester, (server, launcher) async {
        launcher.pending = Completer<bool>();
        await tester.tap(find.text('전문 보기'));
        await tester.pumpAndSettle();
        final detail = tester.widget<DetailScreen>(find.byType(DetailScreen));
        await tester.tap(_original);
        await tester.pump();
        await tester.tap(_original);
        await tester.pump();
        expect(launcher.calls, hasLength(1));
        expect(_events(server), isEmpty);
        expect(launcher.calls.single.url, originalPreviewUrl);
        expect(find.byType(OriginalContentSheet), findsNothing);
        launcher.pending!.complete(true);
        await tester.pumpAndSettle();
        expect(_events(server).single['content_id'], 601);
        expect(
          find.byKey(const ValueKey('detail-original-text')),
          findsOneWidget,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(find.byType(DetailScreen), findsOneWidget);
        expect(
          find.byKey(const ValueKey('detail-original-text')),
          findsOneWidget,
        );
        detail.onBack();
        await tester.pumpAndSettle();
        detail.onOpenOriginalLink();
        await tester.pumpAndSettle();
        expect(launcher.calls, hasLength(1));
        expect(_events(server), hasLength(1));
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'actual root shows existing error feedback and manually retries',
    (tester) async {
      await _withDetail(tester, (server, launcher) async {
        launcher.accepted = false;
        await tester.tap(_original);
        await tester.pumpAndSettle();
        expect(find.text('원본 링크를 열지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
        expect(find.byType(DetailScreen), findsOneWidget);
        expect(_events(server), isEmpty);
        launcher.accepted = true;
        await tester.tap(_original);
        await tester.pumpAndSettle();
        expect(launcher.calls, hasLength(2));
        expect(_events(server), hasLength(1));
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'photo original keeps its authenticated image sheet without URL or link metric',
    (tester) async {
      await _withDetail(tester, (server, launcher) async {
        await tester.tap(_original);
        await tester.pumpAndSettle();
        expect(find.byType(OriginalContentSheet), findsOneWidget);
        expect(find.text('원본 이미지'), findsOneWidget);
        expect(launcher.calls, isEmpty);
        expect(_events(server), isEmpty);
        Navigator.of(tester.element(find.byType(OriginalContentSheet))).pop();
        await tester.pumpAndSettle();
        expect(find.byType(DetailScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, kind: 'photo');
    },
  );
}

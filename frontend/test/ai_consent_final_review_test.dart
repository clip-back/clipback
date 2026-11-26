// #474 final review: the first share prompt after the consent screen and
// the '자세히 보기' lock, in the order things happen on a device.
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/data/services/native_share_service.dart';
import 'package:clipback_frontend/features/auth/ai_consent_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/features/share/pending_share_prompt.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_startup.dart';

http.Response _json(Object? value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _Social extends SocialAuth {
  @override
  List<SocialLoginProvider> get supportedProviders =>
      SocialLoginProvider.values;
  @override
  Future<SocialCredential?> authenticate(
    SocialLoginProvider provider, {
    String? nonce,
  }) async => null;
  @override
  Future<void> signOut([SocialLoginProvider? provider]) async {}
  @override
  Future<void> rememberAppleUserId(String? id) async {}
  @override
  Future<AppleCredentialStatus> appleCredentialState() async =>
      AppleCredentialStatus.authorized;
}

/// One stored account (id 1, undecided) and an empty feed.
class _Server {
  final puts = <Object?>[];
  Future<http.Response> Function()? putRespond;
  late final client = MockClient((request) async {
    switch (request.url.path) {
      case '/api/v1/users/me':
        return _json({
          'id': 1,
          'email': null,
          'display_name': '사용자 1',
          'is_guest': false,
          'created_at': '2026-10-10T00:00:00Z',
          'linked_providers': ['google'],
          'ai_consent_status': 'undecided',
        });
      case '/api/v1/users/me/ai-consent':
        puts.add(jsonDecode(request.body));
        return putRespond?.call() ??
            _json({
              'status': 'granted',
              'notice_version': 1,
              'decided_at': '2026-11-26T03:00:00Z',
            });
      case '/api/v1/users/me/stats':
        return _json({
          'saved_count': 0,
          'reopened_count': 0,
          'recent_reopened_count': 0,
        });
      case '/api/v1/categories':
        return _json(<Object>[]);
      case '/api/v1/feed':
        return _json({
          'items': <Object>[],
          'next_cursor': null,
          'total_count': 0,
        });
      case '/api/v1/recommendations/weekly':
        return _json({
          'period_start': '2026-10-19T00:00:00Z',
          'period_end': '2026-10-26T00:00:00Z',
          'batch_id': null,
          'generated_at': null,
          'items': <Object>[],
        });
      case '/api/v1/auth/share-credential':
        return _json({
          'share_token': 'fixture-share',
          'expires_at': '2030-10-18T00:00:00Z',
          'user_id': 1,
          'session_id': 1,
        });
      case '/api/v1/metrics/events':
        return _json(<String, Object>{}, 201);
    }
    throw StateError('Unexpected ${request.method} ${request.url.path}');
  });
}

Future<void> _app(
  WidgetTester tester,
  _Server server,
  Future<void> Function() check, {
  NativeShareService? nativeShare,
}) async {
  SharedPreferences.setMockInitialValues({
    'clipback.session': jsonEncode({
      'access_token': 'stored-access',
      'refresh_token': 'stored-refresh',
      'expires_in': 3600,
      'refresh_expires_in': 86400,
    }),
  });
  tester.view.physicalSize = const Size(428, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(server.client.close);
  await http.runWithClient(() async {
    try {
      await tester.pumpWidget(
        ClipbackApp(socialAuth: _Social(), nativeShare: nativeShare),
      );
      await completeAppStartup(tester);
      await check();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  }, () => server.client);
}

final _consent = find.byType(AiConsentScreen);
final _home = find.byType(HomeScreen);
final _agree = find.byKey(const ValueKey('ai-consent-agree'));
final _close = find.byKey(const ValueKey('ai-consent-close'));
final _detailLink = find.byKey(const ValueKey('ai-consent-detail-link'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('first share prompt after consent', () {
    const channel = MethodChannel('com.huturu.app/share');
    late Completer<void> ack;
    late bool holdAck;
    setUp(() {
      ack = Completer<void>();
      holdAck = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'getState':
                return {
                  'revision': 3,
                  'drafts': [
                    {'id': 'mine', 'label': '내 공유', 'userId': 1},
                    {'id': 'other', 'label': '다른 계정 공유', 'userId': 9},
                    {'id': 'unbound', 'label': '계정 없는 공유'},
                  ],
                  'receipts': [
                    {'id': 'r', 'userId': 1},
                  ],
                };
              case 'publishCredential':
                return true;
              case 'blockCredential':
                return 4;
              case 'acknowledgeReceipts':
                if (holdAck) await ack.future;
                return null;
            }
            return null;
          });
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    List<String> shown(WidgetTester tester) => tester
        .widget<PendingSharePrompt>(find.byType(PendingSharePrompt))
        .drafts
        .map((draft) => draft.id)
        .toList();

    for (final held in [false, true]) {
      testWidgets('closing with receipts ${held ? 'still' : 'not'} being '
          'acknowledged shows only this account, later reads as usual', (
        tester,
      ) async {
        holdAck = held;
        await _app(tester, _Server(), () async {
          expect(_consent, findsOneWidget);
          expect(shown(tester), isEmpty);
          await tester.tap(_close);
          await tester.pumpAndSettle();
          expect(shown(tester), ['mine'], reason: 'first prompt');
          if (held) {
            ack.complete();
            // The held platform reply resolves outside the fake clock.
            await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          }
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<PendingSharePrompt>(find.byType(PendingSharePrompt))
                .busy,
            isFalse,
            reason: 'receipts acknowledged',
          );
          expect(shown(tester), ['mine'], reason: 'after acknowledging');
          await tester.tap(find.text('확인'));
          await tester.pumpAndSettle();
          expect(find.text('계정 없는 공유'), findsNothing);
          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();
          // The next usual return re-reads: drafts without an account show.
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump();
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pumpAndSettle();
          expect(shown(tester), ['mine', 'unbound'], reason: 'next read');
        }, nativeShare: NativeShareService(enabled: true));
      });
    }
  });

  group("'자세히 보기' while saving", () {
    for (final nextFrame in [false, true]) {
      testWidgets('a tap ${nextFrame ? 'a frame' : 'in the same frame'} '
          'after saving starts opens nothing', (tester) async {
        final put = Completer<http.Response>();
        final server = _Server()..putRespond = () => put.future;
        await _app(tester, server, () async {
          await tester.ensureVisible(_detailLink);
          await tester.pumpAndSettle();
          await tester.tap(_agree);
          await tester.idle();
          if (nextFrame) await tester.pump();
          expect(server.puts, hasLength(1));
          await tester.tap(_detailLink);
          await tester.pumpAndSettle();
          expect(find.byType(AiConsentDetailScreen), findsNothing);
          put.complete(
            _json({
              'status': 'granted',
              'notice_version': 1,
              'decided_at': '2026-11-26T03:00:00Z',
            }),
          );
          await tester.pumpAndSettle();
          expect(_home, findsOneWidget);
          expect(find.byType(AiConsentDetailScreen), findsNothing);
        });
      });
    }

    testWidgets('the locked link offers no tap to accessibility', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        final put = Completer<http.Response>();
        final server = _Server()..putRespond = () => put.future;
        await _app(tester, server, () async {
          await tester.ensureVisible(_detailLink);
          await tester.pumpAndSettle();
          bool tappable() => tester
              .getSemantics(find.text('자세히 보기'))
              .getSemanticsData()
              .hasAction(ui.SemanticsAction.tap);
          expect(tappable(), isTrue, reason: 'before saving');
          await tester.tap(_agree);
          await tester.pump();
          expect(tappable(), isFalse, reason: 'while saving');
          put.complete(_json({'detail': 'no'}, 500));
          await tester.pumpAndSettle();
          expect(tappable(), isTrue, reason: 'after a failed save');
        });
      } finally {
        semantics.dispose();
      }
    });
  });
}

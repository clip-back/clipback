import '../support/asset_access_fixture.dart';

import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/actions/content_actions.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/data/services/original_link_opener.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:clipback_frontend/data/repositories/session_repository.dart';
import 'package:clipback_frontend/data/repositories/user_repository.dart';
import 'package:clipback_frontend/features/content/view_models/detail_view_model.dart';
import 'package:clipback_frontend/features/home/view_models/home_view_model.dart';
import 'package:clipback_frontend/shared/contracts/ui_effect.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _category = {
  'id': 2,
  'name': '보관 분류',
  'color': '#059669',
  'is_default': false,
  'content_count': 0,
  'last_saved_at': null,
};

Map<String, Object?> _content({
  int id = 7,
  String title = '저장한 제목',
  bool favorite = false,
}) => {
  'id': id,
  'categories': [_category],
  'tags': [
    {'name': '보존할 태그'},
  ],
  'assets': <Object>[],
  'content_type': 'link',
  'source': 'web',
  'title': title,
  'summary': '보존할 요약',
  'original_url': 'https://example.com/$id',
  'is_favorite': favorite,
  'saved_at': '2026-10-12T00:00:00Z',
  'last_viewed_at': null,
  'summary_status': 'processing',
};

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response _feed(List<Map<String, Object?>> items, {String? cursor}) =>
    _json({'items': items, 'next_cursor': cursor});

class _Social extends SocialAuth {
  @override
  List<SocialLoginProvider> get supportedProviders => const [];
  @override
  Future<SocialCredential?> authenticate(
    SocialLoginProvider provider, {
    String? nonce,
  }) async => null;
  @override
  Future<void> signOut([SocialLoginProvider? provider]) async {}
  @override
  Future<void> rememberAppleUserId(String? userId) async {}
  @override
  Future<AppleCredentialStatus> appleCredentialState() async =>
      AppleCredentialStatus.unavailable;
}

class _Fixture {
  _Fixture(this.respond, {OriginalLinkOpener? originalLinkOpener}) {
    client = MockClient((request) async {
      requests.add(request);
      final custom = respond(request);
      if (custom != null) return custom;
      switch (request.url.path) {
        case '/api/v1/categories':
          return _json([_category]);
        case '/api/v1/users/me':
          return _json({
            'id': 1,
            'email': null,
            'display_name': '사용자',
            'is_guest': true,
            'created_at': '2026-10-01T00:00:00Z',
            'linked_providers': <String>[],
          });
        case '/api/v1/users/me/stats':
          return _json({'saved_count': 42, 'reopened_count': 17});
        case '/api/v1/metrics/events':
          return _json({});
      }
      if (request.url.path == '/api/v1/uploads/assets/3/access') {
        return originalAccessFixture(3, [1, 2, 3]);
      }
      if (request.url.path.endsWith('/view')) return _json({});
      throw StateError('Unexpected ${request.method} ${request.url.path}');
    });
    api = ClipbackApi(client: client)
      ..restoreSession(
        const ApiSession(
          accessToken: 'test-access',
          refreshToken: 'test-refresh',
          expiresIn: 3600,
          refreshExpiresIn: 86400,
        ),
      );
    repository = RemoteContentRepository(api);
    users = RemoteUserRepository(api: api);
    session = RemoteSessionRepository(
      api: api,
      storage: ApiSessionStorage(),
      socialAuth: _Social(),
    );
    actions = ContentActions(repository, users, session);
    home = HomeViewModel(repository, actions);
    detail = DetailViewModel(
      repository,
      actions,
      originalLinkOpener: originalLinkOpener,
    );
    addTearDown(dispose);
  }

  final FutureOr<http.Response>? Function(http.Request) respond;
  final requests = <http.Request>[];
  late final MockClient client;
  late final ClipbackApi api;
  late final RemoteContentRepository repository;
  late final RemoteUserRepository users;
  late final RemoteSessionRepository session;
  late final ContentActions actions;
  late final HomeViewModel home;
  late final DetailViewModel detail;

  Future<void> load() async {
    await repository.loadCategories();
    await home.loadMore();
  }

  void open({bool recordView = false}) => detail.open(
    home.page.items.first,
    source: FeedKey.home,
    sourcePage: home.page,
    recordView: recordView,
  );

  void dispose() {
    actions.dispose();
    if (!home.isDisposed) home.dispose();
    if (!detail.isDisposed) detail.dispose();
    repository.dispose();
    users.dispose();
    session.dispose();
    client.close();
  }
}

Future<void> _until(bool Function() ready) async {
  for (var attempt = 0; attempt < 30 && !ready(); attempt++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(ready(), isTrue, reason: 'The controlled response must be applied');
}

void main() {
  _originalLinkTests();
  test(
    'home preserves feed and scroll while sharing an additional request',
    () async {
      final next = Completer<http.Response>();
      final nextStarted = Completer<void>();
      final fixture = _Fixture((request) {
        if (request.url.path != '/api/v1/feed') return null;
        if (request.url.queryParameters['cursor'] == 'next') {
          nextStarted.complete();
          return next.future;
        }
        if (request.url.queryParameters['category_id'] != null) {
          return _feed([_content(id: 9)]);
        }
        return _feed([_content()], cursor: 'next');
      });
      final page = fixture.home.page;
      await fixture.load();
      page.scrollOffset = 240;

      final first = fixture.home.loadMore();
      final second = fixture.home.loadMore();
      expect(second, same(first));
      await nextStarted.future;
      next.complete(_feed([_content(id: 8)]));
      await first;

      expect(fixture.home.page, same(page));
      expect(page.items.map((item) => item.apiId), [7, 8]);
      expect(page.scrollOffset, 240);
      await fixture.home.selectCategory(fixture.home.categories.single);
      expect(fixture.home.page, same(page));
      expect(page.scrollOffset, 0);
      expect(page.categoryId, 2);
      expect(page.items.single.apiId, 9);
    },
  );

  test(
    'home category change rejects a late page from the previous filter',
    () async {
      final next = Completer<http.Response>();
      final started = Completer<void>();
      final fixture = _Fixture((request) {
        if (request.url.path != '/api/v1/feed') return null;
        if (request.url.queryParameters['cursor'] == 'old-next') {
          started.complete();
          return next.future;
        }
        if (request.url.queryParameters['category_id'] == '2') {
          return _feed([_content(id: 9)], cursor: 'filtered-next');
        }
        return _feed([_content()], cursor: 'old-next');
      });
      await fixture.load();
      final oldPage = fixture.home.loadMore();
      await started.future;
      await fixture.home.selectCategory(fixture.home.categories.single);
      next.complete(_feed([_content(id: 8)], cursor: 'wrong-next'));
      await oldPage;

      expect(fixture.home.page.items.map((item) => item.apiId), [9]);
      expect(fixture.home.page.nextCursor, 'filtered-next');
      expect(fixture.home.page.categoryId, 2);
    },
  );

  test('reopening the same detail rejects the previous open request', () async {
    final reads = <Completer<http.Response>>[];
    final fixture = _Fixture((request) {
      if (request.url.path == '/api/v1/feed') return _feed([_content()]);
      if (request.url.path == '/api/v1/contents/7') {
        final response = Completer<http.Response>();
        reads.add(response);
        return response.future;
      }
      return null;
    });
    await fixture.load();
    fixture.open(recordView: true);
    await _until(() => reads.length == 1);
    fixture.detail.close();
    fixture.open(recordView: true);
    await _until(() => reads.length == 2);
    reads.last.complete(_json(_content(title: '새 상세 응답')));
    await _until(() => fixture.detail.content?.title == '새 상세 응답');
    reads.first.complete(_json(_content(title: '이전 상세 응답')));
    await Future<void>.delayed(Duration.zero);

    expect(fixture.detail.content?.title, '새 상세 응답');
    expect(fixture.home.page.items.single.title, '새 상세 응답');
    expect(
      fixture.requests.where((request) => request.url.path.endsWith('/view')),
      hasLength(2),
    );
    expect(
      fixture.requests.where(
        (request) => request.url.path.endsWith('/metrics/events'),
      ),
      hasLength(2),
    );
  });

  test('detail boundary navigation joins the home scrolling request', () async {
    final next = Completer<http.Response>();
    final started = Completer<void>();
    var nextCalls = 0;
    final fixture = _Fixture((request) {
      if (request.url.path == '/api/v1/feed') {
        if (request.url.queryParameters['cursor'] == 'next') {
          nextCalls++;
          started.complete();
          return next.future;
        }
        return _feed([_content()], cursor: 'next');
      }
      if (request.url.path == '/api/v1/contents/8') {
        return _json(_content(id: 8));
      }
      return null;
    });
    await fixture.load();
    fixture.open();
    final scrolling = fixture.home.loadMore();
    await started.future;
    final moving = fixture.detail.move(1);
    expect(fixture.detail.moving, isTrue);
    next.complete(_feed([_content(id: 8)]));
    await Future.wait([scrolling, moving]);

    expect(nextCalls, 1);
    expect(fixture.detail.content?.apiId, 8);
    expect(fixture.detail.moving, isFalse);
    expect(fixture.detail.feed, same(fixture.home.page));
  });

  test('failed bookmark restores only that field in home and detail', () async {
    final write = Completer<http.Response>();
    final started = Completer<void>();
    final fixture = _Fixture((request) {
      if (request.url.path == '/api/v1/feed') return _feed([_content()]);
      if (request.url.path == '/api/v1/contents/7/favorite') {
        started.complete();
        return write.future;
      }
      if (request.url.path == '/api/v1/contents/7') {
        return _json(_content(title: '서버가 갱신한 제목'));
      }
      return null;
    });
    await fixture.load();
    fixture.open();
    final mutation = fixture.detail.toggleBookmark(fixture.detail.content!);
    await started.future;
    expect(fixture.home.page.items.single.bookmarked, isTrue);
    expect(fixture.detail.content?.bookmarked, isTrue);
    expect(fixture.home.page.items.single.mutationLabel, '변경 중…');
    await fixture.repository.refreshDetail(
      fixture.repository.currentDetailHandle!,
    );
    write.complete(_json({'detail': '저장 실패'}, 503));
    await mutation;

    for (final item in [
      fixture.home.page.items.single,
      fixture.detail.content!,
    ]) {
      expect(item.bookmarked, isFalse);
      expect(item.title, '서버가 갱신한 제목');
      expect(item.summary, '보존할 요약');
      expect(item.summaryStatus, 'processing');
      expect(item.mutationLabel, isNull);
    }
    expect(fixture.home.bookmarkedIds, isEmpty);
    expect(
      fixture.detail.drainEffects().whereType<MessageEffect>(),
      hasLength(1),
    );
    expect(fixture.detail.drainEffects(), isEmpty);
  });

  test(
    'successful bookmark stays locked until follow-up statistics complete',
    () async {
      final stats = Completer<http.Response>();
      final statsStarted = Completer<void>();
      var favorite = false;
      var writes = 0;
      final fixture = _Fixture((request) {
        if (request.url.path == '/api/v1/feed') {
          return _feed([_content(favorite: favorite)]);
        }
        if (request.url.path == '/api/v1/contents/7/favorite') {
          writes++;
          favorite = (jsonDecode(request.body) as Map)['is_favorite'] as bool;
          return _json(_content(favorite: favorite));
        }
        if (request.url.path == '/api/v1/users/me/stats' &&
            !stats.isCompleted) {
          statsStarted.complete();
          return stats.future;
        }
        return null;
      });
      await fixture.load();
      fixture.open();
      final mutation = fixture.detail.toggleBookmark(fixture.detail.content!);
      await statsStarted.future;
      expect(fixture.home.page.items.single.bookmarked, isTrue);
      expect(fixture.detail.content?.bookmarked, isTrue);
      expect(fixture.detail.content?.mutationLabel, '변경 중…');
      await fixture.detail.toggleBookmark(fixture.detail.content!);
      expect(writes, 1);
      stats.complete(_json({'saved_count': 42, 'reopened_count': 17}));
      await mutation;

      expect(fixture.home.page.items.single.mutationLabel, isNull);
      expect(fixture.detail.content?.mutationLabel, isNull);
      expect(fixture.users.stats?.savedCount, 42);
      await fixture.detail.toggleBookmark(fixture.detail.content!);
      expect(writes, 2);
      expect(fixture.home.page.items.single.bookmarked, isFalse);
      expect(fixture.detail.content?.bookmarked, isFalse);
    },
  );

  test(
    'disposed view models ignore late mutation failure notifications and effects',
    () async {
      final write = Completer<http.Response>();
      final started = Completer<void>();
      final fixture = _Fixture((request) {
        if (request.url.path == '/api/v1/feed') return _feed([_content()]);
        if (request.url.path == '/api/v1/contents/7/favorite') {
          started.complete();
          return write.future;
        }
        return null;
      });
      await fixture.load();
      fixture.open();
      var notifications = 0;
      fixture.home.addListener(() => notifications++);
      fixture.detail.addListener(() => notifications++);
      final mutation = fixture.detail.toggleBookmark(fixture.detail.content!);
      await started.future;
      fixture.home.dispose();
      fixture.detail.dispose();
      final atDisposal = notifications;
      write.complete(_json({'detail': '늦은 오류'}, 503));
      await mutation;

      expect(notifications, atDisposal);
      expect(fixture.home.drainEffects(), isEmpty);
      expect(fixture.detail.drainEffects(), isEmpty);
    },
  );

  test(
    'detail close and same-content reopen rejects previous asset bytes',
    () async {
      final asset = Completer<http.Response>();
      final started = Completer<void>();
      final fixture = _Fixture((request) {
        if (request.url.path == '/api/v1/feed') return _feed([_content()]);
        if (request.url.path == '/api/v1/uploads/assets/3') {
          started.complete();
          return asset.future;
        }
        return null;
      });
      await fixture.load();
      fixture.open();
      final bytes = fixture.detail.readAsset(3);
      final rejected = expectLater(bytes, throwsA(isA<ClipbackApiException>()));
      await started.future;
      fixture.detail.close();
      fixture.open();
      asset.complete(http.Response.bytes([1, 2, 3], 200));
      await rejected;

      expect(fixture.detail.content?.apiId, 7);
      expect(fixture.detail.drainEffects(), isEmpty);
    },
  );

  test(
    'disposing actions during metadata refresh prevents later statistics',
    () async {
      final metadata = Completer<http.Response>();
      final started = Completer<void>();
      var holdMetadata = false;
      final fixture = _Fixture((request) {
        if (request.url.path == '/api/v1/feed') return _feed([_content()]);
        if (holdMetadata && request.url.path == '/api/v1/categories') {
          started.complete();
          return metadata.future;
        }
        return null;
      });
      await fixture.load();
      holdMetadata = true;
      final effects = <UiEffect>[];
      final refresh = fixture.actions.refresh(effects.add);
      await started.future;
      fixture.actions.dispose();
      metadata.complete(_json([_category]));
      await refresh;

      expect(effects, isEmpty);
      expect(
        fixture.requests.where(
          (request) => request.url.path.startsWith('/api/v1/users/me'),
        ),
        isEmpty,
      );
    },
  );

  test(
    'disposing actions during save suppresses insertion and saved callback',
    () async {
      final saved = Completer<http.Response>();
      final started = Completer<void>();
      final fixture = _Fixture((request) {
        if (request.url.path == '/api/v1/feed') return _feed([_content()]);
        if (request.url.path == '/api/v1/contents' &&
            request.method == 'POST') {
          started.complete();
          return saved.future;
        }
        return null;
      });
      await fixture.load();
      final effects = <UiEffect>[];
      final callbacks = <ApiContent>[];
      final result = fixture.actions.saveLink(
        url: 'https://example.com/new',
        onSaved: callbacks.add,
        feedback: effects.add,
      );
      await started.future;
      final requestCount = fixture.requests.length;
      fixture.actions.dispose();
      saved.complete(_json(_content(id: 9)));
      await result;

      expect(callbacks, isEmpty);
      expect(effects, isEmpty);
      expect(fixture.home.page.items.map((item) => item.apiId), [7]);
      expect(fixture.requests.length, requestCount);
    },
  );
}

class _ControlledOriginalOpener implements OriginalLinkOpener {
  final urls = <Uri>[];
  final responses = <Completer<bool>>[];
  @override
  Future<bool> open(Uri uri) {
    urls.add(uri);
    final pending = Completer<bool>();
    responses.add(pending);
    return pending.future;
  }
}

List<Map<String, dynamic>> _originalEvents(_Fixture f) => f.requests
    .where((r) => r.url.path == '/api/v1/metrics/events')
    .map((r) => Map<String, dynamic>.from(jsonDecode(r.body) as Map))
    .where((m) => m['event_type'] == 'original_link_opened')
    .toList();

void _originalLinkTests() {
  _Fixture fixture(
    _ControlledOriginalOpener opener, {
    String? url,
    bool photo = false,
    bool failMetrics = false,
  }) => _Fixture((r) {
    if (r.url.path == '/api/v1/feed') {
      return _feed([
        {
          ..._content(),
          if (url != null) 'original_url': url,
          if (photo) 'content_type': 'screenshot',
        },
        _content(id: 8),
      ]);
    }
    if (r.url.path == '/api/v1/metrics/events' && failMetrics) {
      return _json({'detail': 'metric failed'}, 503);
    }
    return null;
  }, originalLinkOpener: opener);

  test(
    'original opening preserves URL, coalesces taps and records each accepted launch once',
    () async {
      final opener = _ControlledOriginalOpener();
      final f = fixture(
        opener,
        url: '  https://example.com/path?a=a%20b&other=%2F#section  ',
      );
      await f.load();
      f.open();
      final action = f.detail.originalLinkAction();
      action();
      action();
      expect(opener.urls.map((u) => u.toString()), [
        'https://example.com/path?a=a%20b&other=%2F#section',
      ]);
      expect(_originalEvents(f), isEmpty);
      opener.responses[0].complete(true);
      await _until(() => _originalEvents(f).length == 1);
      expect(_originalEvents(f).single['content_id'], 7);
      expect(f.detail.drainEffects(), isEmpty);
      action();
      expect(opener.urls, hasLength(2));
      opener.responses[1].complete(true);
      await _until(() => _originalEvents(f).length == 2);
    },
  );

  for (final failure in ['false', 'exception']) {
    test(
      'original $failure keeps detail and allows manual retry without false metric',
      () async {
        final opener = _ControlledOriginalOpener();
        final current = fixture(opener);
        await current.load();
        current.open();
        final action = current.detail.originalLinkAction();
        action();
        if (failure == 'false') {
          opener.responses.single.complete(false);
        } else {
          opener.responses.single.completeError(
            StateError('private SDK detail'),
          );
        }
        await Future<void>.delayed(Duration.zero);
        final effects = current.detail
            .drainEffects()
            .whereType<MessageEffect>()
            .toList();
        expect(effects.single.message, '원본 링크를 열지 못했어요. 다시 시도해 주세요.');
        expect(current.detail.content?.apiId, 7);
        expect(_originalEvents(current), isEmpty);
        action();
        expect(opener.urls, hasLength(2));
        opener.responses.last.complete(true);
        await _until(() => _originalEvents(current).length == 1);
      },
    );
  }

  for (final url in [
    '',
    '   ',
    'example.com/path',
    '//example.com',
    'https://',
    'http:///path',
    'javascript:alert(1)',
    'file:///tmp/image',
    'mailto:a@example.com',
    'intent://example.com',
    'https://[invalid',
  ]) {
    test('invalid original URL is rejected before OS launch: $url', () async {
      final opener = _ControlledOriginalOpener();
      final current = fixture(opener, url: url);
      await current.load();
      current.open();
      current.detail.originalLinkAction()();
      await Future<void>.delayed(Duration.zero);
      expect(opener.urls, isEmpty);
      expect(_originalEvents(current), isEmpty);
      expect(
        current.detail.drainEffects().whereType<MessageEffect>().single.message,
        '원본 링크를 열지 못했어요. 다시 시도해 주세요.',
      );
    });
  }

  for (final change in ['close', 'reopen', 'move', 'account', 'dispose']) {
    for (final outcome in ['success', 'failure']) {
      test(
        'late original $outcome after $change cannot affect a new owner',
        () async {
          final opener = _ControlledOriginalOpener();
          final current = fixture(opener);
          await current.load();
          current.open();
          final stale = current.detail.originalLinkAction();
          stale();
          switch (change) {
            case 'close':
              current.detail.close();
            case 'reopen':
              current.detail.close();
              current.open();
            case 'move':
              current.detail.open(
                current.home.page.items.last,
                source: FeedKey.home,
                sourcePage: current.home.page,
                recordView: false,
              );
            case 'account':
              current.repository.resetAccount(1);
            case 'dispose':
              current.detail.dispose();
          }
          current.detail.drainEffects();
          stale();
          expect(opener.urls, hasLength(1));
          opener.responses.single.complete(outcome == 'success');
          await Future<void>.delayed(Duration.zero);
          expect(_originalEvents(current), isEmpty);
          expect(current.detail.drainEffects(), isEmpty);
        },
      );
    }
  }

  test(
    'photo original never launches a URL or records a link metric',
    () async {
      final opener = _ControlledOriginalOpener(),
          f = fixture(opener, photo: true);
      await f.load();
      f.open();
      f.detail.originalLinkAction()();
      await Future<void>.delayed(Duration.zero);
      expect(opener.urls, isEmpty);
      expect(_originalEvents(f), isEmpty);
      expect(f.detail.drainEffects(), isEmpty);
    },
  );

  test(
    'metric failure does not reopen URL or turn launch success into an error',
    () async {
      final opener = _ControlledOriginalOpener(),
          f = fixture(opener, failMetrics: true);
      await f.load();
      f.open();
      f.detail.originalLinkAction()();
      opener.responses.single.complete(true);
      await _until(() => _originalEvents(f).length == 1);
      await Future<void>.delayed(Duration.zero);
      expect(opener.urls, hasLength(1));
      expect(f.detail.drainEffects(), isEmpty);
    },
  );

  test(
    'old launch completion cannot unlock or record a different pending detail',
    () async {
      final opener = _ControlledOriginalOpener(), f = fixture(opener);
      await f.load();
      f.open();
      f.detail.originalLinkAction()();
      f.detail.open(
        f.home.page.items.last,
        source: FeedKey.home,
        sourcePage: f.home.page,
        recordView: false,
      );
      final next = f.detail.originalLinkAction();
      next();
      opener.responses.first.complete(false);
      await Future<void>.delayed(Duration.zero);
      next();
      expect(opener.urls, hasLength(2));
      expect(f.detail.drainEffects(), isEmpty);
      opener.responses.last.complete(true);
      await _until(() => _originalEvents(f).isNotEmpty);
      expect(_originalEvents(f).single['content_id'], 8);
    },
  );
}

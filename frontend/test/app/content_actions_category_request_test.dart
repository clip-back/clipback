// 카테고리 요청 4곳(생성 저장, 수정 저장, 목록 재조회, 수정 저장 뒤 피드 갱신)의
// 현재 동작을 고정한다. 행 번호(S·R·F)는 이슈 #276 "바뀌지 않는 것" 표를 따른다.
// 이 파일은 #282에서 동결했다. 이후 수정은 허용하지 않는다.
import 'dart:async';
import 'dart:convert';

import 'package:clipback_frontend/app/actions/content_actions.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:clipback_frontend/data/repositories/session_repository.dart';
import 'package:clipback_frontend/data/repositories/user_repository.dart';
import 'package:clipback_frontend/data/services/api_request_scope.dart';
import 'package:clipback_frontend/shared/contracts/category_submission.dart';
import 'package:clipback_frontend/shared/contracts/ui_effect.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _category = ApiCategory(
  id: 7,
  name: 'n',
  color: '#000000',
  isDefault: false,
);
const _afterSaveNotice = '저장은 완료됐지만 카테고리 목록을 새로 불러오지 못했어요 | 다시 불러오기 | retry';
const _readNotice = '최신 정보를 불러오지 못했어요. | 다시 불러오기 | retry';
const _feedResult = RefreshResult(
  current: false,
  metadataFailed: false,
  categoryDetailsRequired: false,
);

/// Test double whose responses, errors and silence the test decides.
class _Content extends ContentRepository {
  int generation = 0;
  int refreshGeneration = 0;
  final log = <String>[];
  Completer<ApiCategory?>? submit;
  ApiRequestScope? submitScope;
  final reads = <Completer<CategoryServerSnapshot>>[];
  final readScopes = <ApiRequestScope?>[];
  final refreshes = <Completer<RefreshResult>>[];
  final refreshScopes = <ApiRequestScope?>[];

  @override
  int get accountVersion => generation;

  @override
  Future<ApiCategory?> createCategory({
    required String name,
    String? color,
    String? submissionKey,
  }) {
    log.add('create($name,$color,$submissionKey)');
    submitScope = ApiRequestScope.current;
    return (submit = Completer()).future;
  }

  @override
  Future<ApiCategory?> updateCategorySubmission({
    required int categoryId,
    required String name,
    required String color,
    required String submissionKey,
  }) {
    log.add('update($categoryId,$name,$color,$submissionKey)');
    submitScope = ApiRequestScope.current;
    return (submit = Completer()).future;
  }

  @override
  Future<CategoryServerSnapshot> readCurrentCategories() {
    log.add('read');
    readScopes.add(ApiRequestScope.current);
    final read = Completer<CategoryServerSnapshot>();
    reads.add(read);
    return read.future;
  }

  @override
  RefreshTicket beginRefresh({bool preserveViewport = false}) {
    log.add('beginRefresh(preserveViewport=$preserveViewport)');
    return RefreshTicket(
      accountVersion: generation,
      version: ++refreshGeneration,
      feedVersions: const {},
      categoryDetailsRequired: true,
      preserveViewport: preserveViewport,
    );
  }

  @override
  Future<RefreshResult> refresh(
    RefreshTicket ticket, {
    bool includeCategories = true,
  }) {
    log.add('refresh(includeCategories=$includeCategories)');
    refreshScopes.add(ApiRequestScope.current);
    final refresh = Completer<RefreshResult>();
    refreshes.add(refresh);
    return refresh.future;
  }

  @override
  bool isCurrentRefresh(RefreshTicket ticket) =>
      ticket.accountVersion == generation &&
      ticket.version == refreshGeneration;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Users extends UserRepository {
  int refreshCalls = 0;

  @override
  Future<void> refresh({required bool Function() isCurrent}) async {
    refreshCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Session extends SessionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Rig {
  final content = _Content();
  final users = _Users();
  late final actions = ContentActions(content, users, _Session());
  final effects = <UiEffect>[];
}

/// Real repository whose category list method alone is replaced.
class _ListApi extends ClipbackApi {
  _ListApi() : super(client: MockClient((_) => throw StateError('transport')));

  final lists = <Completer<List<ApiCategory>>>[];

  @override
  Future<List<ApiCategory>> listCategories() {
    final list = Completer<List<ApiCategory>>();
    lists.add(list);
    return list.future;
  }
}

class _ListApiRig {
  final api = _ListApi();
  late final content = RemoteContentRepository(api);
  late final actions = ContentActions(content, _Users(), _Session());
  final effects = <UiEffect>[];
}

final _categoryListBody = jsonEncode([
  {
    'id': 7,
    'name': 'n',
    'color': '#000000',
    'is_default': false,
    'content_count': 0,
    'last_saved_at': null,
  },
]);

/// Real repository and API client over a MockClient the test answers.
class _Server {
  final requests = <String>[];
  final responses = <Completer<http.Response>>[];
  late final api =
      ClipbackApi(
        client: MockClient((request) {
          requests.add('${request.method} ${request.url.path}');
          final response = Completer<http.Response>();
          responses.add(response);
          return response.future;
        }),
      )..restoreSession(
        const ApiSession(
          accessToken: 'a',
          refreshToken: 'r',
          expiresIn: 3600,
          refreshExpiresIn: 3600,
        ),
      );
  late final content = RemoteContentRepository(api);
  late final actions = ContentActions(content, _Users(), _Session());
  final effects = <UiEffect>[];

  void ok(int index) =>
      responses[index].complete(http.Response(_categoryListBody, 200));
}

/// Watches a scope close through `cancelled`; reading `isActive` may close it.
class _Closed {
  _Closed(ApiRequestScope scope) {
    scope.cancelled.then((_) => closed = true);
  }

  bool closed = false;
}

class _Save {
  CategorySaveResult? result;
}

_Save _submit(_Rig rig, {required bool edit}) {
  final save = _Save();
  final future = edit
      ? rig.actions.submitCategoryUpdate(
          7,
          name: 'n',
          color: '#000000',
          submissionKey: 'k1',
          feedback: rig.effects.add,
        )
      : rig.actions.submitCategoryCreate(
          name: 'n',
          color: '#000000',
          submissionKey: 'k1',
          feedback: rig.effects.add,
        );
  future.then((result) => save.result = result);
  return save;
}

class _Reload {
  bool? returned;
  final loaded = <int>[];
  final loadedInScope = <bool>[];
}

_Reload _reload(
  ContentActions actions,
  List<UiEffect> effects, {
  bool afterSave = false,
  bool Function()? isCurrent,
  void Function()? whileLoading,
}) {
  final reload = _Reload();
  actions
      .reloadCategories(
        feedback: effects.add,
        afterSave: afterSave,
        isCurrent: isCurrent,
        onLoaded: (categories) {
          reload.loaded.add(categories.length);
          reload.loadedInScope.add(ApiRequestScope.current != null);
          whileLoading?.call();
        },
      )
      .then((value) => reload.returned = value);
  return reload;
}

String _saveRequest(bool edit) =>
    edit ? 'update(7,n,#000000,k1)' : 'create(n,#000000,k1)';

List<String> _followUps(bool edit) => edit
    ? const [
        'read',
        'beginRefresh(preserveViewport=true)',
        'refresh(includeCategories=false)',
      ]
    : const ['read'];

CategoryServerSnapshot _snapshot({bool current = true}) =>
    CategoryServerSnapshot(const [_category], () => current);

List<String> _notices(List<UiEffect> effects) => [
  for (final effect in effects)
    effect is MessageEffect
        ? '${effect.message} | ${effect.retryLabel}'
              '${effect.retry == null ? '' : ' | retry'}'
        : '$effect',
];

void _expectResult(
  CategorySaveResult? result,
  CategorySaveStatus status, [
  CategorySaveRejection? rejection,
]) {
  expect(result, isNotNull);
  expect(result!.status, status);
  expect(result.submissionKey, 'k1');
  expect(result.rejection, rejection);
}

Future<void> _finish(WidgetTester tester, ContentActions actions) async {
  actions.dispose();
  await tester.pump(const Duration(seconds: 11));
}

enum _Arrival { success, rejected, error, silence }

enum _Change { t0, t1, t2 }

/// Observations of one S15/S16 run: account change at T0, T1 or T2.
class _Race {
  CategorySaveResult? result;
  late bool closedAtChange;
  bool? closedBeforeEnd;
  late bool closedAtEnd;
  late List<String> requests;
  late List<UiEffect> effects;
}

Future<_Race> _race(
  WidgetTester tester, {
  required bool edit,
  required _Arrival arrival,
  required _Change change,
}) async {
  final rig = _Rig();
  final save = _submit(rig, edit: edit);
  final race = _Race();
  await tester.pump();
  final closed = _Closed(rig.content.submitScope!);
  void arrive() {
    switch (arrival) {
      case _Arrival.success:
        rig.content.submit!.complete(_category);
      case _Arrival.rejected:
        rig.content.submit!.completeError(
          const CategorySubmissionRejected('m', code: 'category_name_exists'),
        );
      case _Arrival.error:
        rig.content.submit!.completeError(StateError('x'));
      case _Arrival.silence:
        break;
    }
  }

  switch (change) {
    case _Change.t0:
      rig.content.generation++;
      await tester.pump();
      race.closedAtChange = closed.closed;
      if (arrival == _Arrival.silence) {
        await tester.pump(const Duration(milliseconds: 9999));
        race.closedBeforeEnd = closed.closed;
        await tester.pump(const Duration(milliseconds: 1));
      } else {
        race.closedBeforeEnd = closed.closed;
        arrive();
        await tester.pump();
      }
    case _Change.t1:
      if (arrival == _Arrival.silence) {
        await tester.pump(const Duration(milliseconds: 9999));
        rig.content.generation++;
        race.closedAtChange = closed.closed;
        await tester.pump(const Duration(milliseconds: 1));
      } else {
        arrive();
        rig.content.generation++;
        race.closedAtChange = closed.closed;
        await tester.pump();
      }
    case _Change.t2:
      if (arrival == _Arrival.silence) {
        await tester.pump(const Duration(seconds: 10));
      } else {
        arrive();
        await tester.pump();
      }
      race.result = save.result;
      race.closedAtChange = closed.closed;
      rig.content.generation++;
  }
  race.result ??= save.result;
  race.closedAtEnd = closed.closed;
  await tester.pump(const Duration(milliseconds: 1));
  race.requests = [...rig.content.log];
  race.effects = [...rig.effects];
  await _finish(tester, rig.actions);
  return race;
}

void main() {
  group('카테고리 생성·수정 저장', () {
    for (final edit in [false, true]) {
      final kind = edit ? '수정' : '생성';

      testWidgets('S1 $kind: 성공은 응답 즉시 succeeded, 후속 요청은 다음 이벤트에 각자 수명으로', (
        tester,
      ) async {
        final rig = _Rig();
        final save = _submit(rig, edit: edit);
        await tester.pump();
        final submitScope = rig.content.submitScope;
        expect(submitScope, isNotNull);
        final submitClosed = _Closed(submitScope!);
        await tester.pump();
        expect(save.result, isNull);
        expect(submitClosed.closed, isFalse);

        rig.content.submit!.complete(_category);
        await tester.pump();
        _expectResult(save.result, CategorySaveStatus.succeeded);
        expect(submitClosed.closed, isTrue);
        expect(rig.content.log, [_saveRequest(edit)]);

        await tester.pump(const Duration(milliseconds: 1));
        expect(rig.content.log, [_saveRequest(edit), ..._followUps(edit)]);
        final readScope = rig.content.readScopes.single;
        expect(readScope, isNotNull);
        expect(identical(readScope, submitScope), isFalse);
        if (edit) {
          final refreshScope = rig.content.refreshScopes.single;
          expect(refreshScope, isNotNull);
          expect(identical(refreshScope, submitScope), isFalse);
          expect(identical(refreshScope, readScope), isFalse);
        } else {
          expect(rig.content.refreshScopes, isEmpty);
        }

        rig.content.reads.single.complete(_snapshot());
        if (edit) rig.content.refreshes.single.complete(_feedResult);
        await tester.pump();
        expect(rig.content.log, [_saveRequest(edit), ..._followUps(edit)]);
        expect(rig.effects, isEmpty);
        expect(rig.users.refreshCalls, 0);
        await _finish(tester, rig.actions);
      });

      testWidgets('S2 $kind: 후속 목록 조회 실패는 저장 뒤 안내 1회, 재시도는 목록 조회만', (
        tester,
      ) async {
        final rig = _Rig();
        _submit(rig, edit: edit);
        await tester.pump();
        rig.content.submit!.complete(_category);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        rig.content.reads.single.completeError(const ClipbackApiException('x'));
        if (edit) rig.content.refreshes.single.complete(_feedResult);
        await tester.pump();
        expect(_notices(rig.effects), [_afterSaveNotice]);

        (rig.effects.single as MessageEffect).retry!();
        await tester.pump(const Duration(milliseconds: 1));
        expect(rig.content.log, [
          _saveRequest(edit),
          ..._followUps(edit),
          'read',
        ]);
        rig.content.reads.last.complete(_snapshot());
        await tester.pump();
        expect(_notices(rig.effects), [_afterSaveNotice]);
        await _finish(tester, rig.actions);
      });

      testWidgets('S4 $kind: 후속 요청 무응답은 9.999초까지 안내 없음, 10초에 목록 안내 1회와 수명 닫힘', (
        tester,
      ) async {
        final rig = _Rig();
        _submit(rig, edit: edit);
        await tester.pump();
        rig.content.submit!.complete(_category);
        await tester.pump();
        // Follow-ups start at the result time; this pump moves 1ms past it.
        await tester.pump(const Duration(milliseconds: 1));
        final readClosed = _Closed(rig.content.readScopes.single!);
        final refreshClosed = edit
            ? _Closed(rig.content.refreshScopes.single!)
            : null;

        await tester.pump(const Duration(milliseconds: 9998));
        expect(rig.effects, isEmpty);
        expect(readClosed.closed, isFalse);
        expect(refreshClosed?.closed, edit ? isFalse : isNull);

        await tester.pump(const Duration(milliseconds: 1));
        expect(_notices(rig.effects), [_afterSaveNotice]);
        expect(readClosed.closed, isTrue);
        expect(refreshClosed?.closed, edit ? isTrue : isNull);
        await _finish(tester, rig.actions);
      });

      testWidgets('S5 $kind: 결과 직후 후속 시작 전 계정 변경은 succeeded 유지, 후속 없음', (
        tester,
      ) async {
        final rig = _Rig();
        final save = _submit(rig, edit: edit);
        await tester.pump();
        rig.content.submit!.complete(_category);
        await tester.pump();
        _expectResult(save.result, CategorySaveStatus.succeeded);
        rig.content.generation++;
        await tester.pump(const Duration(milliseconds: 1));
        _expectResult(save.result, CategorySaveStatus.succeeded);
        expect(rig.content.log, [_saveRequest(edit)]);
        expect(rig.effects, isEmpty);
        await _finish(tester, rig.actions);
      });

      testWidgets('S6 $kind: 저장소 null 반환은 stale, 후속 없음', (tester) async {
        final rig = _Rig();
        final save = _submit(rig, edit: edit);
        await tester.pump();
        rig.content.submit!.complete(null);
        await tester.pump();
        _expectResult(save.result, CategorySaveStatus.stale);
        await tester.pump(const Duration(milliseconds: 1));
        expect(rig.content.log, [_saveRequest(edit)]);
        expect(rig.effects, isEmpty);
        await _finish(tester, rig.actions);
      });

      const rejections = {
        'category_name_exists': (CategorySaveRejection.nameExists, 'S7'),
        'category_input_invalid': (CategorySaveRejection.inputInvalid, 'S7'),
        'category_target_missing': (CategorySaveRejection.targetMissing, 'S7'),
        'unknown_code': (CategorySaveRejection.other, 'S8'),
        '': (CategorySaveRejection.other, 'S8'),
      };
      for (final MapEntry(key: code, value: (rejection, row))
          in rejections.entries) {
        testWidgets('$row $kind: 거절 코드 "$code"는 rejected·${rejection.name}', (
          tester,
        ) async {
          final rig = _Rig();
          final save = _submit(rig, edit: edit);
          await tester.pump();
          rig.content.submit!.completeError(
            CategorySubmissionRejected('m', code: code, statusCode: 409),
          );
          await tester.pump();
          _expectResult(save.result, CategorySaveStatus.rejected, rejection);
          await tester.pump(const Duration(milliseconds: 1));
          expect(rig.content.log, [_saveRequest(edit)]);
          expect(rig.effects, isEmpty);
          await _finish(tester, rig.actions);
        });
      }

      for (final error in <Object>[
        const ClipbackApiException('boom', statusCode: 500),
        StateError('x'),
        TimeoutException('t'),
      ]) {
        testWidgets('S9 $kind: 거절이 아닌 오류 ${error.runtimeType}는 unconfirmed', (
          tester,
        ) async {
          final rig = _Rig();
          final save = _submit(rig, edit: edit);
          await tester.pump();
          rig.content.submit!.completeError(error);
          await tester.pump();
          _expectResult(save.result, CategorySaveStatus.unconfirmed);
          await tester.pump(const Duration(milliseconds: 1));
          expect(rig.content.log, [_saveRequest(edit)]);
          expect(rig.effects, isEmpty);
          await _finish(tester, rig.actions);
        });
      }

      testWidgets('S10 $kind: 무응답은 9.999초까지 결과 없음, 10초에 unconfirmed·수명 닫힘', (
        tester,
      ) async {
        final rig = _Rig();
        final save = _submit(rig, edit: edit);
        await tester.pump();
        final closed = _Closed(rig.content.submitScope!);
        await tester.pump(const Duration(milliseconds: 9999));
        expect(save.result, isNull);
        expect(closed.closed, isFalse);
        await tester.pump(const Duration(milliseconds: 1));
        _expectResult(save.result, CategorySaveStatus.unconfirmed);
        expect(closed.closed, isTrue);

        rig.content.submit!.complete(_category);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        _expectResult(save.result, CategorySaveStatus.unconfirmed);
        expect(rig.content.log, [_saveRequest(edit)]);
        expect(rig.effects, isEmpty);
        await _finish(tester, rig.actions);
      });

      for (final (row, boundary) in [('S11', '계정 변경'), ('S13', '정리')]) {
        for (final arrival in [
          _Arrival.success,
          _Arrival.rejected,
          _Arrival.error,
        ]) {
          testWidgets(
            '$row $kind: 대기 중 $boundary 뒤 ${arrival.name} 도착 즉시 stale',
            (tester) async {
              final rig = _Rig();
              final save = _submit(rig, edit: edit);
              await tester.pump();
              if (boundary == '계정 변경') {
                rig.content.generation++;
              } else {
                rig.actions.dispose();
              }
              await tester.pump(const Duration(seconds: 1));
              expect(save.result, isNull);
              switch (arrival) {
                case _Arrival.success:
                  rig.content.submit!.complete(_category);
                case _Arrival.rejected:
                  rig.content.submit!.completeError(
                    const CategorySubmissionRejected(
                      'm',
                      code: 'category_name_exists',
                    ),
                  );
                case _Arrival.error:
                  rig.content.submit!.completeError(StateError('x'));
                case _Arrival.silence:
                  break;
              }
              await tester.pump();
              _expectResult(save.result, CategorySaveStatus.stale);
              await tester.pump(const Duration(milliseconds: 1));
              expect(rig.content.log, [_saveRequest(edit)]);
              expect(rig.effects, isEmpty);
              await _finish(tester, rig.actions);
            },
          );
        }
      }

      for (final (row, boundary) in [('S12', '계정 변경'), ('S13', '정리')]) {
        testWidgets('$row $kind: 대기 중 $boundary 뒤 무응답은 10초에 stale', (
          tester,
        ) async {
          final rig = _Rig();
          final save = _submit(rig, edit: edit);
          await tester.pump();
          if (boundary == '계정 변경') {
            rig.content.generation++;
          } else {
            rig.actions.dispose();
          }
          await tester.pump(const Duration(milliseconds: 9999));
          expect(save.result, isNull);
          await tester.pump(const Duration(milliseconds: 1));
          _expectResult(save.result, CategorySaveStatus.stale);
          expect(rig.content.log, [_saveRequest(edit)]);
          expect(rig.effects, isEmpty);
          await _finish(tester, rig.actions);
        });
      }

      for (final arrival in _Arrival.values) {
        for (final change in _Change.values) {
          final expected = change == _Change.t2
              ? switch (arrival) {
                  _Arrival.success => (CategorySaveStatus.succeeded, null),
                  _Arrival.rejected => (
                    CategorySaveStatus.rejected,
                    CategorySaveRejection.nameExists,
                  ),
                  _Arrival.error => (CategorySaveStatus.unconfirmed, null),
                  _Arrival.silence => (CategorySaveStatus.unconfirmed, null),
                }
              : (CategorySaveStatus.stale, null);

          testWidgets(
            'S15 $kind: ${arrival.name} × 계정 변경 ${change.name.toUpperCase()} → '
            '${expected.$1.name}${expected.$2 == null ? '' : '·${expected.$2!.name}'}',
            (tester) async {
              final race = await _race(
                tester,
                edit: edit,
                arrival: arrival,
                change: change,
              );
              _expectResult(race.result, expected.$1, expected.$2);
              expect(race.requests, [_saveRequest(edit)]);
              expect(race.effects, isEmpty);
            },
          );

          testWidgets(
            'S16 $kind: ${arrival.name} × 계정 변경 ${change.name.toUpperCase()}의 수명 닫힘 시점',
            (tester) async {
              final race = await _race(
                tester,
                edit: edit,
                arrival: arrival,
                change: change,
              );
              if (change == _Change.t2) {
                expect(race.closedAtChange, isTrue);
              } else {
                expect(race.closedAtChange, isFalse);
                if (race.closedBeforeEnd != null) {
                  expect(race.closedBeforeEnd, isFalse);
                }
                expect(race.closedAtEnd, isTrue);
              }
            },
          );
        }
      }

      testWidgets('S17 $kind: 성공 응답의 수명은 결과가 나온 같은 pump에서 닫힘', (tester) async {
        final rig = _Rig();
        final save = _submit(rig, edit: edit);
        await tester.pump();
        final closed = _Closed(rig.content.submitScope!);
        rig.content.submit!.complete(_category);
        await tester.pump();
        _expectResult(save.result, CategorySaveStatus.succeeded);
        expect(closed.closed, isTrue);
        await _finish(tester, rig.actions);
      });
    }

    testWidgets('S3 수정: 후속 피드 갱신 실패는 안내 없음', (tester) async {
      for (final error in <Object>[
        const ClipbackApiException('feed'),
        StateError('feed'),
      ]) {
        final rig = _Rig();
        _submit(rig, edit: true);
        await tester.pump();
        rig.content.submit!.complete(_category);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        rig.content.reads.single.complete(_snapshot());
        rig.content.refreshes.single.completeError(error);
        await tester.pump();
        expect(rig.effects, isEmpty, reason: '$error');
        await _finish(tester, rig.actions);
      }
    });

    testWidgets('S14 생성: 이미 정리된 ContentActions는 stale, 저장 요청 없음', (
      tester,
    ) async {
      final rig = _Rig();
      rig.actions.dispose();
      final save = _submit(rig, edit: false);
      await tester.pump();
      _expectResult(save.result, CategorySaveStatus.stale);
      expect(rig.content.log, isEmpty);
      await tester.pump(const Duration(seconds: 11));
    });
  });

  group('카테고리 목록 재조회', () {
    testWidgets('R1 대역: 성공은 true·onLoaded 1회, 요청 안에서 수명이 보이고 끝나면 닫힘', (
      tester,
    ) async {
      final rig = _Rig();
      final reload = _reload(rig.actions, rig.effects);
      await tester.pump();
      final scope = rig.content.readScopes.single;
      expect(scope, isNotNull);
      final closed = _Closed(scope!);
      await tester.pump();
      expect(reload.returned, isNull);
      expect(closed.closed, isFalse);

      rig.content.reads.single.complete(_snapshot());
      await tester.pump();
      expect(reload.returned, isTrue);
      expect(reload.loaded, [1]);
      expect(rig.effects, isEmpty);
      expect(closed.closed, isTrue);
      await _finish(tester, rig.actions);
    });

    testWidgets('R1a 실제+MockClient: 성공은 true·onLoaded 1회, onLoaded는 요청 수명 밖', (
      tester,
    ) async {
      final server = _Server();
      final reload = _reload(server.actions, server.effects);
      await tester.pump();
      server.ok(0);
      await tester.pump();
      expect(server.requests, ['GET /api/v1/categories']);
      expect(reload.returned, isTrue);
      expect(reload.loaded, [1]);
      expect(reload.loadedInScope, [false]);
      expect(server.content.categories, hasLength(1));
      expect(server.effects, isEmpty);
      await _finish(tester, server.actions);
      server.content.dispose();
    });

    testWidgets('R1b 실제+MockClient: 목록 응답의 current는 받은 수명이 열린 동안만 true', (
      tester,
    ) async {
      final server = _Server();
      final owner = ApiRequestScope(timeout: const Duration(seconds: 10));
      final pending = owner.run(() => server.content.readCurrentCategories());
      await tester.pump();
      server.ok(0);
      await tester.pump();
      final snapshot = await pending;
      expect(snapshot.current, isTrue);
      owner.cancel();
      expect(snapshot.current, isFalse);
      await _finish(tester, server.actions);
      server.content.dispose();
    });

    testWidgets('R2 대역: 응답 자체가 현재 것이 아니면 false, onLoaded 없음', (tester) async {
      final rig = _Rig();
      final reload = _reload(rig.actions, rig.effects);
      await tester.pump();
      rig.content.reads.single.complete(_snapshot(current: false));
      await tester.pump();
      expect(reload.returned, isFalse);
      expect(reload.loaded, isEmpty);
      expect(rig.effects, isEmpty);
      await _finish(tester, rig.actions);
    });

    testWidgets('R3 대역: onLoaded 안에서 바깥 조건이 false가 되면 onLoaded 1회·false', (
      tester,
    ) async {
      final rig = _Rig();
      var outer = true;
      final reload = _reload(
        rig.actions,
        rig.effects,
        isCurrent: () => outer,
        whileLoading: () => outer = false,
      );
      await tester.pump();
      rig.content.reads.single.complete(_snapshot());
      await tester.pump();
      expect(reload.loaded, [1]);
      expect(reload.returned, isFalse);
      expect(rig.effects, isEmpty);
      await _finish(tester, rig.actions);
    });

    testWidgets('R3a 실제+API 목록 대역: onLoaded 안에서 바깥 조건이 false가 되면 R3과 같음', (
      tester,
    ) async {
      final rig = _ListApiRig();
      var outer = true;
      final reload = _reload(
        rig.actions,
        rig.effects,
        isCurrent: () => outer,
        whileLoading: () => outer = false,
      );
      await tester.pump();
      rig.api.lists.single.complete(const [_category]);
      await tester.pump();
      expect(reload.loaded, [1]);
      expect(reload.returned, isFalse);
      expect(rig.effects, isEmpty);
      await _finish(tester, rig.actions);
      rig.content.dispose();
    });

    testWidgets('R3b 실제+MockClient: onLoaded 안에서 바깥 조건이 false가 되면 R3과 같음', (
      tester,
    ) async {
      final server = _Server();
      var outer = true;
      final reload = _reload(
        server.actions,
        server.effects,
        isCurrent: () => outer,
        whileLoading: () => outer = false,
      );
      await tester.pump();
      server.ok(0);
      await tester.pump();
      expect(reload.loaded, [1]);
      expect(reload.returned, isFalse);
      expect(server.effects, isEmpty);
      await _finish(tester, server.actions);
      server.content.dispose();
    });

    for (final (row, boundary) in [
      ('R4', '바깥 조건이 false가 되면'),
      ('R5', '계정이 바뀌면'),
    ]) {
      testWidgets('$row 대역: 대기 중 $boundary 응답 도착 때 false로 끝남', (tester) async {
        final rig = _Rig();
        var outer = true;
        final reload = _reload(
          rig.actions,
          rig.effects,
          isCurrent: () => outer,
        );
        await tester.pump();
        if (row == 'R4') {
          outer = false;
        } else {
          rig.content.generation++;
        }
        await tester.pump(const Duration(seconds: 1));
        expect(reload.returned, isNull);
        rig.content.reads.single.complete(_snapshot());
        await tester.pump();
        expect(reload.returned, isFalse);
        expect(reload.loaded, isEmpty);
        expect(rig.effects, isEmpty);
        await _finish(tester, rig.actions);
      });
    }

    testWidgets('R6 대역: 대기 중 정리는 즉시 false·수명 닫힘', (tester) async {
      final rig = _Rig();
      final reload = _reload(rig.actions, rig.effects);
      await tester.pump();
      final closed = _Closed(rig.content.readScopes.single!);
      rig.actions.dispose();
      await tester.pump();
      expect(reload.returned, isFalse);
      expect(closed.closed, isTrue);
      rig.content.reads.single.complete(_snapshot());
      await tester.pump();
      expect(reload.loaded, isEmpty);
      expect(rig.effects, isEmpty);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('R7 대역: 새 재조회가 이전 조회를 즉시 false로 끝냄, 새 조회는 정상', (tester) async {
      final rig = _Rig();
      final first = _reload(rig.actions, rig.effects);
      await tester.pump();
      final second = _reload(rig.actions, rig.effects);
      await tester.pump();
      expect(first.returned, isFalse);
      expect(second.returned, isNull);

      rig.content.reads.first.complete(_snapshot());
      await tester.pump();
      expect(first.loaded, isEmpty);
      rig.content.reads.last.complete(_snapshot());
      await tester.pump();
      expect(second.returned, isTrue);
      expect(second.loaded, [1]);
      expect(first.loaded, isEmpty);
      expect(rig.content.log, ['read', 'read']);
      expect(rig.effects, isEmpty);
      await _finish(tester, rig.actions);
    });

    for (final (row, afterSave, notice) in [
      ('R8', false, _readNotice),
      ('R9', true, _afterSaveNotice),
    ]) {
      testWidgets('$row 대역: 실패(저장 뒤 조회=$afterSave)는 false와 안내 1회', (
        tester,
      ) async {
        final rig = _Rig();
        final reload = _reload(rig.actions, rig.effects, afterSave: afterSave);
        await tester.pump();
        rig.content.reads.single.completeError(StateError('x'));
        await tester.pump();
        expect(reload.returned, isFalse);
        expect(_notices(rig.effects), [notice]);
        await _finish(tester, rig.actions);
      });

      testWidgets('R10 대역: $row 재시도는 아직 현재면 목록 조회 1회', (tester) async {
        final rig = _Rig();
        _reload(rig.actions, rig.effects, afterSave: afterSave);
        await tester.pump();
        rig.content.reads.single.completeError(StateError('x'));
        await tester.pump();
        (rig.effects.single as MessageEffect).retry!();
        await tester.pump();
        expect(rig.content.log, ['read', 'read']);
        await _finish(tester, rig.actions);
      });

      testWidgets('R11 대역: $row 재시도는 그사이 계정이 바뀌면 요청 없음', (tester) async {
        final rig = _Rig();
        _reload(rig.actions, rig.effects, afterSave: afterSave);
        await tester.pump();
        rig.content.reads.single.completeError(StateError('x'));
        await tester.pump();
        rig.content.generation++;
        (rig.effects.single as MessageEffect).retry!();
        await tester.pump();
        expect(rig.content.log, ['read']);
        await _finish(tester, rig.actions);
      });
    }

    testWidgets('R8b 실제+MockClient: 서버 500은 R8과 같음', (tester) async {
      final server = _Server();
      final reload = _reload(server.actions, server.effects);
      await tester.pump();
      server.responses.single.complete(http.Response('{"detail":"x"}', 500));
      await tester.pump();
      expect(reload.returned, isFalse);
      expect(_notices(server.effects), [_readNotice]);
      await _finish(tester, server.actions);
      server.content.dispose();
    });

    testWidgets('R12 대역: 무응답은 9.999초까지 미완료, 10초에 false와 R8 안내 1회', (
      tester,
    ) async {
      final rig = _Rig();
      final reload = _reload(rig.actions, rig.effects);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 9999));
      expect(reload.returned, isNull);
      expect(rig.effects, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(reload.returned, isFalse);
      expect(_notices(rig.effects), [_readNotice]);
      await _finish(tester, rig.actions);
    });

    testWidgets('R13 대역: 이미 정리된 ContentActions는 false, 요청 없음', (tester) async {
      final rig = _Rig();
      rig.actions.dispose();
      final reload = _reload(rig.actions, rig.effects);
      await tester.pump();
      expect(reload.returned, isFalse);
      expect(rig.content.log, isEmpty);
      expect(rig.effects, isEmpty);
    });

    for (final (row, staleFirst, notices) in [
      ('R14', false, [_readNotice]),
      ('R15', true, <String>[]),
    ]) {
      testWidgets('$row 대역: onLoaded 예외(바깥 조건 false로 만든 뒤=$staleFirst)', (
        tester,
      ) async {
        final rig = _Rig();
        var outer = true;
        Object? escaped;
        late _Reload reload;
        runZonedGuarded(() {
          reload = _reload(
            rig.actions,
            rig.effects,
            isCurrent: () => outer,
            whileLoading: () {
              if (staleFirst) outer = false;
              throw StateError('onLoaded');
            },
          );
        }, (error, _) => escaped = error);
        await tester.pump();
        rig.content.reads.single.complete(_snapshot());
        await tester.pump();
        expect(reload.returned, isFalse);
        expect(_notices(rig.effects), notices);
        expect(escaped, isNull);
        await _finish(tester, rig.actions);
      });
    }

    for (final afterSave in [false, true]) {
      testWidgets(
        'R16 대역: 저장소의 CategoryReadSuperseded(저장 뒤 조회=$afterSave)는 false·안내 없음',
        (tester) async {
          final rig = _Rig();
          final reload = _reload(
            rig.actions,
            rig.effects,
            afterSave: afterSave,
          );
          await tester.pump();
          rig.content.reads.single.completeError(
            const CategoryReadSuperseded(),
          );
          await tester.pump();
          expect(reload.returned, isFalse);
          expect(reload.loaded, isEmpty);
          expect(rig.effects, isEmpty);
          expect(rig.content.log, ['read']);
          await _finish(tester, rig.actions);
        },
      );
    }

    testWidgets('R17 실제+API 목록 대역: 다른 저장소 조회가 대체하면 옛 응답 도착 때 false·안내 없음', (
      tester,
    ) async {
      final rig = _ListApiRig();
      final reload = _reload(rig.actions, rig.effects);
      await tester.pump();
      var otherDone = false;
      rig.content.loadCategories().then((_) => otherDone = true);
      await tester.pump();
      expect(reload.returned, isNull);
      rig.api.lists.last.complete(const [_category]);
      await tester.pump();
      expect(otherDone, isTrue);
      expect(reload.returned, isNull);
      rig.api.lists.first.complete(const [_category, _category]);
      await tester.pump();
      expect(reload.returned, isFalse);
      expect(reload.loaded, isEmpty);
      expect(rig.effects, isEmpty);
      expect(rig.api.lists, hasLength(2));
      await _finish(tester, rig.actions);
      rig.content.dispose();
    });

    testWidgets('R17b 실제+MockClient: 다른 저장소 조회가 대체하면 즉시 false·안내 없음', (
      tester,
    ) async {
      final server = _Server();
      final reload = _reload(server.actions, server.effects);
      await tester.pump();
      var otherDone = false;
      server.content.loadCategories().then((_) => otherDone = true);
      await tester.pump();
      expect(reload.returned, isFalse);
      server.ok(1);
      await tester.pump();
      server.ok(0);
      await tester.pump();
      expect(otherDone, isTrue);
      expect(reload.returned, isFalse);
      expect(reload.loaded, isEmpty);
      expect(server.effects, isEmpty);
      expect(server.requests, [
        'GET /api/v1/categories',
        'GET /api/v1/categories',
      ]);
      await _finish(tester, server.actions);
      server.content.dispose();
    });
  });

  group('수정 저장 뒤 피드 갱신', () {
    for (final (row, boundary) in [('F1', '더 새 갱신'), ('F2', '계정 변경')]) {
      for (final outcome in ['성공', '실패', '무응답']) {
        testWidgets('$row: 갱신 대기 중 $boundary 뒤 옛 갱신 $outcome', (tester) async {
          final rig = _Rig();
          _submit(rig, edit: true);
          await tester.pump();
          rig.content.submit!.complete(_category);
          await tester.pump();
          // The feed scope starts at the result time; this pump moves 1ms past it.
          await tester.pump(const Duration(milliseconds: 1));
          rig.content.reads.single.complete(_snapshot());
          await tester.pump();
          final closed = _Closed(rig.content.refreshScopes.single!);
          if (row == 'F1') {
            rig.content.beginRefresh();
          } else {
            rig.content.generation++;
          }
          await tester.pump();
          expect(closed.closed, isFalse);
          await tester.pump(const Duration(seconds: 1));
          expect(closed.closed, isFalse);

          switch (outcome) {
            case '성공':
              rig.content.refreshes.single.complete(_feedResult);
            case '실패':
              rig.content.refreshes.single.completeError(StateError('feed'));
          }
          await tester.pump();
          if (outcome == '무응답') {
            expect(closed.closed, isFalse);
            await tester.pump(const Duration(milliseconds: 8998));
            expect(closed.closed, isFalse);
            await tester.pump(const Duration(milliseconds: 1));
          }
          expect(closed.closed, isTrue);
          expect(rig.effects, isEmpty);
          expect(rig.content.log, [
            'update(7,n,#000000,k1)',
            'read',
            'beginRefresh(preserveViewport=true)',
            'refresh(includeCategories=false)',
            if (row == 'F1') 'beginRefresh(preserveViewport=false)',
          ]);
          await _finish(tester, rig.actions);
        });
      }
    }
  });
}

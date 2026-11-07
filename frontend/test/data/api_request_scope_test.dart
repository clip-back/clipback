import 'dart:async';

import 'package:clipback_frontend/data/services/api_request_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiRequestScope.settle', () {
    test('값 도착 + 현재 → 성공', () async {
      final scope = ApiRequestScope(isCurrent: () => true);

      final outcome = await scope.settle(() async => 'value');

      expect(outcome, isA<RequestSucceeded<String>>());
      expect((outcome as RequestSucceeded<String>).value, 'value');
    });

    test('값 도착 + 현재 아님 → 늦은 응답', () async {
      var current = true;
      final response = Completer<String>();
      final scope = ApiRequestScope(isCurrent: () => current);

      final pending = scope.settle(() => response.future);
      current = false;
      response.complete('value');

      expect(await pending, isA<RequestStale<String>>());
    });

    test('null 값 → 성공(null)', () async {
      final scope = ApiRequestScope(isCurrent: () => true);

      final outcome = await scope.settle<String?>(() async => null);

      expect(outcome, isA<RequestSucceeded<String?>>());
      expect((outcome as RequestSucceeded<String?>).value, isNull);
    });

    test('오류 + 현재 → 실패(그 오류)', () async {
      final error = StateError('failed');
      final scope = ApiRequestScope(isCurrent: () => true);

      final outcome = await scope.settle<String>(() async => throw error);

      expect(outcome, isA<RequestFailed<String>>());
      expect((outcome as RequestFailed<String>).error, same(error));
    });

    test('오류 + 현재 아님 → 늦은 응답', () async {
      var current = true;
      final response = Completer<String>();
      final scope = ApiRequestScope(isCurrent: () => current);

      final pending = scope.settle(() => response.future);
      current = false;
      response.completeError(StateError('failed'));

      expect(await pending, isA<RequestStale<String>>());
    });

    test('바깥 cancel + 현재 → 실패(취소 사유)', () async {
      final reason = StateError('cancelled');
      final scope = ApiRequestScope(isCurrent: () => true);

      final pending = scope.settle(() => Completer<String>().future);
      scope.cancel(reason);
      final outcome = await pending;

      expect(outcome, isA<RequestFailed<String>>());
      expect((outcome as RequestFailed<String>).error, same(reason));
    });

    test('바깥 cancel + 현재 아님 → 늦은 응답', () async {
      var current = true;
      final scope = ApiRequestScope(isCurrent: () => current);

      final pending = scope.settle(() => Completer<String>().future);
      current = false;
      scope.cancel();

      expect(await pending, isA<RequestStale<String>>());
    });

    testWidgets('시간 초과 → 실패(TimeoutException)', (tester) async {
      final scope = ApiRequestScope(
        timeout: const Duration(seconds: 10),
        isCurrent: () => true,
      );
      RequestOutcome<String>? outcome;

      unawaited(
        scope
            .settle(() => Completer<String>().future)
            .then((value) => outcome = value),
      );
      await tester.pump(const Duration(milliseconds: 9999));
      expect(outcome, isNull);
      await tester.pump(const Duration(milliseconds: 1));

      expect(outcome, isA<RequestFailed<String>>());
      expect(
        (outcome! as RequestFailed<String>).error,
        isA<TimeoutException>(),
      );
    });

    test('현재 조건 없는 수명의 취소 → 실패', () async {
      final scope = ApiRequestScope();

      final pending = scope.settle(() => Completer<String>().future);
      scope.cancel();

      expect(await pending, isA<RequestFailed<String>>());
    });

    test('operation 안에서 ApiRequestScope.current가 그 수명', () async {
      final scope = ApiRequestScope(isCurrent: () => true);
      ApiRequestScope? before;
      ApiRequestScope? afterAwait;

      await scope.settle(() async {
        before = ApiRequestScope.current;
        await Future<void>.delayed(Duration.zero);
        afterAwait = ApiRequestScope.current;
        return 'value';
      });

      expect(before, same(scope));
      expect(afterAwait, same(scope));
      expect(ApiRequestScope.current, isNull);
    });

    test('끝난 뒤 수명이 닫힘(성공·실패·늦은 응답)', () async {
      var current = true;
      final succeeded = ApiRequestScope(isCurrent: () => true);
      final failed = ApiRequestScope(isCurrent: () => true);
      final stale = ApiRequestScope(isCurrent: () => current);

      await succeeded.settle(() async => 'value');
      await failed.settle<String>(() async => throw StateError('failed'));
      await stale.settle(() async {
        current = false;
        return 'value';
      });

      await expectLater(succeeded.cancelled, completes);
      await expectLater(failed.cancelled, completes);
      await expectLater(stale.cancelled, completes);
    });

    test('시작 전에 이미 현재가 아님 → operation을 부르지 않고 늦은 응답', () async {
      final scope = ApiRequestScope(isCurrent: () => false);
      var calls = 0;

      final outcome = await scope.settle(() async {
        calls += 1;
        return 'value';
      });

      expect(outcome, isA<RequestStale<String>>());
      expect(calls, 0);
      await expectLater(scope.cancelled, completes);
    });

    test('operation이 동기로 던진 예외 + 현재 → 실패', () async {
      final error = StateError('sync');
      final scope = ApiRequestScope(isCurrent: () => true);

      final outcome = await scope.settle<String>(() => throw error);

      expect(outcome, isA<RequestFailed<String>>());
      expect((outcome as RequestFailed<String>).error, same(error));
      await expectLater(scope.cancelled, completes);
    });

    test('operation이 동기로 던진 예외 + 현재 아님 → 늦은 응답', () async {
      var current = true;
      final scope = ApiRequestScope(isCurrent: () => current);

      final outcome = await scope.settle<String>(() {
        current = false;
        throw StateError('sync');
      });

      expect(outcome, isA<RequestStale<String>>());
    });

    test('수명은 operation이 끝난 뒤에만 닫힘: 마지막 단계의 isActive는 true', () async {
      final scope = ApiRequestScope(isCurrent: () => true);
      var closed = false;
      unawaited(scope.cancelled.then((_) => closed = true));
      bool? closedAtLastStep;
      bool? activeAtLastStep;

      final outcome = await scope.settle(() async {
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        closedAtLastStep = closed;
        activeAtLastStep = scope.isActive;
        return 'value';
      });

      expect(closedAtLastStep, isFalse);
      expect(activeAtLastStep, isTrue);
      expect(outcome, isA<RequestSucceeded<String>>());
      await expectLater(scope.cancelled, completes);
    });
  });
}

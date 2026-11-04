import 'dart:async';
import 'dart:typed_data';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/services/api_request_scope.dart';

import 'package:clipback_frontend/app/actions/content_actions.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:clipback_frontend/data/repositories/session_repository.dart';
import 'package:clipback_frontend/data/repositories/user_repository.dart';
import 'package:clipback_frontend/shared/contracts/ui_effect.dart';
import 'package:flutter_test/flutter_test.dart';

/// Separates repository completion from the action's awaiting continuation.
class _Content extends ContentRepository {
  int generation = 0;
  int refreshGeneration = 0;
  void Function()? afterCompletion;

  @override
  int get accountVersion => generation;

  @override
  RefreshTicket beginRefresh({bool preserveViewport = false}) => RefreshTicket(
    accountVersion: generation,
    version: ++refreshGeneration,
    feedVersions: const {},
    categoryDetailsRequired: true,
  );

  @override
  Future<RefreshResult> refresh(
    RefreshTicket ticket, {
    bool includeCategories = true,
  }) {
    final result = RefreshResult(
      current: isCurrentRefresh(ticket),
      metadataFailed: true,
      categoryDetailsRequired: true,
    );
    scheduleMicrotask(() => afterCompletion?.call());
    return Future.value(result);
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

class _PhotoContent extends _Content {
  final result = Completer<ApiContent>();
  final received = Completer<void>();
  int inserted = 0;
  @override
  Future<ApiContent> saveScreenshot({
    required Uint8List bytes,
    required String filename,
    String? submissionKey,
    int? categoryId,
  }) {
    expect(submissionKey, 'photo-key');
    expect(categoryId, 42);
    received.complete();
    return result.future;
  }

  @override
  void insertSavedContent(ApiContent content) => inserted++;
}

class _PhotoSession extends _Session {
  @override
  bool get authenticationBusy => false;
  @override
  bool get hasSession => true;
}

final _photo = ApiContent(
  id: 1,
  categories: [],
  tags: [],
  assets: [],
  contentType: 'screenshot',
  source: 'screenshot',
  title: 'photo',
  summary: '',
  originalUrl: null,
  isFavorite: false,
  savedAt: DateTime.utc(2026),
  lastViewedAt: null,
);

void main() {
  for (final boundary in ['account', 'dispose', 'screen']) {
    test(
      'photo response after $boundary boundary cannot insert or signal success',
      () async {
        final content = _PhotoContent();
        final users = _Users();
        final session = _PhotoSession();
        final actions = ContentActions(content, users, session);
        final scope = ApiRequestScope();
        var saved = 0;
        final pending = scope.run(
          () => actions.saveScreenshot(
            bytes: Uint8List(1),
            filename: 'photo.png',
            submissionKey: 'photo-key',
            categoryId: 42,
            onSaved: (_) => saved++,
            feedback: (_) {},
          ),
        );
        final assertion = expectLater(pending, throwsA(anything));
        await content.received.future;
        if (boundary == 'account') content.generation++;
        if (boundary == 'dispose') actions.dispose();
        if (boundary == 'screen') scope.cancel();
        content.result.complete(_photo);
        await assertion;
        expect(content.inserted, 0);
        expect(saved, 0);
        expect(users.refreshCalls, 0);
        actions.dispose();
        content.dispose();
        users.dispose();
        session.dispose();
      },
    );
  }

  for (final accountChange in [true, false]) {
    test(
      '${accountChange ? 'account change' : 'new refresh'} between repository completion and continuation suppresses stale feedback',
      () async {
        final content = _Content();
        final users = _Users();
        final session = _Session();
        final actions = ContentActions(content, users, session);
        addTearDown(() {
          actions.dispose();
          content.dispose();
          users.dispose();
          session.dispose();
        });
        content.afterCompletion = () {
          if (accountChange) {
            content.generation++;
          } else {
            content.refreshGeneration++;
          }
        };
        final effects = <UiEffect>[];

        await actions.refresh(effects.add);

        expect(effects, isEmpty);
        expect(users.refreshCalls, 0);
      },
    );
  }
}

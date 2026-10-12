import 'dart:async';

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
  RefreshTicket beginRefresh() => RefreshTicket(
    accountVersion: generation,
    version: ++refreshGeneration,
    feedVersions: const {},
    categoryDetailsRequired: true,
  );

  @override
  Future<RefreshResult> refresh(RefreshTicket ticket) {
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

void main() {
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

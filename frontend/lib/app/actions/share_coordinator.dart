import 'dart:async';

import '../../data/repositories/session_repository.dart';
import '../../data/repositories/share_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../shared/presentation/view_model.dart';
import 'content_actions.dart';

/// Joins authentication and native saving without changing the current route.
class ShareCoordinator extends ViewModel {
  ShareCoordinator({
    required this.shares,
    required this.session,
    required this.users,
    required this.contentActions,
    required this.canPrepare,
  });

  final ShareRepository shares;
  final SessionRepository session;
  final UserRepository users;
  final ContentActions contentActions;
  final bool Function() canPrepare;
  List<PendingShareDraft> drafts = const [];
  String? error;
  bool ready = false;
  bool busy = false;
  int promptVersion = 0;
  int _epoch = 0;
  Object? _preparedSession;
  Object? _attemptedSession;
  Future<void>? _preparing;
  Future<void>? _blocking;
  bool _retryScheduled = false;
  bool _presenting = false;
  bool _needsBlockRetry = false;

  bool get _eligible =>
      !isDisposed &&
      shares.supported &&
      !_needsBlockRetry &&
      canPrepare() &&
      session.hasSession &&
      !session.pendingSessionClear &&
      !session.authenticationBusy &&
      users.user != null;

  /// Called by listeners; never awaited inside API session callbacks.
  void sessionSettled() {
    if (!_eligible || _retryScheduled || _presenting) return;
    if (identical(_preparedSession, shares.sessionIdentity) ||
        identical(_attemptedSession, shares.sessionIdentity)) {
      return;
    }
    _retryScheduled = true;
    scheduleMicrotask(() {
      _retryScheduled = false;
      if (_eligible) unawaited(prepare());
    });
  }

  Future<void> blockForSessionChange() {
    if (isDisposed) return Future.value();
    final pending = _blocking;
    if (pending != null) return pending;
    _epoch++;
    ready = false;
    _preparedSession = null;
    _attemptedSession = null;
    drafts = const [];
    late final Future<void> operation;
    operation = () async {
      try {
        await shares.blockCredential();
        _needsBlockRetry = false;
        error = null;
      } catch (_) {
        _needsBlockRetry = true;
        error = '공유 저장을 잠그지 못했어요. 계정 변경을 다시 시도해 주세요.';
        rethrow;
      } finally {
        if (identical(_blocking, operation)) _blocking = null;
        notifyListeners();
      }
    }();
    _blocking = operation;
    return operation;
  }

  Future<void> prepare() {
    final pending = _preparing;
    if (pending != null) return pending;
    if (!_eligible || _blocking != null) return Future.value();
    late final Future<void> operation;
    operation = _prepare().whenComplete(() {
      if (identical(_preparing, operation)) _preparing = null;
      // A cancelled old account request must not consume the new account retry.
      sessionSettled();
    });
    _preparing = operation;
    return operation;
  }

  Future<void> _prepare() async {
    final epoch = _epoch;
    final user = users.user!;
    final account = users.accountVersion;
    bool current() =>
        _eligible &&
        epoch == _epoch &&
        account == users.accountVersion &&
        users.user?.id == user.id;
    _attemptedSession = shares.sessionIdentity;
    var published = false;
    var readNativeState = false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final state = await shares.readState();
      readNativeState = true;
      if (!current()) return;
      final prepared = await shares.prepare(
        revision: state.revision,
        userId: user.id,
        accountLabel: user.isGuest
            ? '게스트 · ${user.displayName}'
            : user.displayName,
        isCurrent: current,
      );
      if (!current()) return;
      ready = prepared;
      if (!ready) throw StateError('Share credential was not published');
      _preparedSession = shares.preparedSessionIdentity;
      _attemptedSession = _preparedSession;
      published = true;
      await _readPendingAndReceipts(current, user.id);
    } catch (_) {
      if (current()) {
        error = published
            ? '공유한 항목의 최신 정보를 불러오지 못했어요. 다시 확인해 주세요.'
            : '공유 저장을 준비하지 못했어요. 다시 시도해 주세요.';
        promptVersion++;
        // Receipt reads may refresh tokens after publication. Prepare those new
        // tokens, but do not loop when credential preparation itself failed.
        _attemptedSession = published
            ? _preparedSession
            : shares.sessionIdentity;
        // An unreadable Keychain/Keystore credential needs the durable barrier
        // before re-publication. Keep drafts; do not clear the main login.
        if (!readNativeState) _needsBlockRetry = true;
      }
    } finally {
      if (!isDisposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> _readPendingAndReceipts(
    bool Function() current,
    int userId,
  ) async {
    final state = await shares.readState();
    if (!current()) return;
    drafts = List.unmodifiable(
      state.drafts.where(
        (draft) => draft.userId == null || draft.userId == userId,
      ),
    );
    promptVersion++;
    notifyListeners();
    final receipts = state.receipts
        .where((receipt) => receipt.userId == userId)
        .toList();
    if (receipts.isEmpty) return;
    final refreshed = await contentActions.refreshExternal();
    if (!current() || !refreshed) {
      if (current()) throw StateError('Share receipt refresh incomplete');
      return;
    }
    await shares.acknowledge(receipts.map((receipt) => receipt.id).toList());
  }

  Future<void> resume() async {
    if (_presenting || isDisposed) return;
    await retry();
  }

  Future<void> retry() async {
    if (isDisposed) return;
    if (_needsBlockRetry) {
      try {
        await blockForSessionChange();
      } catch (_) {
        return;
      }
    }
    if (_eligible) await prepare();
  }

  Future<void> present(PendingShareDraft draft) async {
    if (!_eligible || !ready || _presenting || busy) return;
    _presenting = true;
    try {
      await shares.present(draft.id);
    } catch (_) {
      if (!isDisposed) error = '공유 항목을 열지 못했어요. 다시 시도해 주세요.';
    } finally {
      _presenting = false;
      if (!isDisposed) await resume();
    }
  }

  @override
  void dispose() {
    _epoch++;
    super.dispose();
  }
}

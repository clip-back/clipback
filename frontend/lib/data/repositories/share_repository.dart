import '../../clipback_api.dart';
import '../services/native_share_service.dart';

class PendingShareDraft {
  const PendingShareDraft({required this.id, required this.label, this.userId});
  final String id;
  final String label;
  final int? userId;
}

class ShareReceipt {
  const ShareReceipt({required this.id, required this.userId});
  final String id;
  final int userId;
}

class NativeShareState {
  const NativeShareState({
    this.revision = 0,
    this.drafts = const [],
    this.receipts = const [],
  });
  final int revision;
  final List<PendingShareDraft> drafts;
  final List<ShareReceipt> receipts;
}

/// A facade, not another durable copy of the platform share queue.
class ShareRepository {
  ShareRepository(this._api, this._native);
  final ClipbackApi _api;
  final NativeShareService _native;

  bool get supported => _native.enabled;
  Object? get sessionIdentity => _api.session;
  Object? preparedSessionIdentity;

  Future<NativeShareState> readState() async {
    final state = await _native.invoke<Map>('getState');
    if (state == null) return const NativeShareState();
    return NativeShareState(
      revision: (state['revision'] as num).toInt(),
      drafts: [
        for (final raw in (state['drafts'] as List? ?? const []))
          PendingShareDraft(
            id: (raw as Map)['id'] as String,
            label: raw['label'] as String? ?? '공유 항목',
            userId: (raw['userId'] as num?)?.toInt(),
          ),
      ],
      receipts: [
        for (final raw in (state['receipts'] as List? ?? const []))
          ShareReceipt(
            id: (raw as Map)['id'] as String,
            userId: (raw['userId'] as num).toInt(),
          ),
      ],
    );
  }

  Future<int> blockCredential() async =>
      await _native.invoke<int>('blockCredential') ?? 0;

  Future<bool> prepare({
    required int revision,
    required int userId,
    required String accountLabel,
    required bool Function() isCurrent,
  }) async {
    if (!supported || !isCurrent()) return false;
    final startedWith = sessionIdentity;
    final credential = await _api.createShareCredential();
    if (!isCurrent() || credential.userId != userId) return false;
    Future<bool> publish(int targetRevision) async =>
        await _native.invoke<bool>('publishCredential', {
          'revision': targetRevision,
          'token': credential.token,
          'expiresAt': credential.expiresAt.toUtc().toIso8601String(),
          'userId': credential.userId,
          'sessionId': credential.sessionId,
          'accountLabel': accountLabel,
          'apiBaseUrl': _api.baseUrl,
        }) ??
        false;
    void remember() =>
        preparedSessionIdentity = credential.sessionIdentity ?? startedWith;
    if (await publish(revision)) {
      remember();
      return true;
    }
    if (!isCurrent()) return false;
    final latest = await _native.invoke<Map>('getState');
    if (!isCurrent() || latest?['revision'] != revision) return false;
    final existing = latest?['credential'] as Map?;
    if (existing != null &&
        existing['userId'] == credential.userId &&
        existing['sessionId'] == credential.sessionId &&
        (existing['apiBaseUrl'] as String? ?? '').replaceAll(
              RegExp(r'/+$'),
              '',
            ) ==
            _api.baseUrl.replaceAll(RegExp(r'/+$'), '')) {
      // Another refresh may already have published a newer token for this session.
      final expiry = DateTime.tryParse(existing['expiresAt'] as String? ?? '');
      if (expiry != null &&
          expiry.isAfter(DateTime.now()) &&
          !expiry.isBefore(credential.expiresAt)) {
        remember();
        return true;
      }
      return false;
    }
    // A restored main session can differ from a retained native credential
    // (e.g. restored app data). Replace it through the same durable barrier.
    final replacementRevision = await blockCredential();
    if (!isCurrent()) return false;
    final accepted = await publish(replacementRevision);
    if (accepted) remember();
    return accepted;
  }

  Future<void> present(String id) =>
      _native.invoke<void>('presentDraft', {'id': id});

  Future<void> acknowledge(List<String> ids) =>
      _native.invoke<void>('acknowledgeReceipts', {'ids': ids});
}

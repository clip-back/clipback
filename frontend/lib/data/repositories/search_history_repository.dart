import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/search_history_storage.dart';

List<String> normalizeSearchHistory(Iterable<String> terms) {
  final result = <String>[];
  for (final value in terms) {
    final term = value.trim();
    if (term.isNotEmpty && !result.contains(term)) result.add(term);
    if (result.length == 5) break;
  }
  return result;
}

class _Edit {
  const _Edit(this.term, {this.remove = false});
  final String term;
  final bool remove;
  List<String> apply(List<String> values) => normalizeSearchHistory([
    if (!remove) term,
    ...values.where((value) => value != term),
  ]);
}

class _AccountHistory {
  _AccountHistory(this.id);
  final int id;
  List<String> terms = [];
  final pending = <_Edit>[];
  bool loaded = false, readFailed = false, dirty = false;
  int revision = 0;
  Future<void>? job;
}

class _Binding {
  _Binding(this.generation);
  final int generation;
  _AccountHistory? account;
  final pending = <_Edit>[];
  List<String> terms = [];
  bool opened = false;
}

/// Account-owned local history, independent of the content/search feed cache.
class SearchHistoryRepository extends ChangeNotifier {
  SearchHistoryRepository({required this.storage, required this.environment});
  final SearchHistoryStorage storage;
  final String environment;
  final _accounts = <int, _AccountHistory>{};
  _Binding? _binding;
  bool _disposed = false;

  Object? get owner => _binding;
  List<String> get terms => List.unmodifiable(
    _binding?.account?.terms ?? _binding?.terms ?? const <String>[],
  );

  void bind({required int generation, required bool active, int? userId}) {
    if (_disposed) return;
    if (!active) {
      if (_binding != null) {
        _binding = null;
        notifyListeners();
      }
      return;
    }
    var binding = _binding;
    if (binding == null ||
        binding.generation != generation ||
        (binding.account != null && binding.account!.id != userId)) {
      binding = _Binding(generation);
      _binding = binding;
    } else if (binding.account?.id == userId) {
      return;
    }
    if (userId != null) {
      final account = _accounts.putIfAbsent(
        userId,
        () => _AccountHistory(userId),
      );
      binding.account = account;
      for (final edit in binding.pending) {
        _editAccount(account, edit);
      }
      binding.pending.clear();
      if (binding.opened) _start(account, retryRead: true);
    }
    notifyListeners();
  }

  bool owns(Object? owner) =>
      !_disposed && owner != null && identical(owner, _binding);

  void open() {
    final binding = _binding;
    if (_disposed || binding == null) return;
    binding.opened = true;
    final account = binding.account;
    if (account != null && !account.loaded) _start(account, retryRead: true);
  }

  void record(String value) {
    final term = value.trim();
    if (term.isNotEmpty) _edit(_Edit(term));
  }

  void remove(String term) => _edit(_Edit(term, remove: true));

  void _edit(_Edit edit) {
    final binding = _binding;
    if (_disposed || binding == null) return;
    final account = binding.account;
    if (account == null) {
      binding.pending.add(edit);
      binding.terms = edit.apply(binding.terms);
    } else {
      _editAccount(account, edit);
      _start(account);
    }
    notifyListeners();
  }

  void _editAccount(_AccountHistory account, _Edit edit) {
    account.terms = edit.apply(account.terms);
    if (!account.loaded) account.pending.add(edit);
    account.dirty = true;
    account.revision++;
  }

  void _start(_AccountHistory account, {bool retryRead = false}) {
    if (account.job != null || (account.readFailed && !retryRead)) return;
    final job = _process(account);
    account.job = job;
    unawaited(job.whenComplete(() => account.job = null));
  }

  Future<void> _process(_AccountHistory account) async {
    if (!account.loaded) {
      List<String> stored;
      try {
        stored = await storage.read(environment, account.id);
      } catch (_) {
        account.readFailed = true;
        return;
      }
      account.readFailed = false;
      account.terms = normalizeSearchHistory(stored);
      for (final edit in account.pending) {
        account.terms = edit.apply(account.terms);
      }
      account.pending.clear();
      account.loaded = true;
      if (!_disposed && identical(_binding?.account, account)) {
        notifyListeners();
      }
    }
    while (account.dirty) {
      final revision = account.revision;
      final snapshot = List<String>.of(account.terms);
      try {
        await storage.write(environment, account.id, snapshot);
      } catch (_) {
        return;
      }
      account.dirty = revision != account.revision;
    }
  }

  /// Wait for accepted work without introducing retries or starting new reads.
  Future<void> settle() async {
    while (true) {
      final jobs = _accounts.values
          .map((a) => a.job)
          .whereType<Future<void>>()
          .toList();
      if (jobs.isEmpty) return;
      await Future.wait(jobs);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _binding = null;
    // Accepted writes keep their captured account, but never notify a dead UI.
    super.dispose();
  }
}

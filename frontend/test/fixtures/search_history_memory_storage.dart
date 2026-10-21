import 'package:clipback_frontend/data/services/search_history_storage.dart';

/// Explicit visual-fixture data. Never uses the platform preference store.
class SearchHistoryMemoryStorage implements SearchHistoryStorage {
  SearchHistoryMemoryStorage({this.initialTerms = const []});
  final List<String> initialTerms;
  final _values = <(String, int), List<String>>{};

  @override
  Future<List<String>> read(String environment, int userId) async =>
      List.of(_values[(environment, userId)] ?? initialTerms);

  @override
  Future<void> write(String environment, int userId, List<String> terms) async {
    _values[(environment, userId)] = List.of(terms);
  }
}

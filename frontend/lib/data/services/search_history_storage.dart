import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SearchHistoryStorage {
  Future<List<String>> read(String environment, int userId);
  Future<void> write(String environment, int userId, List<String> terms);
}

class PreferencesSearchHistoryStorage implements SearchHistoryStorage {
  PreferencesSearchHistoryStorage({
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferences;
  String _key(String environment, int userId) =>
      'clipback.search_history.v1.${Uri.encodeComponent(environment)}.$userId';

  @override
  Future<List<String>> read(String environment, int userId) async {
    final value = (await _preferences()).get(_key(environment, userId));
    // Malformed history is not an authentication/storage failure. Only this
    // account's next explicit edit replaces it; never clear other preferences.
    return value is List ? value.whereType<String>().toList() : const [];
  }

  @override
  Future<void> write(String environment, int userId, List<String> terms) async {
    if (!await (await _preferences()).setStringList(
      _key(environment, userId),
      List.of(terms),
    )) {
      throw StateError('Could not persist search history');
    }
  }
}

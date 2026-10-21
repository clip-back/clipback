import 'package:clipback_frontend/data/services/search_history_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('persists separate environment and user namespaces', () async {
    final s = PreferencesSearchHistoryStorage();
    await s.write('https://a/api', 1, ['one']);
    await s.write('https://b/api', 1, ['other']);
    await s.write('https://a/api', 2, ['two']);
    final next = PreferencesSearchHistoryStorage();
    expect(await next.read('https://a/api', 1), ['one']);
    expect(await next.read('https://a/api', 2), ['two']);
    expect(await next.read('https://b/api', 1), ['other']);
    expect(await next.read('https://a/api', 3), isEmpty);
  });
  test('empty deletion persists without touching session keys', () async {
    final p = await SharedPreferences.getInstance();
    await p.setString('clipback.session', 'fixture-session');
    final s = PreferencesSearchHistoryStorage();
    await s.write('test', 1, ['one']);
    await s.write('test', 1, []);
    expect(await s.read('test', 1), isEmpty);
    expect(p.getString('clipback.session'), 'fixture-session');
  });
  test(
    'malformed stored value is treated as empty, not eagerly removed',
    () async {
      final p = await SharedPreferences.getInstance();
      await p.setString('clipback.search_history.v1.test.1', 'bad history');
      final s = PreferencesSearchHistoryStorage();
      expect(await s.read('test', 1), isEmpty);
      expect(p.getString('clipback.search_history.v1.test.1'), 'bad history');
      await s.write('test', 1, ['new']);
      expect(await s.read('test', 1), ['new']);
    },
  );
  test('storage provider failures are observable by repository', () async {
    final s = PreferencesSearchHistoryStorage(
      preferences: () async => throw StateError('unavailable'),
    );
    await expectLater(s.read('test', 1), throwsStateError);
    await expectLater(s.write('test', 1, ['new']), throwsStateError);
  });
}

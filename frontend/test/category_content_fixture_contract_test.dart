import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures/category_content_fixture.dart';

void main() {
  test('F01 server favorite partitions are disjoint and complete', () async {
    final s = CategoryContentServer();
    Future<List<Map>> read(bool favorite) async {
      final r = await s.client.get(
        Uri.parse(
          'https://fixture.invalid/api/v1/feed?category_id=101&is_favorite=$favorite',
        ),
      );
      return ((jsonDecode(r.body) as Map)['items'] as List).cast<Map>();
    }

    final favorite = await read(true), ordinary = await read(false);
    expect(favorite.every((r) => r['is_favorite'] == true), isTrue);
    expect(ordinary.every((r) => r['is_favorite'] == false), isTrue);
    expect(
      {...favorite.map((r) => r['id']), ...ordinary.map((r) => r['id'])}.length,
      6,
    );
  });
  test(
    'F01 native fixture uses opaque pages with exact selected memberships',
    () async {
      final s = CategoryContentServer();
      final first =
          jsonDecode(
                (await s.client.get(
                  Uri.parse(
                    'https://fixture.invalid/api/v1/feed?category_id=101',
                  ),
                )).body,
              )
              as Map;
      expect((first['items'] as List).length, 5);
      expect(first['next_cursor'], '5');
      final last =
          jsonDecode(
                (await s.client.get(
                  Uri.parse(
                    'https://fixture.invalid/api/v1/feed?category_id=101&cursor=5',
                  ),
                )).body,
              )
              as Map;
      expect((last['items'] as List).length, 1);
      expect(last['next_cursor'], isNull);
      for (final r in [...first['items'], ...last['items']]) {
        expect((r['categories'] as List).any((c) => c['id'] == 101), isTrue);
      }
    },
  );
}

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'support/original_link_preview.dart';

void main() {
  test(
    'frozen original-link API fixture forwards requests and preserves source URL',
    () async {
      final server = OriginalLinkPreviewServer()..reset('link');
      addTearDown(server.previewClient.close);
      addTearDown(server.client.close);
      final categories = await server.previewClient.get(
        Uri.parse('https://fixture.invalid/api/v1/categories'),
      );
      expect(categories.statusCode, 200);
      final feed = await server.previewClient.get(
        Uri.parse('https://fixture.invalid/api/v1/feed'),
      );
      final data = jsonDecode(feed.body) as Map;
      expect((data['items'] as List).first['original_url'], originalPreviewUrl);
      expect(server.unexpected, isEmpty);
    },
  );
}

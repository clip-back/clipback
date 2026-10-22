import 'package:clipback_frontend/features/search/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('fresh search has no fabricated history', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: SearchScreen(
          initialQuery: '',
          contents: const [],
          bookmarkedIds: const {},
          categories: const [],
          onSearch: (_) async => [],
          onQueryChanged: (_) {},
          onClose: () {},
          onOpenContent: (_) {},
          onToggleBookmark: (_) {},
          onChangeContentCategory: (_, _) {},
          onDeleteContent: (_) {},
          onOpenArchive: () {},
        ),
      ),
    );
    expect(find.byType(SearchHistoryRow), findsNothing);
  });
}

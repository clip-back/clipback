import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';

class FeedStatus extends StatelessWidget {
  const FeedStatus({required this.page, this.onRetry, super.key});

  final FeedPage page;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (page.loading || (!page.initialized && page.error == null)) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (page.error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            page.items.isEmpty ? '콘텐츠를 불러오지 못했어요.' : '콘텐츠를 더 불러오지 못했어요.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.subtle, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: Text(page.invalidCursor ? '처음부터 다시 불러오기' : '다시 시도'),
          ),
        ],
      ),
    );
  }
}

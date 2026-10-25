import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/shared/category/category_colors.dart';
import 'package:clipback_frontend/shared/content/source_label.dart';
import 'package:clipback_frontend/shared/models/app_user.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';

CategoryItem categoryFromApi(ApiCategory category, {String? mutationLabel}) {
  final color = _colorFromHex(category.color) ?? AppColors.subSubtle;
  return CategoryItem(
    id: category.id,
    name: category.name == '미분류' ? catUncategorized.name : category.name,
    color: color,
    tint: color.withValues(alpha: 0.2),
    deep: deepCategoryColor(color),
    contentCount: category.contentCount,
    rawLastSavedAt: category.lastSavedAt,
    lastSavedAt: category.lastSavedAt == null
        ? null
        : _formatSavedAt(category.lastSavedAt!),
    mutationLabel: mutationLabel,
  );
}

/// Projects reconciled repository data without applying another mutation layer.
ContentItem contentFromApi(
  ApiContent content,
  Map<int, CategoryItem> categoryById, {
  CategoryItem? uncategorized,
  String? mutationLabel,
}) {
  final categories = content.categories
      .map((category) => categoryById[category.id] ?? categoryFromApi(category))
      .toList();
  if (categories.isEmpty) categories.add(uncategorized ?? catUncategorized);
  return ContentItem(
    id: 'api-${content.id}',
    apiId: content.id,
    title: content.title.isEmpty ? '제목을 추출하지 못한 링크' : content.title,
    summary: content.summary,
    category: categories.first,
    categories: List.unmodifiable(categories),
    savedAt: _formatShortDate(content.savedAt),
    savedAtFull: _formatSavedAt(content.savedAt),
    savedAtFullShort: _formatSavedAtShort(content.savedAt),
    tags: content.tags,
    source: sourceLabel(content.source),
    originalUrl: content.originalUrl ?? '',
    originalText: content.summary,
    bookmarked: content.isFavorite,
    isScreenshot: content.contentType == 'screenshot',
    assets: List.unmodifiable(content.assets),
    summaryStatus: content.summaryStatus,
    mutationLabel: mutationLabel,
  );
}

AppUser userFromApi(ApiUser? user, ApiUserStats? stats) {
  final provider = user == null
      ? defaultUser.providerLabel
      : user.isGuest
      ? '게스트 계정'
      : user.linkedProviders.isEmpty
      ? '연동된 계정 없음'
      : '${user.linkedProviders.join(', ')} 계정 연동 중';
  return AppUser(
    name: user?.displayName ?? defaultUser.name,
    providerLabel: provider,
    joinedAt: user == null
        ? defaultUser.joinedAt
        : _formatJoinedAt(user.createdAt),
    savedContentCount: stats?.savedCount,
    revisitedContentCount: stats?.reopenedCount,
    appVersion: defaultUser.appVersion,
  );
}

Color? _colorFromHex(String? value) {
  if (value == null) return null;
  final hex = value.replaceFirst('#', '');
  if (hex.length != 6) return null;
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : Color(0xFF000000 | parsed);
}

String hexFromColor(Color color) {
  String value(int channel) => channel.toRadixString(16).padLeft(2, '0');
  final argb = color.toARGB32();
  return '#${value((argb >> 16) & 0xFF)}'
      '${value((argb >> 8) & 0xFF)}${value(argb & 0xFF)}';
}

String _formatShortDate(DateTime dateTime) {
  final year = (dateTime.year % 100).toString().padLeft(2, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  return '$year.$month.$day';
}

String _formatJoinedAt(DateTime dateTime) {
  return '${dateTime.year}. ${dateTime.month.toString().padLeft(2, '0')}. '
      '${dateTime.day.toString().padLeft(2, '0')}';
}

String _formatSavedAt(DateTime dateTime) {
  final hour = dateTime.hour;
  final period = hour < 12 ? '오전' : '오후';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '${dateTime.year}. ${dateTime.month.toString().padLeft(2, '0')}. '
      '${dateTime.day.toString().padLeft(2, '0')} $period '
      '${displayHour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
}

String _formatSavedAtShort(DateTime dateTime) {
  return '${dateTime.year}. ${dateTime.month.toString().padLeft(2, '0')}. '
      '${dateTime.day.toString().padLeft(2, '0')} '
      '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
}

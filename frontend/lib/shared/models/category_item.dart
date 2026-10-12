import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CategoryItem {
  const CategoryItem({
    this.id,
    this.lastSavedAt,
    this.contentCount = 0,
    this.rawLastSavedAt,
    this.mutationLabel,
    required this.name,
    required this.color,
    required this.tint,
    required this.deep,
  });

  final int? id;
  final String? lastSavedAt;
  final int contentCount;
  final DateTime? rawLastSavedAt;
  final String name;
  final Color color;
  final Color tint;
  final Color deep;
  final String? mutationLabel;
  bool get isDeleting => mutationLabel == '삭제 중…';

  CategoryItem copyWith({
    String? name,
    Color? color,
    Color? tint,
    Color? deep,
    String? mutationLabel,
    bool clearMutationLabel = false,
  }) => CategoryItem(
    id: id,
    lastSavedAt: lastSavedAt,
    contentCount: contentCount,
    rawLastSavedAt: rawLastSavedAt,
    name: name ?? this.name,
    color: color ?? this.color,
    tint: tint ?? this.tint,
    deep: deep ?? this.deep,
    mutationLabel: clearMutationLabel
        ? null
        : mutationLabel ?? this.mutationLabel,
  );
}

const catUncategorized = CategoryItem(
  name: '분류가 필요한 콘텐츠',
  color: Color(0xFFB5BDC3),
  tint: Color(0xFFE9ECEF),
  deep: Color(0xFF626C73),
);

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Color deepCategoryColor(Color color) {
  return Color.fromARGB(
    255,
    (color.r * 0.72).round(),
    (color.g * 0.72).round(),
    (color.b * 0.72).round(),
  );
}

/// 앱 팔레트 1–6번 색의 배지 짝(연한, 진한): Figma "카테고리 색상 코드"
/// `428:4712` 같은 칸의 3줄·2줄 값(#414).
const _figmaBadgePairs = <int, (Color, Color)>{
  0xFFFF6277: (Color(0xFFFFE0E4), Color(0xFFBC4858)),
  0xFFFFA24B: (Color(0xFFFFDAB2), Color(0xFFD0802A)),
  0xFFFFD75C: (Color(0xFFFFF3CE), Color(0xFFC5A544)),
  0xFF5BD89D: (Color(0xFFE0F8EF), Color(0xFF45A27D)),
  0xFF64B5F6: (Color(0xFFE2F1FF), Color(0xFF4676A4)),
  0xFFB9AAFF: (Color(0xFFDCD3FF), Color(0xFF927EDD)),
};

/// 카테고리 색의 배지 배경(연한)·글자(진한) 색. 짝이 없는 색은 기존 계산을 쓴다.
({Color tint, Color deep}) categoryBadgeColors(Color color) {
  final pair = _figmaBadgePairs[color.toARGB32()];
  if (pair != null) return (tint: pair.$1, deep: pair.$2);
  return (tint: color.withValues(alpha: 0.2), deep: deepCategoryColor(color));
}

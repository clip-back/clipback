import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const catProduct = CategoryItem(
  name: '제품추천',
  color: Color(0xFFB48CFF),
  tint: Color(0xFFDDCEFF),
  deep: Color(0xFF6145A2),
);

const catJapan = CategoryItem(
  name: '일본여행',
  color: Color(0xFFFF5F78),
  tint: Color(0xFFFFE0E4),
  deep: Color(0xFFBC4858),
);

const catSelfGrowth = CategoryItem(
  name: '자기개발',
  color: Color(0xFF64B5F6),
  tint: Color(0xFFE2F1FF),
  deep: Color(0xFF4676A4),
);

const catLife = CategoryItem(
  name: '생활',
  color: Color(0xFF5BD89D),
  tint: Color(0x80C1F1DE),
  deep: Color(0xFF45A27D),
);

const catLifeInfo = CategoryItem(
  name: '생활정보',
  color: Color(0xFFFFA9BD),
  tint: Color(0xFFFFE0E4),
  deep: Color(0xFFBC4858),
);

const catToWatch = CategoryItem(
  name: '봐야할 것',
  color: Color(0xFFFF5F78),
  tint: Color(0xFFFFE0E4),
  deep: Color(0xFFBC4858),
);

const catDiet = CategoryItem(
  name: '다이어트',
  color: Color(0xFFFFD75C),
  tint: Color(0xFFFFF0BA),
  deep: Color(0xFF856B00),
);

const catJob = CategoryItem(
  name: '취업준비',
  color: Color(0xFF64B5F6),
  tint: Color(0xFFE2F1FF),
  deep: Color(0xFF4676A4),
);

const catBeauty = CategoryItem(
  name: '뷰티/패션',
  color: Color(0xFFFF8CB4),
  tint: Color(0xFFFFE4EE),
  deep: Color(0xFFB84B72),
);

const catKnowledge = CategoryItem(
  name: '인문/지식',
  color: Color(0xFF8C7BFF),
  tint: Color(0xFFE7E3FF),
  deep: Color(0xFF5144A6),
);

const catEconomy = CategoryItem(
  name: '경제/시사',
  color: Color(0xFF4DB6AC),
  tint: Color(0xFFDDF4F1),
  deep: Color(0xFF2E817A),
);

const initialCategories = [
  catJob,
  catBeauty,
  catJapan,
  catKnowledge,
  catSelfGrowth,
  catEconomy,
  catLife,
  catLifeInfo,
  catToWatch,
  catDiet,
  catProduct,
  catUncategorized,
];

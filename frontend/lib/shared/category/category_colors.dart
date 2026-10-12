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

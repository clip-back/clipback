import 'package:flutter/material.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';

enum CategorySaveStatus { succeeded, rejected, unconfirmed, stale }

enum CategorySaveRejection { nameExists, inputInvalid, targetMissing, other }

class CategorySaveResult {
  const CategorySaveResult(this.status, this.submissionKey, {this.rejection});

  final CategorySaveStatus status;
  final String submissionKey;
  final CategorySaveRejection? rejection;
}

typedef CategorySubmitCallback =
    Future<CategorySaveResult> Function({
      required String name,
      required Color color,
      String? submissionKey,
    });

typedef CategoryUpdateSubmitCallback =
    Future<CategorySaveResult> Function(
      CategoryItem category, {
      required String name,
      required Color color,
      String? submissionKey,
    });

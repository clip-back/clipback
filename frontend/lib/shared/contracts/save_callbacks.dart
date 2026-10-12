import 'dart:async';

import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:flutter/services.dart';

typedef SaveLinkCallback =
    Future<ContentItem> Function({required String url, CategoryItem? category});

typedef SaveScreenshotCallback =
    Future<ContentItem> Function({
      required Uint8List bytes,
      required String filename,
      CategoryItem? category,
    });

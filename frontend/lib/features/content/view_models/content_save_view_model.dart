import 'dart:typed_data';

import 'package:clipback_frontend/app/actions/content_actions.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/shared/contracts/ui_effect.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/presentation/content_view_model.dart';

class ContentSaveViewModel extends ContentViewModel {
  ContentSaveViewModel(super.repository, this.actions);
  final ContentActions actions;

  Future<ContentItem> addLink({
    required String url,
    CategoryItem? category,
  }) async {
    ContentItem? saved;
    final response = await actions.saveLink(
      url: url,
      categoryId: category?.id,
      onSaved: (item) {
        saved = present(item);
        emitEffect(SavedContentEffect(item.id));
      },
      feedback: emitEffect,
    );
    return saved ?? present(response);
  }

  Future<ContentItem> addScreenshot({
    required Uint8List bytes,
    required String filename,
    CategoryItem? category,
  }) async {
    ContentItem? saved;
    final response = await actions.saveScreenshot(
      bytes: bytes,
      filename: filename,
      categoryId: category?.id,
      onSaved: (ApiContent item) {
        saved = present(item);
        emitEffect(SavedContentEffect(item.id));
      },
      feedback: emitEffect,
    );
    return saved ?? present(response);
  }
}

import 'dart:async';
import 'dart:typed_data';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/models/content_state.dart';
import 'package:clipback_frontend/data/repositories/content_repository.dart';
import 'package:clipback_frontend/data/repositories/session_repository.dart';
import 'package:clipback_frontend/data/repositories/user_repository.dart';
import 'package:clipback_frontend/data/services/api_request_scope.dart';
import 'package:clipback_frontend/shared/contracts/category_submission.dart';
import 'package:clipback_frontend/shared/contracts/ui_effect.dart';

typedef ContentFeedback = void Function(UiEffect effect);

/// Coordinates committed writes and their follow-up reads without owning UI.
class ContentActions {
  ContentActions(this.content, this.users, this.session);

  final ContentRepository content;
  final UserRepository users;
  final SessionRepository session;
  bool _disposed = false;

  void dispose() => _disposed = true;

  bool _current(int generation) =>
      !_disposed && generation == content.accountVersion;

  Future<bool> refreshExternal() async {
    if (_disposed) return false;
    final ticket = content.beginRefresh(preserveViewport: true);
    final result = await content.refresh(ticket);
    bool current() => !_disposed && content.isCurrentRefresh(ticket);
    if (!current() ||
        !result.current ||
        result.metadataFailed ||
        ticket.feedVersions.keys.any(
          (key) => content.feed(key).error != null,
        )) {
      return false;
    }
    // A failed follow-up read leaves the native receipt available for retry.
    await users.refresh(isCurrent: current);
    return current();
  }

  Future<void> refresh(ContentFeedback feedback) async {
    if (_disposed) return;
    final ticket = content.beginRefresh();
    final result = await content.refresh(ticket);
    if (_disposed || !result.current || !content.isCurrentRefresh(ticket)) {
      return;
    }
    if (result.categoryDetailsRequired && result.metadataFailed) {
      feedback(
        MessageEffect(
          '최신 정보를 불러오지 못했어요.',
          retryLabel: '다시 불러오기',
          retry: () {
            if (_current(ticket.accountVersion)) {
              unawaited(refresh(feedback));
            }
          },
        ),
      );
    }
    if (_disposed || !content.isCurrentRefresh(ticket)) return;
    try {
      await users.refresh(
        isCurrent: () => !_disposed && content.isCurrentRefresh(ticket),
      );
    } catch (_) {
      // A committed content action remains successful if statistics fail.
    }
  }

  Future<void> _changeContent(
    ContentMutationHandle? mutation,
    ContentFeedback feedback,
  ) async {
    if (mutation == null) return;
    try {
      if (!_current(mutation.accountVersion)) return;
      final result = await content.executeContentMutation(mutation);
      if (!_current(mutation.accountVersion) || result.stale) return;
      if (!result.succeeded) {
        feedback(
          MessageEffect(
            _message(result.error, '콘텐츠 변경을 완료하지 못했어요. 다시 시도해 주세요.'),
          ),
        );
        return;
      }
      await refresh(feedback);
    } finally {
      content.finishContentMutation(mutation);
    }
  }

  Future<void> toggleBookmark(int id, ContentFeedback feedback) async {
    if (_disposed) return;
    await _changeContent(content.beginBookmark(id), feedback);
  }

  Future<void> changeCategory(
    int id,
    int categoryId,
    ContentFeedback feedback,
  ) async {
    if (_disposed) return;
    await _changeContent(
      content.beginContentCategoryChange(id, categoryId),
      feedback,
    );
  }

  Future<void> deleteContent(int id, ContentFeedback feedback) async {
    if (_disposed) return;
    await _changeContent(content.beginContentDelete(id), feedback);
  }

  Future<void> createCategory({
    required String name,
    required String color,
    required ContentFeedback feedback,
  }) async {
    if (_disposed) return;
    final generation = content.accountVersion;
    try {
      await content.createCategory(name: name, color: color);
    } catch (error) {
      if (_current(generation)) {
        feedback(MessageEffect(_message(error, '카테고리를 만들지 못했어요. 다시 시도해 주세요.')));
      }
    }
  }

  Future<CategorySaveResult> submitCategoryCreate({
    required String name,
    required String color,
    required String submissionKey,
  }) async {
    final generation = content.accountVersion;
    final scope = ApiRequestScope(
      timeout: const Duration(seconds: 10),
      isCurrent: () => _current(generation),
    );
    try {
      final created = await scope.run(
        () => scope.wait(
          content.createCategory(
            name: name,
            color: color,
            submissionKey: submissionKey,
          ),
        ),
      );
      if (!_current(generation) || created == null) {
        return CategorySaveResult(CategorySaveStatus.stale, submissionKey);
      }
      unawaited(
        Future<void>(() async {
          if (!_current(generation)) return;
          final read = ApiRequestScope(
            timeout: const Duration(seconds: 10),
            isCurrent: () => _current(generation),
          );
          try {
            await read.run(() => read.wait(content.loadCategories()));
          } catch (_) {
            // A committed submission stays successful if the later read fails.
          } finally {
            read.cancel();
          }
        }),
      );
      return CategorySaveResult(CategorySaveStatus.succeeded, submissionKey);
    } on CategorySubmissionRejected catch (error) {
      if (!_current(generation)) {
        return CategorySaveResult(CategorySaveStatus.stale, submissionKey);
      }
      return CategorySaveResult(
        CategorySaveStatus.rejected,
        submissionKey,
        rejection: switch (error.code) {
          'category_name_exists' => CategorySaveRejection.nameExists,
          'category_input_invalid' => CategorySaveRejection.inputInvalid,
          'category_target_missing' => CategorySaveRejection.targetMissing,
          _ => CategorySaveRejection.other,
        },
      );
    } catch (_) {
      return CategorySaveResult(
        _current(generation)
            ? CategorySaveStatus.unconfirmed
            : CategorySaveStatus.stale,
        submissionKey,
      );
    } finally {
      scope.cancel();
    }
  }

  Future<void> updateCategory(
    int id, {
    required String name,
    required String color,
    required ContentFeedback feedback,
  }) async {
    if (_disposed) return;
    await _changeCategory(
      content.beginCategoryUpdate(id, name: name, color: color),
      feedback,
    );
  }

  Future<void> deleteCategory(int id, ContentFeedback feedback) async {
    if (_disposed) return;
    await _changeCategory(content.beginCategoryDelete(id), feedback);
  }

  Future<void> _changeCategory(
    CategoryMutationHandle? mutation,
    ContentFeedback feedback,
  ) async {
    if (mutation == null) return;
    try {
      if (!_current(mutation.accountVersion)) return;
      final result = await content.executeCategoryMutation(mutation);
      if (!_current(mutation.accountVersion) || result.stale) return;
      if (!result.succeeded) {
        feedback(
          MessageEffect(
            _message(
              result.error,
              mutation.deleting
                  ? '카테고리를 삭제하지 못했어요. 다시 시도해 주세요.'
                  : '카테고리를 수정하지 못했어요. 다시 시도해 주세요.',
            ),
          ),
        );
        return;
      }
      await refresh(feedback);
    } finally {
      content.finishCategoryMutation(mutation);
    }
  }

  Future<void> _requireSession() async {
    if (_disposed) {
      throw const ClipbackApiException('계정이 변경되어 저장 결과를 표시하지 못했어요.');
    }
    if (session.authenticationBusy) {
      throw const ClipbackApiException('계정 변경이 끝난 뒤 다시 시도해 주세요.');
    }
    if (!session.hasSession) {
      throw const ClipbackApiException('로그인하거나 게스트로 시작해 주세요.');
    }
  }

  Future<ApiContent> saveLink({
    required String url,
    int? categoryId,
    required void Function(ApiContent) onSaved,
    required ContentFeedback feedback,
  }) async {
    await _requireSession();
    if (_disposed) {
      throw const ClipbackApiException('계정이 변경되어 저장 결과를 표시하지 못했어요.');
    }
    final generation = content.accountVersion;
    final item = await content.saveLink(url: url, categoryId: categoryId);
    if (!_current(generation)) return item;
    content.insertSavedContent(item);
    if (!_current(generation)) return item;
    onSaved(item);
    if (_current(generation)) await refresh(feedback);
    return item;
  }

  Future<ApiContent> saveScreenshot({
    required Uint8List bytes,
    required String filename,
    int? categoryId,
    required void Function(ApiContent) onSaved,
    required ContentFeedback feedback,
  }) async {
    await _requireSession();
    if (_disposed) {
      throw const ClipbackApiException('계정이 변경되어 저장 결과를 표시하지 못했어요.');
    }
    final generation = content.accountVersion;
    final item = await content.saveScreenshot(
      bytes: bytes,
      filename: filename,
      categoryId: categoryId,
    );
    if (!_current(generation)) return item;
    content.insertSavedContent(item);
    if (!_current(generation)) return item;
    onSaved(item);
    if (_current(generation)) await refresh(feedback);
    return item;
  }

  String _message(Object? error, String fallback) =>
      error is ClipbackApiException ? error.message : fallback;
}

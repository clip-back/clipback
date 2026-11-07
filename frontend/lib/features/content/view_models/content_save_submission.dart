import 'dart:async';

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/data/services/api_request_scope.dart';
import 'package:clipback_frontend/data/services/event_uuid.dart';
import 'package:clipback_frontend/shared/contracts/save_callbacks.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:flutter/foundation.dart';

/// What the save screen submitted: a link address or a photo and its name.
class PendingSave {
  const PendingSave.link(this.label) : photoBytes = null;
  const PendingSave.photo(this.label, Uint8List bytes) : photoBytes = bytes;

  final String label;
  final Uint8List? photoBytes;
  bool get isLink => photoBytes == null;
}

/// A finished save: the saved content and what was submitted.
class SavedSave {
  const SavedSave(this.content, this.submission);

  final ContentItem content;
  final PendingSave submission;
}

/// Submission state of one save sheet. Create it when the sheet opens and
/// dispose it when the sheet closes.
class ContentSaveSubmission extends ChangeNotifier {
  ContentSaveSubmission({
    required SaveLinkCallback onAddLink,
    required SaveScreenshotCallback onAddScreenshot,
  }) : _onAddLink = onAddLink,
       _onAddScreenshot = onAddScreenshot;

  static const _defaultError = '저장하지 못했어요. 다시 시도해 주세요.';

  final SaveLinkCallback _onAddLink;
  final SaveScreenshotCallback _onAddScreenshot;
  Uint8List? _selectedPhotoBytes;
  String? _photoKey;
  ApiRequestScope? _photoRequest;
  var _isSaving = false;
  PendingSave? _pending;
  SavedSave? _saved;
  var _disposed = false;

  bool get isSaving => _isSaving;
  PendingSave? get pending => _pending;
  SavedSave? get saved => _saved;

  /// A different photo gets a new submission key on its next submit.
  void photoSelected(Uint8List bytes) {
    if (!listEquals(_selectedPhotoBytes, bytes)) _photoKey = null;
    _selectedPhotoBytes = bytes;
  }

  /// Returns the message to show when saving fails, otherwise null.
  Future<String?> submitLink(String url) =>
      _submit(PendingSave.link(url), () => _onAddLink(url: url));

  /// Returns the message to show when saving fails, otherwise null.
  Future<String?> submitPhoto(Uint8List bytes, String filename) =>
      _submit(PendingSave.photo(filename, bytes), () {
        // The API, repository and action read this scope from the zone, so
        // the callback must start inside run.
        final request = _photoRequest = ApiRequestScope();
        return request.run(
          () => _onAddScreenshot(
            bytes: bytes,
            filename: filename,
            submissionKey: _photoKey ??= newEventUuid(),
          ),
        );
      });

  Future<String?> _submit(
    PendingSave submission,
    Future<ContentItem> Function() save,
  ) async {
    if (_saved != null || _isSaving) return null;
    _isSaving = true;
    _pending = submission;
    notifyListeners();
    SavedSave? saved;
    String? error;
    try {
      saved = SavedSave(await save(), submission);
    } on ClipbackApiException catch (exception) {
      error = exception.message;
    } catch (_) {
      error = _defaultError;
    }
    if (_disposed) return null;
    _isSaving = false;
    _pending = null;
    _saved = saved;
    notifyListeners();
    return error;
  }

  @override
  void dispose() {
    _disposed = true;
    _photoRequest?.cancel();
    super.dispose();
  }
}

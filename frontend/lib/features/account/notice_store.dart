import 'package:flutter/foundation.dart';

import 'notices.dart';

/// The last notice list (#486 decision 4): entering the list shows it at once
/// and asks the server; a valid answer replaces it, a failure keeps it quietly.
/// Kept outside the screens, so an answer after a screen or the app is gone
/// is only stored, and one request runs at a time.
class NoticeStore extends ValueNotifier<List<Notice>> {
  NoticeStore(this._fetch) : super(notices);

  final Future<Object?> Function() _fetch;
  bool _loading = false;

  void refresh() {
    if (_loading) return;
    _loading = true;
    _fetch()
        .then((json) => value = noticesFromJson(json))
        .catchError((Object _) => value)
        .whenComplete(() => _loading = false);
  }
}

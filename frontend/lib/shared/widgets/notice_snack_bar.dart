import 'package:flutter/material.dart';

/// Text inset from the notice box's left (Figma C01 428:4569, #407).
const _textStart = 18.0;

/// Text inset above and below in a notice with a button. Figma has no such
/// notice; 7 (one or two lines 62 high) is the 2026-11-17 trial choice
/// "1번으로 한번 볼게", to be settled after the screen review.
const _buttonNoticeVertical = 7.0;

/// A bottom notice (Figma C01 428:4567, #407). The app theme gives the box
/// and text. A notice without a button has the Figma inner spacing (one
/// line 50 high). A notice with a button keeps the Flutter button and its
/// place 8 from the box's right: Flutter puts half the end padding on each
/// side of the button, so end 16/3 leaves 16/3 + 8/3 = 8 as before.
SnackBar noticeSnackBar(String message, {SnackBarAction? action}) => SnackBar(
  content: Text(message),
  padding: action == null
      ? const EdgeInsets.symmetric(horizontal: _textStart, vertical: 16.5)
      : const EdgeInsetsDirectional.fromSTEB(
          _textStart,
          _buttonNoticeVertical,
          16 / 3,
          _buttonNoticeVertical,
        ),
  action: action,
);

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Text inset from the notice box's left (Figma C01 428:4569, #407).
const _textStart = 18.0;

/// Text inset above and below (Figma 428:4568: 50 high for one line of 17).
const _textVertical = 16.5;

/// The notice box's inset from both screen sides (app snackBarTheme).
const _boxInset = 16.0;

/// End padding of a notice with a button: Flutter puts half of it on each
/// side of the button, so 16/3 + 8/3 keeps the button 8 from the box's
/// right as before (#407).
const _buttonEnd = 16 / 3;

/// A bottom notice (Figma C01 428:4567, #407). The app theme gives the box
/// and text. A notice without a button has the Figma inner spacing.
///
/// A notice with a button keeps the Flutter button (48 tap height, 8 from
/// the box's right) and is as high as a notice without one (2026-11-17
/// decision "1번"): the text's height on this screen sets the space above
/// and below the 48 row, so the text is 16.5 from the top and bottom. The
/// text stays a plain Text.
SnackBar noticeSnackBar(
  BuildContext context,
  String message, {
  SnackBarAction? action,
}) => SnackBar(
  content: Text(message),
  padding: action == null
      ? const EdgeInsets.symmetric(
          horizontal: _textStart,
          vertical: _textVertical,
        )
      : _buttonNoticePadding(context, message, action.label),
  // Flutter moves a wide button to a row of its own below the text; the
  // button stays beside the text instead, as measured below (2026-11-17
  // decision "추천대로"). Narrow screens wrap the text into more lines.
  actionOverflowThreshold: action == null ? null : 1,
  action: action,
);

EdgeInsetsGeometry _buttonNoticePadding(
  BuildContext context,
  String message,
  String label,
) {
  final theme = Theme.of(context);
  final scaler = MediaQuery.textScalerOf(context);
  final boxWidth = MediaQuery.sizeOf(context).width - 2 * _boxInset;
  // SnackBarAction is a TextButton with 16 on both sides (min width 64)
  // and 8/3 outside it on both sides.
  final labelPainter = TextPainter(
    text: TextSpan(text: label, style: theme.textTheme.labelLarge),
    textScaler: scaler,
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final buttonWidth = math.max(64.0, labelPainter.width + 32) + _buttonEnd;
  labelPainter.dispose();
  final textPainter = TextPainter(
    text: TextSpan(text: message, style: theme.snackBarTheme.contentTextStyle),
    textScaler: scaler,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: boxWidth - _textStart - _buttonEnd - buttonWidth);
  final textHeight = textPainter.height;
  textPainter.dispose();
  // The row is max(text, 48) high; the box is text + 2 × 16.5.
  final vertical = textHeight >= 48
      ? _textVertical
      : (2 * _textVertical + textHeight - 48) / 2;
  return EdgeInsetsDirectional.fromSTEB(
    _textStart,
    vertical,
    _buttonEnd,
    vertical,
  );
}

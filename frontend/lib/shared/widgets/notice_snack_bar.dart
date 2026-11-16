import 'package:flutter/material.dart';

/// A bottom notice (Figma C01 428:4567, #407). The app theme gives the box
/// and text; a notice without a button keeps the Figma inner spacing (text
/// 18 from the left, one line 50 high). A notice with a button keeps the
/// Flutter default spacing around its button, which Figma does not show.
SnackBar noticeSnackBar(String message, {SnackBarAction? action}) => SnackBar(
  content: Text(message),
  padding: action == null
      ? const EdgeInsets.symmetric(horizontal: 18, vertical: 16.5)
      : null,
  action: action,
);

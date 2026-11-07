import 'dart:ui' show PointerDeviceKind;

import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:flutter/material.dart';

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class PhoneFrame extends StatelessWidget {
  const PhoneFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = appContentWidth(constraints.maxWidth);
          final contentHeight = constraints.hasBoundedHeight
              ? constraints.maxHeight
              : phoneHeight;

          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: contentWidth,
              height: contentHeight,
              child: child,
            ),
          );
        },
      ),
    );
  }
}

import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:flutter/material.dart';

class EntrySurface extends StatelessWidget {
  const EntrySurface({
    required this.backgroundColor,
    required this.children,
    super.key,
  });

  final Color backgroundColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: phoneWidth,
              height: phoneHeight,
              child: Stack(
                children: [
                  const EntryStatusBar(),
                  const EntryHomeIndicator(),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EntryStatusBar extends StatelessWidget {
  const EntryStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: DesignStatusBar(),
    );
  }
}

class EntryHomeIndicator extends StatelessWidget {
  const EntryHomeIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 116,
      bottom: 8,
      width: 144,
      height: 5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.text,
          borderRadius: BorderRadius.circular(100),
        ),
      ),
    );
  }
}

class EntryTagline extends StatelessWidget {
  const EntryTagline({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        '저장한 정보를 다시 볼 순간으로',
        textAlign: TextAlign.center,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          color: color,
          fontFamily: 'RiaSans',
          fontFamilyFallback: const ['Pretendard'],
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 23 / 16,
        ),
      ),
    );
  }
}

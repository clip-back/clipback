import 'package:flutter/material.dart';

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

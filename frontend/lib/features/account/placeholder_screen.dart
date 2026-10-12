import 'package:clipback_frontend/shared/theme/app_text.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:clipback_frontend/shared/widgets/top_bars.dart';
import 'package:flutter/material.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    required this.title,
    required this.activeIndex,
    super.key,
  });

  final String title;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              AppTopBar(title: title),
              const Expanded(
                child: Center(
                  child: Text('준비 중입니다', style: AppText.body16Subtle),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: ClipbackNavigationBar(
          activeIndex: activeIndex,
          onTap: (_) => Navigator.maybePop(context),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/app_layout.dart';
import '../../shared/widgets/buttons.dart';

class SessionRestoreScreen extends StatelessWidget {
  const SessionRestoreScreen({
    required this.errorMessage,
    required this.onRetry,
    super.key,
  });

  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (errorMessage == null) ...[
                    const CircularProgressIndicator(color: AppColors.mainDeep),
                    const SizedBox(height: 24),
                    const Text('저장한 콘텐츠를 불러오는 중이에요.'),
                  ] else ...[
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, height: 1.6),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(label: '다시 시도', onPressed: onRetry),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

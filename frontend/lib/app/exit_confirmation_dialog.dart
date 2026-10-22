import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:flutter/material.dart';

/// User-approved reuse of the existing confirmation surface, without the
/// category deletion illustration, copy or destructive button treatment.
class ExitConfirmationDialog extends StatelessWidget {
  const ExitConfirmationDialog({
    required this.onCancel,
    required this.onExit,
    super.key,
  });

  final VoidCallback onCancel;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppColors.surface,
    constraints: const BoxConstraints(maxWidth: phoneWidth - 64),
    insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: SingleChildScrollView(
      child: Padding(
        key: const ValueKey('exit-confirmation-dialog'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '앱을 종료할까요?',
              textAlign: TextAlign.center,
              style: TextStyle(
                inherit: false,
                fontFamily: 'Pretendard',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -.45,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 36),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('exit-confirmation-cancel'),
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.standard,
                      foregroundColor: AppColors.text,
                      backgroundColor: AppColors.surface,
                      side: const BorderSide(color: AppColors.subtler),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: _buttonText,
                    ),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('exit-confirmation-exit'),
                    onPressed: onExit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.standard,
                      backgroundColor: AppColors.text,
                      foregroundColor: AppColors.main,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: _buttonText,
                    ),
                    child: const Text('종료'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  static const _buttonText = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 22 / 14,
  );
}

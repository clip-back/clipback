import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class _ContentDeleteText {
  static const deleteTitle = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.45,
    color: Colors.black,
  );
  static const deleteBody = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.35,
    color: AppColors.subtle,
    height: 1.6,
  );
  static const deleteButton = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 22 / 14,
  );
}

class ContentDeleteDialog extends StatelessWidget {
  const ContentDeleteDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      constraints: const BoxConstraints(maxWidth: phoneWidth - 64),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        key: const ValueKey('content-delete-viewport'),
        child: Padding(
          key: const ValueKey('content-delete-dialog'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                key: const ValueKey('content-delete-warning'),
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.mainSubtle,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    Assets.categorySheetWarning,
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '콘텐츠를 삭제할까요?',
                key: ValueKey('content-delete-title'),
                style: _ContentDeleteText.deleteTitle,
              ),
              const SizedBox(height: 8),
              Text(
                '아카이브와 즐겨찾기에서도 삭제돼요. 삭제 후 복구할 수 없어요.',
                key: const ValueKey('content-delete-body'),
                textAlign: TextAlign.center,
                style: _ContentDeleteText.deleteBody,
              ),
              const SizedBox(height: 36),
              SizedBox(
                height: 44,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey('content-delete-cancel'),
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.standard,
                          foregroundColor: AppColors.text,
                          backgroundColor: AppColors.surface,
                          side: const BorderSide(color: AppColors.subtler),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: _ContentDeleteText.deleteButton,
                        ),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('content-delete-confirm'),
                        onPressed: () {
                          if (ModalRoute.of(context)!.isCurrent) {
                            Navigator.pop(context, true);
                          }
                        },
                        style: FilledButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.standard,
                          backgroundColor: const Color(0xFFFFDDDD),
                          foregroundColor: const Color(0xFFFF0000),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: _ContentDeleteText.deleteButton,
                        ),
                        child: const Text('삭제'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

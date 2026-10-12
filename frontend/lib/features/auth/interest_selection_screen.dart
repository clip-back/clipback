import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/app_text.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:flutter/material.dart';

class InterestSelectionScreen extends StatefulWidget {
  const InterestSelectionScreen({
    required this.onBack,
    required this.onDone,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onDone;

  @override
  State<InterestSelectionScreen> createState() =>
      _InterestSelectionScreenState();
}

class _InterestSelectionScreenState extends State<InterestSelectionScreen> {
  final Set<String> _selected = {mockInterestOptions.first};

  void _toggle(String option) {
    setState(() {
      if (_selected.contains(option)) {
        _selected.remove(option);
        return;
      }
      if (_selected.length < 3) {
        _selected.add(option);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                left: 6,
                top: 8,
                child: SvgIconButton(
                  asset: Assets.back,
                  onPressed: widget.onBack,
                  size: 24,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 80, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '주로 어떤 정보를\n저장하고 싶으신가요?',
                      style: AppText.title24,
                    ),
                    const SizedBox(height: 8),
                    const Text('최대 3개까지 선택해 주세요.', style: AppText.body16Subtle),
                    const SizedBox(height: 48),
                    for (final option in mockInterestOptions)
                      InterestOptionTile(
                        label: option,
                        selected: _selected.contains(option),
                        onTap: () => _toggle(option),
                      ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: PrimaryButton(
                  label: '완료',
                  onPressed: widget.onDone,
                  color: _selected.isEmpty ? AppColors.faint : AppColors.text,
                  foreground: _selected.isEmpty
                      ? AppColors.subtle
                      : AppColors.main,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InterestOptionTile extends StatelessWidget {
  const InterestOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selected ? AppColors.text : Colors.transparent,
                  shape: BoxShape.circle,
                  border: selected
                      ? null
                      : Border.all(color: AppColors.subtler, width: 1),
                ),
                child: selected
                    ? const Icon(Icons.check, color: AppColors.main, size: 16)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const mockInterestOptions = [
  '직장/자기개발',
  '뷰티/패션',
  '여행/장소',
  '인문/지식',
  '요리/식품',
  '경제/시사',
];

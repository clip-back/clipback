import 'dart:async';
import 'dart:math' as math;

import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/shared/category/category_sheets.dart';
import 'package:clipback_frontend/shared/content/source_label.dart';
import 'package:clipback_frontend/shared/contracts/save_callbacks.dart';
import 'package:clipback_frontend/shared/models/category_item.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/shared/theme/layout.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:clipback_frontend/shared/widgets/sheet_primitives.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

Future<void> showContentSaveScreen({
  required BuildContext context,
  required SaveLinkCallback onAddLink,
  required SaveScreenshotCallback onAddScreenshot,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (context, _, _) =>
        AddContentSheet(onAddLink: onAddLink, onAddScreenshot: onAddScreenshot),
  );
}

class AddContentSheet extends StatefulWidget {
  const AddContentSheet({
    required this.onAddLink,
    required this.onAddScreenshot,
    super.key,
  });

  final SaveLinkCallback onAddLink;
  final SaveScreenshotCallback onAddScreenshot;

  @override
  State<AddContentSheet> createState() => _AddContentSheetState();
}

class _SaveSubmission {
  const _SaveSubmission.link(this.label) : photoBytes = null;
  const _SaveSubmission.photo(this.label, Uint8List bytes) : photoBytes = bytes;

  final String label;
  final Uint8List? photoBytes;
  bool get isLink => photoBytes == null;
  int get tab => isLink ? 0 : 1;
}

class _AddContentSheetState extends State<AddContentSheet> {
  final _urlController = TextEditingController();
  final _bodyScrollController = ScrollController();
  Timer? _validationTimer;
  Timer? _saveErrorTimer;
  var _activeTab = 0;
  var _linkStage = SaveFlowStage.editing;
  var _photoStage = SaveFlowStage.editing;
  Uint8List? _selectedPhotoBytes;
  String? _selectedPhotoFilename;
  var _isSaving = false;
  String? _saveError;
  ({ContentItem content, _SaveSubmission submission})? _savedResult;

  @override
  void dispose() {
    _validationTimer?.cancel();
    _saveErrorTimer?.cancel();
    _urlController.dispose();
    _bodyScrollController.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    if (_savedResult != null) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted ||
        _savedResult != null ||
        data?.text == null ||
        data!.text!.trim().isEmpty) {
      return;
    }
    _urlController.text = data.text!.trim();
    _validateLink(_urlController.text);
  }

  void _validateLink(String value) {
    _validationTimer?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() => _linkStage = SaveFlowStage.editing);
      return;
    }
    setState(() => _linkStage = SaveFlowStage.editing);
    _validationTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final uri = Uri.tryParse(trimmed);
      final valid =
          uri != null &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.contains('.');
      setState(
        () => _linkStage = valid ? SaveFlowStage.valid : SaveFlowStage.invalid,
      );
    });
  }

  void _clearLink() {
    _validationTimer?.cancel();
    _urlController.clear();
    setState(() => _linkStage = SaveFlowStage.editing);
  }

  void _changeTab(int tab) {
    if (_savedResult != null) return;
    setState(() => _activeTab = tab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _savedResult == null && _bodyScrollController.hasClients) {
        _bodyScrollController.jumpTo(0);
      }
    });
  }

  Future<void> _submit() async {
    final isLink = _activeTab == 0;
    final stage = isLink ? _linkStage : _photoStage;
    if (_savedResult != null || _isSaving || stage != SaveFlowStage.valid) {
      return;
    }

    final _SaveSubmission submission;
    if (isLink) {
      submission = _SaveSubmission.link(_urlController.text.trim());
    } else {
      final bytes = _selectedPhotoBytes;
      final filename = _selectedPhotoFilename;
      if (bytes == null || filename == null) return;
      submission = _SaveSubmission.photo(filename, bytes);
    }

    setState(() => _isSaving = true);
    try {
      late final ContentItem savedContent;
      if (submission.isLink) {
        savedContent = await widget.onAddLink(url: submission.label);
      } else {
        savedContent = await widget.onAddScreenshot(
          bytes: submission.photoBytes!,
          filename: submission.label,
        );
      }
      if (mounted) {
        _validationTimer?.cancel();
        _saveErrorTimer?.cancel();
        setState(() {
          _isSaving = false;
          _savedResult = (content: savedContent, submission: submission);
          _activeTab = submission.tab;
          _saveError = null;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _bodyScrollController.hasClients) {
            _bodyScrollController.jumpTo(0);
          }
        });
      }
    } on ClipbackApiException catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSaveErrorToast(error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSaveErrorToast();
      }
    }
  }

  void _showSaveErrorToast([String? message]) {
    _saveErrorTimer?.cancel();
    setState(() => _saveError = message ?? '저장하지 못했어요. 다시 시도해 주세요.');
    _saveErrorTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _saveError = null);
    });
  }

  Future<void> _selectPhoto() async {
    if (_savedResult != null) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final photo = result != null && result.files.isNotEmpty
        ? result.files.first
        : null;
    if (!mounted || _savedResult != null || photo?.bytes == null) return;
    setState(() {
      _selectedPhotoBytes = photo!.bytes;
      _selectedPhotoFilename = photo.name;
      _photoStage = SaveFlowStage.valid;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _savedResult == null && _bodyScrollController.hasClients) {
        _bodyScrollController.jumpTo(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final savedResult = _savedResult;
    final stage = _activeTab == 0 ? _linkStage : _photoStage;
    final enabled =
        savedResult != null || (!_isSaving && stage == SaveFlowStage.valid);
    final bottomObstruction = math.max(
      MediaQuery.viewInsetsOf(context).bottom,
      MediaQuery.viewPaddingOf(context).bottom,
    );

    return ColoredBox(
      color: AppColors.bg,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: phoneWidth),
          child: SizedBox.expand(
            child: Material(
              color: AppColors.bg,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    SaveContentTopBar(onClose: () => Navigator.pop(context)),
                    Row(
                      children: [
                        Expanded(
                          child: _SaveTab(
                            label: '링크 첨부',
                            active: _activeTab == 0,
                            onTap: () => _changeTab(0),
                          ),
                        ),
                        Expanded(
                          child: _SaveTab(
                            label: '사진 첨부',
                            active: _activeTab == 1,
                            onTap: () => _changeTab(1),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _bodyScrollController,
                        padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
                        child: savedResult != null
                            ? SavedContentConfirmation(
                                content: savedResult.content,
                                originalUrl: savedResult.submission.label,
                                photoBytes: savedResult.submission.photoBytes,
                              )
                            : _activeTab == 0
                            ? LinkSaveBody(
                                controller: _urlController,
                                stage: _linkStage,
                                onChanged: _validateLink,
                                onClear: _clearLink,
                                onPaste: _paste,
                              )
                            : PhotoSaveBody(
                                stage: _photoStage,
                                onSelect: _selectPhoto,
                                photoBytes: _selectedPhotoBytes,
                              ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 32 + bottomObstruction),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_saveError case final message?)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(40, 0, 40, 16),
                              child: SaveErrorToast(message: message),
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SizedBox(
                              height: 56,
                              child: SaveFlowButton(
                                label: savedResult == null ? '허투루에 저장하기' : '닫기',
                                enabled: enabled,
                                loading: _isSaving,
                                onPressed: savedResult == null
                                    ? _submit
                                    : () => Navigator.of(
                                        context,
                                        rootNavigator: true,
                                      ).pop(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveTab extends StatelessWidget {
  const _SaveTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppColors.text : AppColors.subtler,
              width: active ? 2 : 1,
            ),
          ),
        ),
        child: Text(
          label,
          style: _SaveTextStyles.tab.copyWith(
            color: active ? AppColors.text : AppColors.subtler,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

enum SaveFlowStage { editing, invalid, valid }

class _SaveTextStyles {
  static const header = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.45,
    color: Colors.black,
  );
  static const tab = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.4,
  );
  static const heading = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: Colors.black,
  );
  static const previewTitle = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.375,
    height: 1.6,
    color: Colors.black,
  );
  static const previewSource = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.35,
    height: 1.6,
    color: AppColors.subtle,
  );
  static const categoryMessage = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.35,
    color: AppColors.subtle,
  );
  static const categoryName = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 22 / 16,
    color: Colors.black,
  );
  static const input = TextStyle(
    inherit: false,
    textBaseline: TextBaseline.alphabetic,
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.35,
    color: AppColors.text,
  );
  static const photoTitle = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.375,
    color: AppColors.subtle,
  );
  static const helper = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.35,
    color: AppColors.subSubtle,
  );
  static const action = TextStyle(
    inherit: false,
    fontFamily: 'Pretendard',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 22 / 16,
  );
}

class SaveContentTopBar extends StatelessWidget {
  const SaveContentTopBar({required this.onClose, super.key});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: appHeaderHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SvgIconButton(
              asset: Assets.close,
              onPressed: onClose,
              size: 24,
              hitSize: 24,
            ),
            const SizedBox(width: 8),
            const Text('콘텐츠 저장하기', style: _SaveTextStyles.header),
          ],
        ),
      ),
    );
  }
}

class LinkSaveBody extends StatelessWidget {
  const LinkSaveBody({
    required this.controller,
    required this.stage,
    required this.onChanged,
    required this.onClear,
    required this.onPaste,
    super.key,
  });

  final TextEditingController controller;
  final SaveFlowStage stage;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('저장할 링크', style: _SaveTextStyles.heading),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.url,
                    textAlignVertical: TextAlignVertical.center,
                    onChanged: onChanged,
                    style: _SaveTextStyles.input,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'https://',
                      hintStyle: _SaveTextStyles.input.copyWith(
                        color: AppColors.subtler,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.only(left: 8),
                      suffixIconConstraints: BoxConstraints(
                        minWidth: controller.text.isEmpty ? 0 : 34,
                        minHeight: 44,
                      ),
                      // Fill the shared row height without making the URL
                      // multiline or measuring the scaled text ourselves.
                      suffixIcon: Align(
                        widthFactor: 1,
                        child: controller.text.isEmpty
                            ? const SizedBox(width: 0, height: 44)
                            : IconButton(
                                onPressed: onClear,
                                padding: const EdgeInsets.only(right: 8),
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 44,
                                ),
                                style: IconButton.styleFrom(
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: SvgPicture.asset(
                                  Assets.xCircle,
                                  width: 18,
                                  height: 18,
                                ),
                              ),
                      ),
                      border: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 64,
                  child: TextButton(
                    onPressed: onPaste,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(64, 44),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      // Keep scaled glyph bounds clear of the inside border.
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.subtle,
                      disabledBackgroundColor: AppColors.surface,
                      disabledForegroundColor: AppColors.subtle,
                      side: const BorderSide(color: AppColors.subtler),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.35,
                      ),
                    ),
                    child: const Text(
                      '붙여넣기',
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (stage == SaveFlowStage.invalid || stage == SaveFlowStage.valid) ...[
          const SizedBox(height: 5),
          ValidationMessage(valid: stage == SaveFlowStage.valid),
        ],
      ],
    );
  }
}

class SavedContentConfirmation extends StatelessWidget {
  const SavedContentConfirmation({
    required this.content,
    required this.originalUrl,
    required this.photoBytes,
    super.key,
  });

  final ContentItem content;
  final String originalUrl;
  final Uint8List? photoBytes;

  @override
  Widget build(BuildContext context) {
    final linkLabel = originalUrl.isEmpty ? content.originalUrl : originalUrl;
    final isPhoto = photoBytes != null;
    final processingVideo =
        content.source == sourceLabel('youtube') &&
        (content.summaryStatus == 'queued' ||
            content.summaryStatus == 'processing');
    final categoryMessage = processingVideo
        ? '동영상 정보를 처리 중이에요. 분류는 나중에 반영될 수 있어요.'
        : content.category.name == catUncategorized.name
        ? '아직 분류되지 않았어요.'
        : '저장된 카테고리';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isPhoto ? '저장할 사진' : '저장할 링크', style: _SaveTextStyles.heading),
        const SizedBox(height: 16),
        if (isPhoto)
          Container(
            key: const ValueKey('save-result-photo-summary'),
            height: 89,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            foregroundDecoration: BoxDecoration(
              border: Border.all(color: AppColors.subtler),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Container(
              foregroundDecoration: BoxDecoration(
                border: Border.all(color: AppColors.subtler),
              ),
              child: ClipRect(
                child: Image.memory(
                  photoBytes!,
                  key: const ValueKey('save-result-photo-image'),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  semanticLabel: linkLabel,
                ),
              ),
            ),
          )
        else
          Container(
            key: const ValueKey('save-result-input-summary'),
            height: 44,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              linkLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _SaveTextStyles.input,
            ),
          ),
        if (!isPhoto) ...[
          const SizedBox(height: 5),
          const ValidationMessage(valid: true),
        ],
        SizedBox(height: isPhoto ? 16 : 32),
        const Text('미리보기', style: _SaveTextStyles.heading),
        const SizedBox(height: 16),
        Container(
          key: const ValueKey('save-result-preview-card'),
          constraints: const BoxConstraints(minHeight: 116),
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Container(
                width: 164,
                height: 100,
                foregroundDecoration: isPhoto
                    ? BoxDecoration(
                        border: Border.all(color: AppColors.subtler),
                        borderRadius: BorderRadius.circular(4),
                      )
                    : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: isPhoto
                      ? Image.memory(
                          photoBytes!,
                          key: const ValueKey('save-result-preview-image'),
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                        )
                      : Image.asset(
                          Assets.saveLinkPreview,
                          key: const ValueKey('save-result-preview-image'),
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        content.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _SaveTextStyles.previewTitle,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      content.source,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _SaveTextStyles.previewSource,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          key: const ValueKey('save-result-category-heading'),
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('카테고리', style: _SaveTextStyles.heading),
            Text(categoryMessage, style: _SaveTextStyles.categoryMessage),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          key: const ValueKey('save-result-category-row'),
          height: 55,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              SvgPicture.asset(
                Assets.saveResultFolder,
                key: const ValueKey('save-result-category-folder'),
                colorFilter: ColorFilter.mode(
                  content.category.color,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  content.category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _SaveTextStyles.categoryName,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '분류는 상세 화면에서 변경할 수 있어요.',
          style: TextStyle(color: AppColors.subtle, fontSize: 14),
        ),
      ],
    );
  }
}

class ValidationMessage extends StatelessWidget {
  const ValidationMessage({required this.valid, super.key});

  final bool valid;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SvgIcon(
          asset: valid ? Assets.check : Assets.close,
          size: 24,
          color: AppColors.subSubtle,
        ),
        Text(
          valid ? '유효한 링크예요!' : '유효하지 않은 링크예요.',
          style: _SaveTextStyles.helper,
        ),
      ],
    );
  }
}

class PhotoSaveBody extends StatelessWidget {
  const PhotoSaveBody({
    required this.stage,
    required this.onSelect,
    required this.photoBytes,
    super.key,
  });

  final SaveFlowStage stage;
  final Future<void> Function() onSelect;
  final Uint8List? photoBytes;

  @override
  Widget build(BuildContext context) {
    final selected = stage != SaveFlowStage.editing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('저장할 사진', style: _SaveTextStyles.heading),
        const SizedBox(height: 16),
        InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(8),
          child: selected
              ? SelectedPhotoPreview(photoBytes: photoBytes)
              : const PhotoEmptyPrompt(),
        ),
      ],
    );
  }
}

class PhotoEmptyPrompt extends StatelessWidget {
  const PhotoEmptyPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: const _DashedRoundedBorderPainter(
        color: AppColors.subtler,
        radius: 8,
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 89),
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: SvgPicture.asset(Assets.photoSelect),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('사진 선택', style: _SaveTextStyles.photoTitle),
                    SizedBox(height: 4),
                    Text(
                      '앨범에서 선택하거나 스크린샷을 업로드해 주세요.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _SaveTextStyles.helper,
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

class _DashedRoundedBorderPainter extends CustomPainter {
  const _DashedRoundedBorderPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    final metric = path.computeMetrics().first;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 4.0;
    for (var distance = 0.0; distance < metric.length; distance += dash + gap) {
      canvas.drawPath(
        metric.extractPath(distance, math.min(distance + dash, metric.length)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class SelectedPhotoPreview extends StatelessWidget {
  const SelectedPhotoPreview({required this.photoBytes, super.key});

  final Uint8List? photoBytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 437,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: AppColors.subtler),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: AppColors.subtler)),
        child: ClipRect(
          child: SizedBox.expand(
            child: photoBytes == null
                ? Image.asset(
                    Assets.savedPhotoPreview,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                  )
                : Image.memory(
                    photoBytes!,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                  ),
          ),
        ),
      ),
    );
  }
}

class SaveFlowButton extends StatelessWidget {
  const SaveFlowButton({
    required this.label,
    required this.enabled,
    required this.loading,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: loading ? '저장 중' : label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onPressed : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: enabled || loading ? AppColors.text : AppColors.subtler,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: DefaultTextStyle(
              style: _SaveTextStyles.action.copyWith(
                color: enabled || loading ? AppColors.main : AppColors.surface,
              ),
              child: loading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: AppColors.surface,
                            strokeWidth: 2.2,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text('저장 중...'),
                      ],
                    )
                  : Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

class SaveErrorToast extends StatelessWidget {
  const SaveErrorToast({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.text,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.surface, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.surface,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LinkAddSheet extends StatefulWidget {
  const LinkAddSheet({
    required this.categories,
    required this.onSave,
    super.key,
  });

  final List<CategoryItem> categories;
  final void Function({required String url, required CategoryItem category})
  onSave;

  @override
  State<LinkAddSheet> createState() => _LinkAddSheetState();
}

class _LinkAddSheetState extends State<LinkAddSheet> {
  final _controller = TextEditingController(
    text: 'https://www.instagram.com/p/hutureu-mock',
  );
  late CategoryItem _category;

  @override
  void initState() {
    super.initState();
    _category = widget.categories.first;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final url = _controller.text.trim();
    if (url.isEmpty) return;
    widget.onSave(url: url, category: _category);
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: '링크 추가',
      children: [
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            hintText: 'https://',
            filled: true,
            fillColor: AppColors.bg,
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),
        CategorySelectField(
          categories: widget.categories,
          selected: _category,
          onChanged: (category) => setState(() => _category = category),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            '미리보기: 링크 제목, 핵심 요약, 자동 추천 카테고리를 확인한 뒤 저장하는 목데이터 흐름입니다.',
            style: TextStyle(color: AppColors.subtle, fontSize: 14),
          ),
        ),
        const SizedBox(height: 18),
        PrimaryButton(label: '저장하기', onPressed: _save, height: 52),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../controllers/diary_editor_controller.dart';
import 'diary_editor/diary_editor.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../l10n/app_localizations.dart';
import '../viewmodels/diary_text_appearance.dart';

/// 正文排版预览卡：示例标题 + 几段示例正文，按传入外观渲染。
///
/// 正文用只读 AppFlowy 渲染、与日记页面同一个样式生成函数，段间距这类块级
/// 排版在这里看到的就是日记里的效果。示例文本随界面语言切换时重建文档。
class DiaryTypographyPreview extends StatefulWidget {
  const DiaryTypographyPreview({
    super.key,
    required this.appearance,
    this.maxHeight = double.infinity,
  });

  final DiaryTextAppearance appearance;

  /// 卡片高度上限：超出时卡片外框保持完整圆角，示例文字在卡内滚动。
  final double maxHeight;

  @override
  State<DiaryTypographyPreview> createState() => _DiaryTypographyPreviewState();
}

class _DiaryTypographyPreviewState extends State<DiaryTypographyPreview> {
  DiaryEditorController? _controller;
  String? _sampleText;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sample = context.l10n.diaryTypographySampleBody;
    if (sample == _sampleText) {
      return;
    }
    _sampleText = sample;
    _controller?.dispose();
    _controller = DiaryEditorController.fromContent(sample, readOnly: true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ExpressiveSurfaces.cardColor(colorScheme),
        borderRadius: BorderRadius.circular(20),
        border: Border.fromBorderSide(
          ExpressiveSurfaces.cardBorderSide(colorScheme),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.m,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: _buildContent(context, theme),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          context.l10n.diaryTypographySampleTitle,
          style: widget.appearance.titleStyle(
            theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        // 预览不可交互：避免点按出现光标或选区，也不抢滚动手势。
        IgnorePointer(
          child: DiaryEditor(
            controller: _controller!,
            appearance: widget.appearance,
            shrinkWrap: true,
            textSelection: false,
          ),
        ),
      ],
    );
  }
}

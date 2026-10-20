import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/services/diary_font_storage_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_code_block/diary_code_block_style.dart';
import '../../../diaries/providers/diary_typography_provider.dart';
import '../../../diaries/widgets/diary_typography_metrics_editor.dart';
import '../../controllers/diary_code_block_style_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import '../../widgets/style_editor/style_editor_common.dart';
import 'diary_code_block_style_display_tab.dart';

/// “字体”标签页：代码字体（系统等宽、正文字体，再按导入顺序列出导入的
/// 字体，点按即写入）与字号、行距滑块（拖动中只预览，松手写入）。
///
/// 导入字体与正文排版同一来源（[diaryImportedFontsProvider]，同一套 id）；
/// 这里只挑选，导入与删除仍在正文字体与排版页。所选导入字体已不在本机时
/// 与正文排版页同样处理：选择原样保留（文件找回后自动恢复），没有选项处于
/// 选中态，分组下方说明代码暂按系统等宽字体显示。
class DiaryCodeBlockStyleFontTab extends ConsumerWidget {
  const DiaryCodeBlockStyleFontTab({super.key, required this.controller});

  final DiaryCodeBlockStyleEditorController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final style = controller.style;
    final fontsAsync = ref.watch(diaryImportedFontsProvider);
    final importedFonts =
        fontsAsync.asData?.value ?? const <DiaryImportedFont>[];
    final selectedFontMissing =
        style.usesImportedFont &&
        fontsAsync.hasValue &&
        !importedFonts.any((font) => font.id == style.fontId);
    final options = <(String, String)>[
      (kDiaryCodeFontMono, l10n.codeBlockFontMono),
      (kDiaryCodeFontBody, l10n.codeBlockFontBody),
      for (final font in importedFonts) (font.id, font.name),
    ];

    return StyleEditorTabList(
      children: <Widget>[
        SettingsCardGroup(
          footer: selectedFontMissing ? l10n.codeBlockFontMissing : null,
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.codeBlockFontTitle,
              child: Wrap(
                spacing: AppSpacing.s,
                runSpacing: AppSpacing.s,
                children: <Widget>[
                  for (final (id, label) in options)
                    ChoiceChip(
                      label: Text(label),
                      selected: id == style.fontId,
                      onSelected: (_) =>
                          controller.commitWith((s) => s.copyWith(fontId: id)),
                    ),
                ],
              ),
            ),
          ],
        ),
        SettingsCardGroup(
          children: <Widget>[
            SettingsSliderTile(
              title: l10n.codeBlockFontSizeTitle,
              value: style.fontScale,
              min: DiaryCodeBlockStyle.minFontScale,
              max: DiaryCodeBlockStyle.maxFontScale,
              divisions: codeBlockSliderDivisions(
                DiaryCodeBlockStyle.minFontScale,
                DiaryCodeBlockStyle.maxFontScale,
                DiaryCodeBlockStyle.fontScaleStep,
              ),
              valueLabel: (double v) =>
                  l10n.codeBlockFontSizeValue((v * 100).round()),
              onChanged: (double v) =>
                  controller.previewWith((s) => s.copyWith(fontScale: v)),
              onChangeEnd: (double v) =>
                  controller.commitWith((s) => s.copyWith(fontScale: v)),
            ),
            SettingsSliderTile(
              title: l10n.codeBlockLineHeightTitle,
              value: style.lineHeight,
              min: DiaryCodeBlockStyle.minLineHeight,
              max: DiaryCodeBlockStyle.maxLineHeight,
              divisions: codeBlockSliderDivisions(
                DiaryCodeBlockStyle.minLineHeight,
                DiaryCodeBlockStyle.maxLineHeight,
                DiaryCodeBlockStyle.lineHeightStep,
              ),
              // 步进 0.05：与正文排版同样去掉多余的 0（1.5、1.55），只留一位
              // 小数会让相邻两档显示成同一个值。
              valueLabel: formatDiaryTypographyValue,
              onChanged: (double v) =>
                  controller.previewWith((s) => s.copyWith(lineHeight: v)),
              onChangeEnd: (double v) =>
                  controller.commitWith((s) => s.copyWith(lineHeight: v)),
            ),
          ],
        ),
      ],
    );
  }
}

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../controllers/diary_block_batch_format.dart';
import '../../controllers/diary_editor_controller.dart';
import '../../models/diary_text_style_options.dart';
import '../../models/diary_toolbar_preferences.dart';
import '../diary_panel_action_cell.dart';
import '../diary_toolbar_config.dart';
import 'diary_block_panel_body.dart';

/// 第一排的行内格式：工具栏工具与写进文字的属性键。
final List<(DiaryToolbarItem, String)> _inline = [
  (DiaryToolbarItem.bold, af.AppFlowyRichTextKeys.bold),
  (DiaryToolbarItem.italic, af.AppFlowyRichTextKeys.italic),
  (DiaryToolbarItem.underline, af.AppFlowyRichTextKeys.underline),
  (DiaryToolbarItem.strikeThrough, af.AppFlowyRichTextKeys.strikethrough),
];

/// 「样式」面板内容的自然高度（不含面板外框）。
final double kDiaryBlockStylePanelHeight = diaryBlockPanelHeight(
  2,
  footer: true,
);

/// 段落操作栏的「样式」面板：第一排加粗 / 斜体 / 下划线 / 删除线（整段开关：
/// 选中的文字都带着时显示选中态、再点去掉），第二排左对齐 / 居中 / 右对齐 /
/// 两端对齐，最下通栏一格「清除格式」。作用于选中块（连同子块）里的文字块，
/// 代码块不加格式、不改对齐（同工具栏）；每次一步撤销，面板保持打开。
class DiaryBlockStylePanel extends StatelessWidget {
  const DiaryBlockStylePanel({
    super.key,
    required this.controller,
    required this.bodyHeight,
  });

  final DiaryEditorController controller;
  final double bodyHeight;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, controller.blockSelection]),
    builder: (BuildContext context, Widget? child) {
      final l10n = context.l10n;
      final selection = controller.blockSelection;
      final roots = selection.roots;
      final textNodes = diaryBlockTextNodes(roots);
      final enabled = !controller.readOnly && textNodes.isNotEmpty;
      final align = diaryBlocksAlign(roots);
      return DiaryBlockPanelBody(
        bodyHeight: bodyHeight,
        footer: DiaryPanelActionCell(
          icon: DiaryToolbarItem.clearFormat.iconData,
          label: DiaryToolbarItem.clearFormat.label(l10n),
          enabled: enabled,
          filled: true,
          wide: true,
          maxLines: 1,
          onTap: () =>
              selection.replace(clearDiaryBlocksFormat(controller, roots)),
        ),
        rows: [
          [
            for (final (item, key) in _inline)
              DiaryBlockPanelItem(
                DiaryPanelActionCell(
                  icon: item.iconData,
                  label: item.label(l10n),
                  enabled: enabled,
                  selected: diaryBlocksHaveInline(roots, key),
                  filled: true,
                  onTap: () => toggleDiaryBlocksInline(controller, roots, key),
                ),
              ),
          ],
          [
            for (final value in DiaryTextAlign.values)
              DiaryBlockPanelItem(
                DiaryPanelActionCell(
                  icon: diaryTextAlignIcon(value),
                  label: _alignLabel(l10n, value),
                  enabled: enabled,
                  selected: value == align,
                  filled: true,
                  onTap: () => setDiaryBlocksAlign(controller, roots, value),
                ),
              ),
          ],
        ],
      );
    },
  );

  static String _alignLabel(AppLocalizations l10n, DiaryTextAlign align) =>
      switch (align) {
        DiaryTextAlign.left => l10n.diaryAlignLeft,
        DiaryTextAlign.center => l10n.diaryAlignCenter,
        DiaryTextAlign.right => l10n.diaryAlignRight,
        DiaryTextAlign.justify => l10n.diaryAlignJustify,
      };
}

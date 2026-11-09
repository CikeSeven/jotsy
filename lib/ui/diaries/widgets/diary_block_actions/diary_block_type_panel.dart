import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../../l10n/app_localizations.dart';
import '../../controllers/diary_block_batch_format.dart';
import '../../controllers/diary_editor_controller.dart';
import '../../models/diary_toolbar_preferences.dart';
import '../diary_panel_action_cell.dart';
import 'diary_block_panel_body.dart';

/// 「转换为」面板的格子，按三排四格的顺序。
const List<List<DiaryBlockTypeChoice>> _rows = [
  [
    (type: kDiaryBlockParagraph, level: null),
    (type: kDiaryBlockHeading, level: 1),
    (type: kDiaryBlockHeading, level: 2),
    (type: kDiaryBlockHeading, level: 3),
  ],
  [
    (type: kDiaryBlockBulletedList, level: null),
    (type: kDiaryBlockNumberedList, level: null),
    (type: kDiaryBlockTodoList, level: null),
    (type: kDiaryBlockQuote, level: null),
  ],
  [
    (type: kDiaryBlockCallout, level: null),
    (type: kDiaryBlockToggleList, level: null),
    (type: kDiaryBlockCode, level: null),
  ],
];

/// 「转换为」面板内容的自然高度（不含面板外框）。
final double kDiaryBlockTypePanelHeight = diaryBlockPanelHeight(_rows.length);

/// 段落操作栏的「转换为」面板：把选中的块（连同子块）里的文字块一起换成
/// 正文、一二三级标题、无序 / 有序列表、待办、引用、提示块、折叠块或代码块，
/// 一步撤销，面板保持打开。三排磁贴，选中的块都是同一种时那一格显示选中
/// 态；没有能换类型的文字块（只选了图片、表格等）时整面停用。名称与图标
/// 与 `/` 菜单、工具栏同一套，三级标题用 H1 / H2 / H3 字样区分（图标是
/// 同一个）。
class DiaryBlockTypePanel extends StatelessWidget {
  const DiaryBlockTypePanel({
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
      final selection = controller.blockSelection;
      final roots = selection.roots;
      final current = diaryBlocksType(roots);
      final enabled = !controller.readOnly && diaryBlocksConvertible(roots);
      return DiaryBlockPanelBody(
        bodyHeight: bodyHeight,
        rows: [
          for (final row in _rows)
            [
              for (final choice in row)
                DiaryBlockPanelItem(
                  DiaryPanelActionCell(
                    icon: _icon(choice),
                    glyph: choice.type == kDiaryBlockHeading
                        ? 'H${choice.level}'
                        : null,
                    label: _label(context.l10n, choice),
                    enabled: enabled,
                    selected: choice == current,
                    filled: true,
                    onTap: () => selection.replace(
                      setDiaryBlocksType(controller, roots, choice),
                    ),
                  ),
                ),
            ],
        ],
      );
    },
  );

  static FaIconData _icon(DiaryBlockTypeChoice choice) => switch (choice.type) {
    kDiaryBlockParagraph => FontAwesomeIcons.paragraph,
    kDiaryBlockHeading => FontAwesomeIcons.heading,
    kDiaryBlockBulletedList => DiaryToolbarItem.bulletList.iconData,
    kDiaryBlockNumberedList => DiaryToolbarItem.orderedList.iconData,
    kDiaryBlockTodoList => DiaryToolbarItem.checkList.iconData,
    kDiaryBlockQuote => DiaryToolbarItem.quote.iconData,
    kDiaryBlockCallout => DiaryToolbarItem.callout.iconData,
    kDiaryBlockToggleList => DiaryToolbarItem.toggle.iconData,
    _ => DiaryToolbarItem.codeBlock.iconData,
  };

  static String _label(AppLocalizations l10n, DiaryBlockTypeChoice choice) =>
      switch (choice.type) {
        kDiaryBlockParagraph => l10n.diaryEditorParagraph,
        kDiaryBlockHeading => switch (choice.level) {
          1 => l10n.diaryEditorHeading1,
          2 => l10n.diaryEditorHeading2,
          _ => l10n.diaryEditorHeading3,
        },
        kDiaryBlockBulletedList => DiaryToolbarItem.bulletList.label(l10n),
        kDiaryBlockNumberedList => DiaryToolbarItem.orderedList.label(l10n),
        kDiaryBlockTodoList => DiaryToolbarItem.checkList.label(l10n),
        kDiaryBlockQuote => DiaryToolbarItem.quote.label(l10n),
        kDiaryBlockCallout => DiaryToolbarItem.callout.label(l10n),
        kDiaryBlockToggleList => DiaryToolbarItem.toggle.label(l10n),
        // 工具栏上叫“代码块（多行）”是为了与行内代码区分；这里只有块。
        _ => l10n.codeBlockPanelTitle,
      };
}

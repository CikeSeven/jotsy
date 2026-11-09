import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../controllers/diary_block_batch_structure.dart';
import '../../controllers/diary_block_group_move.dart';
import '../../controllers/diary_editor_controller.dart';
import '../diary_panel_action_cell.dart';
import 'diary_block_actions.dart';
import 'diary_block_panel_body.dart';

/// 「更多」面板内容的自然高度（不含面板外框）。
final double kDiaryBlockMorePanelHeight = diaryBlockPanelHeight(2);

/// 段落操作栏的「更多」面板：第一排移到开头 / 末尾、创建副本、剪切，第二排
/// 拆分成段落、合并成一段（标签长，各占两格、图标与标签横排）。作用于选中
/// 的块、一步撤销；移动、创建副本、拆分与合并后面板保持打开（选择跟着换到
/// 操作后的块），剪切后退出选择模式（操作栏随之收起）。停用只看文档与
/// 选择：一个都没选、已在开头 / 末尾、没有带换行的文字块（拆分）、不到两块
/// 文字块（合并）时停用。
class DiaryBlockMorePanel extends StatelessWidget {
  const DiaryBlockMorePanel({
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
      final roots = controller.blockSelection.roots;
      final editable = !controller.readOnly && roots.isNotEmpty;
      DiaryBlockPanelItem cell(
        FaIconData icon,
        String label, {
        required bool enabled,
        required VoidCallback onTap,
        bool wide = false,
      }) => DiaryBlockPanelItem(
        DiaryPanelActionCell(
          icon: icon,
          label: label,
          enabled: enabled,
          filled: true,
          wide: wide,
          onTap: onTap,
        ),
        span: wide ? 2 : 1,
      );
      return DiaryBlockPanelBody(
        bodyHeight: bodyHeight,
        rows: [
          [
            cell(
              FontAwesomeIcons.anglesUp,
              l10n.diaryBlockMoveToTop,
              enabled:
                  editable &&
                  canMoveDiaryBlockGroupToEdge(controller, roots, top: true),
              onTap: () => DiaryBlockActions.moveToEdge(controller, top: true),
            ),
            cell(
              FontAwesomeIcons.anglesDown,
              l10n.diaryBlockMoveToBottom,
              enabled:
                  editable &&
                  canMoveDiaryBlockGroupToEdge(controller, roots, top: false),
              onTap: () => DiaryBlockActions.moveToEdge(controller, top: false),
            ),
            cell(
              FontAwesomeIcons.clone,
              l10n.diaryBlockDuplicate,
              enabled: editable,
              onTap: () => DiaryBlockActions.duplicate(controller),
            ),
            cell(
              FontAwesomeIcons.scissors,
              l10n.diaryBlockCut,
              enabled: editable,
              onTap: () => DiaryBlockActions.cut(context, controller),
            ),
          ],
          [
            cell(
              FontAwesomeIcons.arrowsSplitUpAndLeft,
              l10n.diaryBlockSplitLines,
              wide: true,
              enabled: editable && canSplitDiaryBlockLines(roots),
              onTap: () => controller.blockSelection.replace(
                splitDiaryBlockLines(controller, roots),
              ),
            ),
            cell(
              FontAwesomeIcons.objectGroup,
              l10n.diaryBlockMerge,
              wide: true,
              enabled: editable && canMergeDiaryBlocks(roots),
              onTap: () => controller.blockSelection.replace(
                mergeDiaryBlocks(controller, roots),
              ),
            ),
          ],
        ],
      );
    },
  );
}

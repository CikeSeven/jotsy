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
/// 拆分成段落、合并成一段。作用于选中的块、一步撤销；移动、创建副本、拆分
/// 与合并后面板保持打开（选择跟着换到操作后的块），剪切后退出选择模式（操作
/// 栏随之收起）。停用只看文档与选择：一个都没选、已在开头 / 末尾、没有带
/// 换行的文字块（拆分）、不到两块文字块（合并）时停用。
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
      return DiaryBlockPanelBody(
        title: l10n.diaryEditorMoreActions,
        bodyHeight: bodyHeight,
        rows: [
          [
            DiaryPanelActionCell(
              icon: FontAwesomeIcons.anglesUp,
              label: l10n.diaryBlockMoveToTop,
              enabled:
                  editable &&
                  canMoveDiaryBlockGroupToEdge(controller, roots, top: true),
              onTap: () => DiaryBlockActions.moveToEdge(controller, top: true),
            ),
            DiaryPanelActionCell(
              icon: FontAwesomeIcons.anglesDown,
              label: l10n.diaryBlockMoveToBottom,
              enabled:
                  editable &&
                  canMoveDiaryBlockGroupToEdge(controller, roots, top: false),
              onTap: () => DiaryBlockActions.moveToEdge(controller, top: false),
            ),
            DiaryPanelActionCell(
              icon: FontAwesomeIcons.clone,
              label: l10n.diaryBlockDuplicate,
              enabled: editable,
              onTap: () => DiaryBlockActions.duplicate(controller),
            ),
            DiaryPanelActionCell(
              icon: FontAwesomeIcons.scissors,
              label: l10n.diaryBlockCut,
              enabled: editable,
              onTap: () => DiaryBlockActions.cut(context, controller),
            ),
          ],
          [
            DiaryPanelActionCell(
              icon: FontAwesomeIcons.arrowsSplitUpAndLeft,
              label: l10n.diaryBlockSplitLines,
              enabled: editable && canSplitDiaryBlockLines(roots),
              onTap: () => controller.blockSelection.replace(
                splitDiaryBlockLines(controller, roots),
              ),
            ),
            DiaryPanelActionCell(
              icon: FontAwesomeIcons.objectGroup,
              label: l10n.diaryBlockMerge,
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

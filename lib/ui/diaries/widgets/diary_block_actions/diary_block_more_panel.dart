import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../controllers/diary_block_group_move.dart';
import '../../controllers/diary_editor_controller.dart';
import '../diary_panel_action_cell.dart';
import 'diary_block_actions.dart';
import 'diary_block_panel_header.dart';

/// 一排操作格的高度与间距（同表格面板）。
const double _kRowHeight = 58;
const double _kRowGap = 4;
const double _kBottomGap = 4;
const double _kInset = 4;

/// 「更多」面板里的操作，按排列顺序。
enum DiaryBlockMoreAction { moveToTop, moveToBottom, duplicate, cut }

const List<List<DiaryBlockMoreAction>> _rows = [
  [
    DiaryBlockMoreAction.moveToTop,
    DiaryBlockMoreAction.moveToBottom,
    DiaryBlockMoreAction.duplicate,
    DiaryBlockMoreAction.cut,
  ],
];

/// 「更多」面板内容的自然高度（不含面板外框）。
final double kDiaryBlockMorePanelHeight =
    kDiaryBlockPanelHeaderHeight +
    _rows.length * _kRowHeight +
    (_rows.length - 1) * _kRowGap +
    _kBottomGap;

/// 段落操作栏的「更多」面板：移到开头 / 末尾、创建副本、剪切。作用于选中
/// 的块、一步撤销；移动与创建副本后面板保持打开，剪切后退出选择模式（操作栏
/// 随之收起）。停用只看文档与选择：一个都没选、或已在开头 / 末尾时停用。
class DiaryBlockMorePanel extends StatelessWidget {
  const DiaryBlockMorePanel({
    super.key,
    required this.controller,
    required this.bodyHeight,
  });

  final DiaryEditorController controller;
  final double bodyHeight;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DiaryBlockPanelHeader(title: context.l10n.diaryEditorMoreActions),
        ListenableBuilder(
          listenable: Listenable.merge([controller, controller.blockSelection]),
          builder: (BuildContext context, Widget? child) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var i = 0; i < _rows.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: _kRowGap),
                SizedBox(height: _kRowHeight, child: _row(context, _rows[i])),
              ],
            ],
          ),
        ),
        const SizedBox(height: _kBottomGap),
      ],
    );
    return SizedBox(
      height: bodyHeight,
      child: bodyHeight < kDiaryBlockMorePanelHeight
          ? SingleChildScrollView(primary: false, child: content)
          : content,
    );
  }

  Widget _row(BuildContext context, List<DiaryBlockMoreAction> actions) {
    final l10n = context.l10n;
    final roots = controller.blockSelection.roots;
    final editable = !controller.readOnly && roots.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kInset),
      child: Row(
        children: <Widget>[
          for (final action in actions)
            Expanded(
              child: switch (action) {
                DiaryBlockMoreAction.moveToTop => DiaryPanelActionCell(
                  icon: FontAwesomeIcons.anglesUp,
                  label: l10n.diaryBlockMoveToTop,
                  enabled:
                      editable &&
                      canMoveDiaryBlockGroupToEdge(
                        controller,
                        roots,
                        top: true,
                      ),
                  onTap: () =>
                      DiaryBlockActions.moveToEdge(controller, top: true),
                ),
                DiaryBlockMoreAction.moveToBottom => DiaryPanelActionCell(
                  icon: FontAwesomeIcons.anglesDown,
                  label: l10n.diaryBlockMoveToBottom,
                  enabled:
                      editable &&
                      canMoveDiaryBlockGroupToEdge(
                        controller,
                        roots,
                        top: false,
                      ),
                  onTap: () =>
                      DiaryBlockActions.moveToEdge(controller, top: false),
                ),
                DiaryBlockMoreAction.duplicate => DiaryPanelActionCell(
                  icon: FontAwesomeIcons.clone,
                  label: l10n.diaryBlockDuplicate,
                  enabled: editable,
                  onTap: () => DiaryBlockActions.duplicate(controller),
                ),
                DiaryBlockMoreAction.cut => DiaryPanelActionCell(
                  icon: FontAwesomeIcons.scissors,
                  label: l10n.diaryBlockCut,
                  enabled: editable,
                  onTap: () => DiaryBlockActions.cut(context, controller),
                ),
              },
            ),
        ],
      ),
    );
  }
}

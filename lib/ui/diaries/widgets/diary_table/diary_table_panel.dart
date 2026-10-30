import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart'
    as editor;
import 'package:node_diary/ui/diaries/controllers/diary_table_editing.dart';
import 'package:node_diary/ui/diaries/controllers/diary_table_structure.dart';
import 'package:node_diary/ui/widgets/expressive_state_blend.dart';

/// 表头一行高度：与代码块、列表、提示块面板的表头同高。
const double _kHeaderHeight = 40;
const double _kHeaderGap = 4;

/// 两排操作格：一格里图标在上、短标签在下（两行以内），320dp 的手机上一排
/// 四格也放得下。
const double _kRowHeight = 58;
const double _kRowGap = 4;
const double _kBottomGap = 4;

/// 标题与两排操作的左右缩进，左缘对齐（同代码块、列表、提示块面板）。
const double _kInset = 4;

const double _kIconSize = 16;
const double _kIconGap = 4;
const double _kLabelSize = 11;
const double _kCellRadius = 12;

/// 表格面板内容的自然高度（不含面板外框）。与选区、取值无关，工具栏据此
/// 直接算出面板目标高度，不必等测量。
const double kDiaryTablePanelHeight =
    _kHeaderHeight +
    _kHeaderGap +
    _kRowHeight +
    _kRowGap +
    _kRowHeight +
    _kBottomGap;

/// 面板里的操作，按两排四格的顺序。
enum DiaryTableAction {
  insertRowAbove,
  insertRowBelow,
  insertColumnLeft,
  insertColumnRight,
  deleteRow,
  deleteColumn,
  headerRow,
  deleteTable,
}

extension DiaryTableActionX on DiaryTableAction {
  FaIconData get icon => switch (this) {
    DiaryTableAction.insertRowAbove => FontAwesomeIcons.arrowUp,
    DiaryTableAction.insertRowBelow => FontAwesomeIcons.arrowDown,
    DiaryTableAction.insertColumnLeft => FontAwesomeIcons.arrowLeft,
    DiaryTableAction.insertColumnRight => FontAwesomeIcons.arrowRight,
    DiaryTableAction.deleteRow => FontAwesomeIcons.gripLines,
    DiaryTableAction.deleteColumn => FontAwesomeIcons.gripLinesVertical,
    DiaryTableAction.headerRow => FontAwesomeIcons.heading,
    DiaryTableAction.deleteTable => FontAwesomeIcons.trashCan,
  };

  String label(AppLocalizations l10n) => switch (this) {
    DiaryTableAction.insertRowAbove => l10n.diaryTableInsertRowAbove,
    DiaryTableAction.insertRowBelow => l10n.diaryTableInsertRowBelow,
    DiaryTableAction.insertColumnLeft => l10n.diaryTableInsertColumnLeft,
    DiaryTableAction.insertColumnRight => l10n.diaryTableInsertColumnRight,
    DiaryTableAction.deleteRow => l10n.diaryTableDeleteRow,
    DiaryTableAction.deleteColumn => l10n.diaryTableDeleteColumn,
    DiaryTableAction.headerRow => l10n.diaryTableHeaderRow,
    DiaryTableAction.deleteTable => l10n.diaryTableDelete,
  };

  /// 光标在 [caret] 处时能不能做：列数到上限不能加列，只剩一行 / 一列时不能
  /// 删行 / 删列。
  bool enabledFor(DiaryTableCaret caret) => switch (this) {
    DiaryTableAction.insertColumnLeft ||
    DiaryTableAction.insertColumnRight => canInsertDiaryTableColumn(caret),
    DiaryTableAction.deleteRow => canDeleteDiaryTableRow(caret),
    DiaryTableAction.deleteColumn => canDeleteDiaryTableColumn(caret),
    _ => true,
  };

  void apply(editor.DiaryEditorController controller) => switch (this) {
    DiaryTableAction.insertRowAbove => insertDiaryTableRow(
      controller,
      above: true,
    ),
    DiaryTableAction.insertRowBelow => insertDiaryTableRow(
      controller,
      above: false,
    ),
    DiaryTableAction.insertColumnLeft => insertDiaryTableColumn(
      controller,
      before: true,
    ),
    DiaryTableAction.insertColumnRight => insertDiaryTableColumn(
      controller,
      before: false,
    ),
    DiaryTableAction.deleteRow => deleteDiaryTableRow(controller),
    DiaryTableAction.deleteColumn => deleteDiaryTableColumn(controller),
    DiaryTableAction.headerRow => toggleDiaryTableHeaderRow(controller),
    DiaryTableAction.deleteTable => deleteDiaryTable(controller),
  };
}

/// 悬浮工具栏卡片内的表格面板：表头 + 两排操作格（上方 / 下方插入行、左侧
/// / 右侧插入列；删除行、删除列、表头行开关、删除表格）。
///
/// - 输入：正文控制器、工具栏给的内容高度 [bodyHeight]（小于自然高度时面板
///   内纵向滚动）、收起回调 [onClose]；
/// - 输出：每个操作经 `diary_table_editing.dart` 改写光标所在的表格，一次
///   一步撤销，光标留在合理的格子里，面板保持打开；删除表格后光标已不在
///   表格里，工具栏的选区监听会收起面板，这里也经 [onClose] 收起；
/// - 停用与选中态只看正文（随选区与撤销变化）：列数到上限不能加列，只剩
///   一行 / 一列不能删；「表头行」开着时显示选中态；「删除表格」用错误色；
/// - 四格等分整行宽度，320dp 的手机上同样排成一行；
/// - 不走路由、对话框或底部面板，按钮也不请求焦点：那些都会抢走正文焦点、
///   收起键盘，而工具栏跟着键盘显示，会连同面板一起消失。
class DiaryTablePanel extends StatelessWidget {
  const DiaryTablePanel({
    super.key,
    required this.controller,
    required this.bodyHeight,
    required this.onClose,
  });

  final editor.DiaryEditorController controller;
  final double bodyHeight;
  final VoidCallback onClose;

  static const List<List<DiaryTableAction>> _rows = [
    [
      DiaryTableAction.insertRowAbove,
      DiaryTableAction.insertRowBelow,
      DiaryTableAction.insertColumnLeft,
      DiaryTableAction.insertColumnRight,
    ],
    [
      DiaryTableAction.deleteRow,
      DiaryTableAction.deleteColumn,
      DiaryTableAction.headerRow,
      DiaryTableAction.deleteTable,
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(height: _kHeaderHeight, child: _buildHeader(context)),
        const SizedBox(height: _kHeaderGap),
        ListenableBuilder(
          listenable: controller,
          builder: (BuildContext context, Widget? child) {
            final caret = diaryTableCaret(controller);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < _rows.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: _kRowGap),
                  SizedBox(
                    height: _kRowHeight,
                    child: _buildRow(context, _rows[i], caret),
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: _kBottomGap),
      ],
    );
    return SizedBox(
      height: bodyHeight,
      child: bodyHeight < kDiaryTablePanelHeight
          ? SingleChildScrollView(primary: false, child: content)
          : content,
    );
  }

  /// 标题字号与字重同代码块、列表面板表头。
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: _kInset),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          context.l10n.diaryEditorTable,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    List<DiaryTableAction> actions,
    DiaryTableCaret? caret,
  ) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kInset),
      child: Row(
        children: <Widget>[
          for (final action in actions)
            Expanded(
              child: _DiaryTableActionCell(
                icon: action.icon,
                label: action.label(l10n),
                enabled:
                    caret != null &&
                    !controller.readOnly &&
                    action.enabledFor(caret),
                selected:
                    action == DiaryTableAction.headerRow &&
                    (caret?.headerRow ?? false),
                destructive: action == DiaryTableAction.deleteTable,
                onTap: () {
                  action.apply(controller);
                  if (action == DiaryTableAction.deleteTable) onClose();
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// 一格操作：图标在上、标签在下；选中（表头行开着）时垫 primaryContainer
/// 圆角方块，经 [ExpressiveStateBlend] 补间；停用时变淡；删除表格用错误色。
/// 只是按钮，不请求焦点。
class _DiaryTableActionCell extends StatelessWidget {
  const _DiaryTableActionCell({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.selected,
    required this.destructive,
    required this.onTap,
  });

  final FaIconData icon;
  final String label;
  final bool enabled;
  final bool selected;
  final bool destructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_kCellRadius),
    );
    final base = destructive ? colors.error : colors.onSurface;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: ExpressiveStateBlend(
        active: selected,
        builder: (BuildContext context, double t, Widget? child) {
          final foreground = Color.lerp(
            base,
            colors.onPrimaryContainer,
            t,
          )!.withValues(alpha: enabled ? 1 : 0.38);
          return Material(
            color: colors.primaryContainer.withValues(alpha: t),
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onTap : null,
              customBorder: shape,
              canRequestFocus: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    FaIcon(icon, size: _kIconSize, color: foreground),
                    const SizedBox(height: _kIconGap),
                    Text(
                      label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: _kLabelSize,
                        height: 1.2,
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

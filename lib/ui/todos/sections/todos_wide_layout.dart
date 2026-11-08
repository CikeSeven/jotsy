import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../widgets/todo_detail_pane.dart';

/// 宽窗口（≥1024）待办页的分栏：左栏 [sidebarWidth] 宽，中间列表，可用宽度
/// 放得下“左栏 + [listMinWidth] 列表 + 详情栏”时右侧再放 [TodoDetailPane]。
///
/// 只负责量宽度与摆放：[canShowPane] 按给定宽度算能否放详情栏（页面据此
/// 决定点开待办放进详情栏还是弹底部面板）；[list] 按列表实际宽度构建。
class TodosWideLayout extends StatelessWidget {
  const TodosWideLayout({
    super.key,
    required this.width,
    required this.topInset,
    required this.sidebar,
    required this.list,
    required this.detailId,
    required this.onCloseDetail,
    required this.onDeleteDetail,
  });

  static const double sidebarWidth = 264;

  /// 三栏时列表的最小宽度。
  static const double listMinWidth = 360;

  /// 宽度为 [width] 时能否放下详情栏。
  static bool canShowPane(double width) =>
      width - sidebarWidth - AppSpacing.l >=
      listMinWidth + TodoDetailPane.width;

  final double width;
  final double topInset;
  final Widget sidebar;
  final Widget Function(double width) list;

  /// 详情栏正在看的那一条；null 时不显示详情栏。
  final String? detailId;
  final VoidCallback onCloseDetail;
  final ValueChanged<String> onDeleteDetail;

  @override
  Widget build(BuildContext context) {
    final rest = width - sidebarWidth - AppSpacing.l;
    final detailId = canShowPane(width) ? this.detailId : null;
    final listWidth = detailId == null ? rest : rest - TodoDetailPane.width;
    return Padding(
      padding: EdgeInsets.only(top: topInset, left: AppSpacing.l),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.l),
            child: SizedBox(width: sidebarWidth, child: sidebar),
          ),
          Expanded(child: list(listWidth)),
          if (detailId != null)
            SizedBox(
              width: TodoDetailPane.width,
              child: TodoDetailPane(
                todoId: detailId,
                onClose: onCloseDetail,
                onDelete: () => onDeleteDetail(detailId),
              ),
            ),
        ],
      ),
    );
  }
}

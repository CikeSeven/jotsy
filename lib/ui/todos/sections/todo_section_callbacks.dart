import 'package:flutter/widgets.dart';

import '../../../core/database/app_database.dart';

/// 清单视图里分区的操作（页面持有写库与面板；只在单个清单视图里给出，
/// 收集箱与智能视图没有分区）。
class TodoSectionCallbacks {
  const TodoSectionCallbacks({
    required this.sections,
    required this.onCreate,
    required this.onAddTodo,
    required this.onRename,
    required this.onMove,
    required this.onDelete,
    required this.onReorder,
  });

  /// 这个清单的分区（按顺序；菜单据此判断能否上移 / 下移）。
  final List<TodoSection> sections;

  /// 列表末尾“添加分区”。
  final VoidCallback onCreate;

  /// 分区标题上的“+”：在这个分区里新建。
  final ValueChanged<TodoSection> onAddTodo;
  final ValueChanged<TodoSection> onRename;

  /// 上移（-1）/ 下移（+1）。
  final void Function(TodoSection section, int delta) onMove;
  final ValueChanged<TodoSection> onDelete;

  /// 手动排序时把 [rows]（开放区此刻的先后）里第 [oldIndex] 条拖到
  /// [newIndex]（已修正），并放进松手处的分区 [sectionId]（null 为未分区）。
  final void Function(
    List<TodoRow> rows,
    int oldIndex,
    int newIndex,
    String? sectionId,
  )
  onReorder;
}

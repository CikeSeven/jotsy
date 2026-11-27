import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../models/todo_settings.dart';

/// 待办列表与页面之间的约定：列表把交互交给 [TodoListCallbacks]（写库、
/// 导航与多选由页面与 controllers 处理），按 [TodoListRowState] 画各行的
/// 临时状态。

/// 待办列表的回调（页面持有写库、导航与多选）。
class TodoListCallbacks {
  const TodoListCallbacks({
    required this.onToggle,
    required this.onSwipeToggle,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
    required this.onMoveToList,
    required this.onMoveOverdueToToday,
    required this.onReschedule,
    required this.onToggleSteps,
    required this.onToggleStep,
    required this.onReorder,
    required this.onReorderStart,
    required this.onReorderEnd,
  });

  /// 点方框勾选 / 取消（行内动效已播完）。
  final ValueChanged<TodoRow> onToggle;

  /// 右滑完成 / 恢复（行已滑出并收起，直接写库）。
  final ValueChanged<TodoRow> onSwipeToggle;
  final ValueChanged<TodoRow> onTap;
  final ValueChanged<TodoRow> onLongPress;
  final ValueChanged<TodoRow> onDelete;
  final ValueChanged<TodoRow> onMoveToList;
  final ValueChanged<List<TodoRow>> onMoveOverdueToToday;

  /// 改期（左滑设为改期时、右键菜单、读屏动作）：弹改期面板，这一行留在
  /// 原位。
  final ValueChanged<TodoRow> onReschedule;

  /// 点步骤胶囊：就地展开 / 收起这一行的步骤。
  final ValueChanged<TodoRow> onToggleSteps;

  /// 勾选展开后的某一步。
  final void Function(TodoRow row, TodoStep step) onToggleStep;

  /// 把 [rows]（这一组此刻显示的顺序）里第 [oldIndex] 条拖到 [newIndex]
  /// （已修正的插入位置）。
  final void Function(List<TodoRow> rows, int oldIndex, int newIndex) onReorder;
  final ValueChanged<int> onReorderStart;
  final ValueChanged<int> onReorderEnd;
}

/// 列表行的临时状态（页面持有）：多选、正在收起、刚出现、详情栏正在看的、
/// 展开了步骤的，以及左滑的动作（来自设置）。
class TodoListRowState {
  const TodoListRowState({
    this.selectionMode = false,
    this.selected = const <String>{},
    this.leaving = const <String>{},
    this.appearing = const <String>{},
    this.highlightedId,
    this.expandedSteps = const <String>{},
    this.swipeLeft = TodoSwipeAction.delete,
  });

  final bool selectionMode;
  final Set<String> selected;

  /// 勾选后正在收起、还没写库的行。
  final Set<String> leaving;

  /// 页面打开之后才出现的行（新建、同步来的）：从 0 展开进场。
  final Set<String> appearing;

  /// 宽窗口详情栏正在看的那一条（高亮）。
  final String? highlightedId;

  /// 步骤就地展开的行。
  final Set<String> expandedSteps;

  /// 手机上左滑（RTL 右滑）的动作。
  final TodoSwipeAction swipeLeft;
}

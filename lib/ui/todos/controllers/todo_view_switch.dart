import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../diaries/controllers/diary_list_switch_motion.dart';
import '../models/todo_view.dart';

/// 切换视图（今天 / 计划 / 某个清单……）的编排：旧列表整齐退场 → 在完全
/// 看不见的那一帧换成新视图 → 新列表自上而下错峰入场。与日记列表整体切换
/// 同一套动效（[DiaryListSwitchMotion]，各项经 `DiaryListSwitchReveal` 读取），
/// 两个 Tab 的手感一致。
///
/// 方向按视图在视图面板里的先后（[directionOf]）：往后的视图从右边进来、
/// 旧的往左边走，往前的相反。
///
/// 连点：退场途中又选了别的视图时，退场照旧走完、换成最后选的那个（入场
/// 方向按最后一次）；入场途中再选时从当前画面退场。减少动态效果、或页面
/// 不在屏上（另一个 Tab，动画不会走）时直接换。
class TodoViewSwitch {
  TodoViewSwitch({required TickerProvider vsync, required this.onSwap})
    : motion = DiaryListSwitchMotion(vsync: vsync);

  final DiaryListSwitchMotion motion;

  /// 在列表看不见的那一帧换成 [TodoView]（页面 setState）。
  final ValueChanged<TodoView> onSwap;

  TodoView? _target;
  int _direction = 0;
  bool _exiting = false;
  bool _disposed = false;

  /// 正要换去的视图（退场途中）；没有时为 null。视图面板与左栏据此立即
  /// 标出新的选中，不等退场走完。
  TodoView? get target => _target;

  /// 从 [from] 换到 [to] 的方向：在视图面板里往后为 +1、往前为 -1、同一个
  /// 为 0。智能视图按 [kTodoSmartViews] 在前，清单按拖动顺序（[lists]）在后，
  /// 标签都在最后（标签之间为 0，只淡入淡出）。
  static int directionOf(TodoView from, TodoView to, List<TodoListRow> lists) =>
      (_orderOf(to, lists) - _orderOf(from, lists)).sign;

  static int _orderOf(TodoView view, List<TodoListRow> lists) {
    final smart = view.smart;
    if (smart != null) return kTodoSmartViews.indexOf(smart);
    if (view.tag != null) return kTodoSmartViews.length + lists.length + 1;
    final index = lists.indexWhere((list) => list.listId == view.listId);
    return kTodoSmartViews.length + (index < 0 ? lists.length : index);
  }

  /// 换到 [next]；[direction] 为 +1（往后的视图）、-1（往前）或 0。
  Future<void> switchTo(
    BuildContext context,
    TodoView next, {
    required int direction,
  }) async {
    _target = next;
    _direction = direction;
    if (ExpressiveMotion.reduceMotion(context) ||
        !TickerMode.getValuesNotifier(context).value.enabled) {
      _target = null;
      motion.settle();
      onSwap(next);
      return;
    }
    if (_exiting) return;
    _exiting = true;
    await motion.exit(direction);
    _exiting = false;
    if (_disposed) return;
    final view = _target;
    _target = null;
    if (view == null) return;
    motion.prepareEnter(_direction);
    onSwap(view);
    // 新列表排好之后再起入场：错峰锚点取第一个被构建的项（见
    // [DiaryListSwitchMotion.slotFor]）。
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) unawaited(motion.enter());
    });
  }

  void dispose() {
    _disposed = true;
    motion.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../models/todo_view.dart';

/// 桌面待办页的键盘焦点行（只在 `AppPlatform.isDesktop` 时由页面挂上）。
///
/// 按键只在页面自己的焦点节点拿着焦点时处理（输入框里的按键归输入框）：
/// - ↑ / ↓：在当前列表里移动焦点行，并把它滚进视野（[rowKey] 挂在焦点行
///   上）；
/// - 空格：勾选 / 取消；回车：打开详情；Delete / Backspace：删除（可撤销）；
///   Ctrl / ⌘ + D：改期；F：为焦点行开始专注（专注计时开着时）；
/// - Alt + 1…6：切到第 n 个智能视图（Ctrl / ⌘ + 数字留给首页切 Tab）；
/// - Esc：先退出多选，再关详情栏，最后放下焦点行。
///
/// 焦点行被勾走（离开视图）后，下一次移动从它原来的位置接着走（[_index]）。
class TodoKeyboardCursor {
  TodoKeyboardCursor({required this.onChanged});

  final VoidCallback onChanged;

  /// 焦点行的业务 id；null 为没有焦点行。
  String? id;

  /// 焦点行最近一次所在的下标（它离开列表后从这里接着走）。
  int _index = -1;

  /// 挂在焦点行上，移动后据此滚进视野。
  final GlobalKey rowKey = GlobalKey(debugLabel: 'todo_keyboard_row');

  /// 在 [rows] 里往下（[delta] 为 1）或往上（-1）移一行；没有焦点行时从第一
  /// 行（往上时最后一行）开始。
  void move(List<TodoRow> rows, int delta) {
    if (rows.isEmpty) return;
    final index = id == null
        ? -1
        : rows.indexWhere((TodoRow row) => row.todoId == id);
    final int next;
    if (index >= 0) {
      next = index + delta;
    } else if (_index >= 0) {
      // 焦点行已离开：补到它原位置上的那一行就是“下一行”。
      next = delta > 0 ? _index : _index - 1;
    } else {
      next = delta > 0 ? 0 : rows.length - 1;
    }
    _index = next.clamp(0, rows.length - 1);
    id = rows[_index].todoId;
    onChanged();
  }

  /// 焦点行此刻的那一行（不在 [rows] 里时为 null）。
  TodoRow? rowIn(List<TodoRow> rows) {
    final current = id;
    if (current == null) return null;
    for (final row in rows) {
      if (row.todoId == current) return row;
    }
    return null;
  }

  void clear() {
    if (id == null) return;
    id = null;
    _index = -1;
    onChanged();
  }

  /// 把焦点行滚进视野（往下移时贴底、往上移时贴顶，已在视野里不动）。
  void reveal(BuildContext context, int delta) {
    final rowContext = rowKey.currentContext;
    if (rowContext == null) return;
    Scrollable.ensureVisible(
      rowContext,
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      curve: ExpressiveMotion.spatial,
      alignmentPolicy: delta > 0
          ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
          : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
  }
}

/// 键盘焦点行要做的事（页面接上各自的流程）。
class TodoKeyboardActions {
  const TodoKeyboardActions({
    required this.move,
    required this.toggle,
    required this.open,
    required this.delete,
    required this.reschedule,
    required this.selectView,
    required this.escape,
    this.focus,
  });

  final ValueChanged<int> move;
  final VoidCallback toggle;
  final VoidCallback open;
  final VoidCallback delete;
  final VoidCallback reschedule;
  final ValueChanged<TodoView> selectView;

  /// 为焦点行开始专注；null 时 F 不处理（专注计时关着）。
  final VoidCallback? focus;

  /// 返回是否处理了（没有可退出的东西时不吞掉 Esc）。
  final bool Function() escape;

  static const List<LogicalKeyboardKey> _digits = <LogicalKeyboardKey>[
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
  ];

  /// 处理一次按下（含长按连发）；认得的键返回 handled。
  KeyEventResult handle(KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    final key = event.logicalKey;
    final primary = keys.isControlPressed || keys.isMetaPressed;
    if (keys.isAltPressed && !primary) {
      final index = _digits.indexOf(key);
      if (index >= 0 && index < kTodoSmartViews.length) {
        selectView(TodoView.smart(kTodoSmartViews[index]));
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (primary) {
      if (key == LogicalKeyboardKey.keyD) {
        reschedule();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      move(1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      move(-1);
    } else if (key == LogicalKeyboardKey.space) {
      toggle();
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      open();
    } else if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      delete();
    } else if (key == LogicalKeyboardKey.escape) {
      return escape() ? KeyEventResult.handled : KeyEventResult.ignored;
    } else if (key == LogicalKeyboardKey.keyF && focus != null) {
      focus!();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }
}

import 'package:flutter/widgets.dart';

import '../../../core/database/app_database.dart';

/// 待办页的多选状态（页面持有，纯内存）。
///
/// 状态：未多选 ↔ 多选（[active]）。长按一行或桌面 Ctrl / ⌘ 点按经 [enter]
/// 进入；多选里点行经 [toggle] 增减（取消到一条不剩时仍留在多选，与日记页
/// 一致，靠 × 或返回键 [clear] 退出）；换视图、批量操作完成后退出。
/// [retain] 在每次构建时去掉已不在当前列表里的选中（被同步删掉、勾选完成
/// 后离开视图），不通知。[onChanged] 只在进出多选或选中变化时调用，参数为
/// 是否在多选。
class TodoPageSelection {
  TodoPageSelection({required this.onChanged});

  final ValueChanged<bool> onChanged;

  bool _active = false;
  final Set<String> _ids = <String>{};

  bool get active => _active;

  /// 选中的业务 id。
  Set<String> get ids => Set<String>.unmodifiable(_ids);

  void enter(String todoId) {
    _active = true;
    _ids.add(todoId);
    onChanged(true);
  }

  void toggle(String todoId) {
    if (!_ids.remove(todoId)) _ids.add(todoId);
    onChanged(_active);
  }

  void clear() {
    if (!_active) return;
    _active = false;
    _ids.clear();
    onChanged(false);
  }

  bool containsAll(List<TodoRow> rows) =>
      rows.isNotEmpty && rows.every((row) => _ids.contains(row.todoId));

  /// 全选当前列表；已全选时取消全选（仍留在多选）。
  void toggleAll(List<TodoRow> rows) {
    if (containsAll(rows)) {
      _ids.clear();
    } else {
      _ids.addAll(rows.map((row) => row.todoId));
    }
    onChanged(_active);
  }

  void retain(List<TodoRow> rows) {
    if (_ids.isEmpty) return;
    final visible = <String>{for (final row in rows) row.todoId};
    _ids.removeWhere((id) => !visible.contains(id));
  }

  /// 当前列表里被选中的行（按列表顺序）。
  List<TodoRow> selectedRows(List<TodoRow> rows) => <TodoRow>[
    for (final row in rows)
      if (_ids.contains(row.todoId)) row,
  ];
}

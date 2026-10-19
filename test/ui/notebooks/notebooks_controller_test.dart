import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/notebooks/controllers/notebooks_controller.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_view.dart';

/// 分组内拖动排序换算成全局顺序：其他分组的相对顺序不变、置顶始终在前。
void main() {
  var nextId = 0;
  NotebookView view(
    String id, {
    required int sortOrder,
    bool pinned = false,
    NotebookKind kind = NotebookKind.manual,
  }) {
    final now = DateTime(2026, 10, 18);
    return NotebookView(
      NotebookRow(
        id: ++nextId,
        notebookId: id,
        name: id,
        kind: kind.name,
        visibility: NotebookVisibility.normal.name,
        payload: '{}',
        sortOrder: sortOrder,
        isPinned: pinned,
        isClosed: false,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  test('fills the section slots and keeps other sections in place', () {
    final all = <NotebookView>[
      view('a', sortOrder: 0),
      view('s', sortOrder: 1, kind: NotebookKind.smart),
      view('b', sortOrder: 2),
      view('c', sortOrder: 3),
    ];
    final order = notebookOrderAfterReorder(all, <String>['c', 'a', 'b']);
    expect(order.manual, <String>['c', 's', 'a', 'b']);
    expect(order.shelf, <String>['c', 's', 'a', 'b']);
  });

  test('pinned notebooks stay first in the expected shelf order', () {
    final all = <NotebookView>[
      view('p', sortOrder: 5, pinned: true),
      view('a', sortOrder: 1),
      view('b', sortOrder: 2),
    ];
    // 把 b 拖到置顶的 p 上方。
    final order = notebookOrderAfterReorder(all, <String>['b', 'p', 'a']);
    expect(order.manual, <String>['b', 'p', 'a']);
    expect(order.shelf, <String>['p', 'b', 'a']);
  });

  test('ignores ids that are no longer on the shelf', () {
    final all = <NotebookView>[
      view('a', sortOrder: 0),
      view('b', sortOrder: 1),
    ];
    final order = notebookOrderAfterReorder(all, <String>['gone', 'b', 'a']);
    expect(order.manual, <String>['b', 'a']);
  });
}

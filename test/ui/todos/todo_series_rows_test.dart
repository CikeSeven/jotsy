import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/todos/viewmodels/todo_series_rows.dart';

TodoRow _row(String todoId, {String? repeatOf, bool done = false}) {
  final at = DateTime(2026, 11, 28, 9);
  return TodoRow(
    id: todoId.hashCode,
    todoId: todoId,
    title: '学刮痧',
    note: '',
    priority: 0,
    reminders: '[]',
    steps: '[]',
    sortOrder: 0,
    metadata: repeatOf == null
        ? '{}'
        : jsonEncode(<String, Object?>{TodoMetadataKeys.repeatOf: repeatOf}),
    completedAt: done ? at : null,
    createdAt: at,
    updatedAt: at,
  );
}

/// 重复待办已完成的各次收进原待办（#382）。
void main() {
  test('done occurrences fold into their series and are counted', () {
    final entries = TodoSeriesRows.collapse(<TodoRow>[
      _row('series'),
      _row('other'),
      _row('copy-1', repeatOf: 'series', done: true),
      _row('copy-2', repeatOf: 'series', done: true),
    ]);
    expect(entries.map((e) => e.row.todoId), <String>['series', 'other']);
    expect(entries.map((e) => e.doneCount), <int>[2, 0]);
  });

  test('occurrences without their series, or reopened, stay listed', () {
    final entries = TodoSeriesRows.collapse(<TodoRow>[
      // 原待办不在列表里（删了或关联到了别处）。
      _row('orphan', repeatOf: 'gone', done: true),
      _row('series'),
      // 取消完成后已是一条普通待办。
      _row('reopened', repeatOf: 'series'),
    ]);
    expect(entries.map((e) => e.row.todoId), <String>[
      'orphan',
      'series',
      'reopened',
    ]);
    expect(entries.every((e) => e.doneCount == 0), isTrue);
    expect(TodoSeriesRows.seriesOf(_row('reopened', repeatOf: 'x')), isNull);
    expect(TodoSeriesRows.seriesOf(_row('c', repeatOf: 'x', done: true)), 'x');
  });
}

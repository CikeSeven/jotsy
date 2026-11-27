import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/todos/viewmodels/todo_streak.dart';
import 'package:node_diary/ui/todos/widgets/todo_note_extras.dart';

TodoRow _copy(String due, DateTime completedAt) => TodoRow(
  id: completedAt.millisecondsSinceEpoch,
  todoId: '$due@${completedAt.toIso8601String()}',
  title: '浇花',
  note: '',
  priority: 0,
  reminders: '[]',
  steps: '[]',
  sortOrder: 0,
  metadata: '{}',
  dueDate: due,
  completedAt: completedAt,
  createdAt: completedAt,
  updatedAt: completedAt,
);

/// 坚持记录：累计次数、准时连续次数与最近几周的完成格；备注里的链接。
void main() {
  test('streak counts on-time completions back from the latest', () {
    final today = DateTime(2026, 11, 27); // 周五
    final streak = TodoStreak.build(<TodoRow>[
      _copy('2026-11-26', DateTime(2026, 11, 26, 20)),
      _copy('2026-11-19', DateTime(2026, 11, 19, 8)),
      // 迟了一天：连续到这里断开。
      _copy('2026-11-12', DateTime(2026, 11, 13, 8)),
      _copy('2026-11-05', DateTime(2026, 11, 5, 8)),
    ], today);
    expect(streak.total, 4);
    expect(streak.streak, 2);
    expect(streak.days, hasLength(TodoStreak.defaultWeeks * 7));
    // 最后一列是本周：周一（11-23）起，周四完成一次，周六、周日还没到。
    final week = streak.days.sublist(streak.days.length - 7);
    expect(week, <int>[0, 0, 0, 1, 0, -1, -1]);
  });

  test('note links are found once each, without trailing punctuation', () {
    final links = TodoNoteExtras.linksIn(
      '看 https://example.com/a。还有 (https://flutter.dev) 和 '
      'https://example.com/a 以及 ftp://nope',
    );
    expect(links.map((u) => u.toString()), <String>[
      'https://example.com/a',
      'https://flutter.dev',
    ]);
  });
}

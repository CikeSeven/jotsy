import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/todo_rules.dart';

void main() {
  test('steps decode tolerantly and keep stable ids', () {
    final steps = decodeTodoSteps(
      '[{"id":"a","title":" 买菜 ","done":true},{"title":"洗碗"},'
      '{"id":"a","title":"重复"},{"title":""},3]',
    );
    expect(steps.map((s) => (s.id, s.title, s.done)), <(String, String, bool)>[
      ('a', '买菜', true),
      ('s1', '洗碗', false),
    ]);
    expect(decodeTodoSteps(encodeTodoSteps(steps)), steps);
    expect(decodeTodoSteps('not json'), isEmpty);
  });

  test('reminders skip invalid or unknown entries and duplicates', () {
    final reminders = decodeTodoReminders(
      '[{"kind":"beforeDue","minutes":15},{"kind":"beforeDue","minutes":15},'
      '{"kind":"onDay","days":-1,"minute":1200},{"kind":"onDay","days":2,'
      '"minute":60},{"kind":"future"},{"kind":"beforeDue","minutes":-5}]',
    );
    expect(reminders, const <TodoReminder>[
      TodoReminder.beforeDue(15),
      TodoReminder.onDay(days: -1, minute: 1200),
    ]);
    expect(decodeTodoReminders(encodeTodoReminders(reminders)), reminders);
  });

  test('reminder fire times use wall-clock components', () {
    final due = DateTime(2026, 11, 9);
    expect(
      const TodoReminder.beforeDue(15).fireAt(due, 9 * 60),
      DateTime(2026, 11, 9, 8, 45),
    );
    expect(const TodoReminder.beforeDue(15).fireAt(due, null), isNull);
    expect(
      const TodoReminder.onDay(days: -1, minute: 20 * 60).fireAt(due, null),
      DateTime(2026, 11, 8, 20),
    );
  });

  test('repeat rule round-trips and unknown frequency reads as none', () {
    final rule = TodoRepeatRule(
      frequency: TodoRepeatFrequency.weekly,
      interval: 2,
      weekdays: const <int>[DateTime.friday, DateTime.monday, 9],
      anchor: DateTime(2026, 11, 2),
      until: DateTime(2027, 1, 1),
    );
    final decoded = decodeTodoRepeat(encodeTodoRepeat(rule))!;
    expect(decoded.weekdays, <int>[DateTime.monday, DateTime.friday]);
    expect(decoded.interval, 2);
    expect(decoded.until, DateTime(2027, 1, 1));
    expect(decodeTodoRepeat('{"freq":"lunar","anchor":"2026-11-02"}'), isNull);
    expect(decodeTodoRepeat('{"freq":"daily"}'), isNull, reason: '缺起点');
  });

  test('sort order midpoints and occurrence ids', () {
    expect(TodoSortOrder.between(null, null), 0);
    expect(TodoSortOrder.between(null, 10), 10 - TodoSortOrder.gap);
    expect(TodoSortOrder.between(10, null), 10 + TodoSortOrder.gap);
    expect(TodoSortOrder.between(1, 2), 1.5);
    expect(TodoSortOrder.between(1, 1 + 1e-9), isNull);
    final id = todoOccurrenceId('todo-1', '2026-11-09');
    expect(id, todoOccurrenceId('todo-1', '2026-11-09'));
    expect(id, isNot(todoOccurrenceId('todo-1', '2026-11-10')));
    expect(id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-')));
  });

  test('priority clamps out-of-range values', () {
    expect(TodoPriority.of(-1), TodoPriority.none);
    expect(TodoPriority.of(2), TodoPriority.medium);
    expect(TodoPriority.of(9), TodoPriority.high);
  });
}

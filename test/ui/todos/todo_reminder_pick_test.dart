import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/todos/viewmodels/todo_reminder_pick.dart';
import 'package:node_diary/ui/todos/widgets/todo_reminder_sheet.dart';

import '../../support/expressive_test_theme.dart';

void main() {
  final due = DateTime(2030, 3, 10);

  group('resolveTodoReminderPick', () {
    test('a day before an all-day due stays relative without moving', () {
      final pick = resolveTodoReminderPick(
        due: due,
        dueMinute: null,
        date: DateTime(2030, 3, 8),
        minute: 9 * 60,
      );
      expect(pick.reminder, const TodoReminder.onDay(days: -2, minute: 540));
      expect(pick.dueMove, isNull);
    });

    test('a later day moves an all-day due and reminds on that day', () {
      final pick = resolveTodoReminderPick(
        due: due,
        dueMinute: null,
        date: DateTime(2030, 4, 2),
        minute: 21 * 60,
      );
      expect(pick.reminder, const TodoReminder.onDay(days: 0, minute: 1260));
      expect(pick.dueMove, (date: DateTime(2030, 4, 2), minute: null));
    });

    test('a later day keeps a timed due time when the reminder is earlier', () {
      final pick = resolveTodoReminderPick(
        due: due,
        dueMinute: 18 * 60,
        date: DateTime(2030, 3, 15),
        minute: 9 * 60,
      );
      expect(pick.reminder, const TodoReminder.onDay(days: 0, minute: 540));
      expect(pick.dueMove, (date: DateTime(2030, 3, 15), minute: 1080));
    });

    test('a later moment than a timed due moves the due to it', () {
      final later = resolveTodoReminderPick(
        due: due,
        dueMinute: 9 * 60,
        date: DateTime(2030, 3, 15),
        minute: 14 * 60,
      );
      expect(later.reminder, const TodoReminder.beforeDue(0));
      expect(later.dueMove, (date: DateTime(2030, 3, 15), minute: 840));

      // 同一天、晚于截止时刻：只顺延时刻，选的时刻不丢。
      final sameDay = resolveTodoReminderPick(
        due: due,
        dueMinute: 9 * 60,
        date: due,
        minute: 14 * 60,
      );
      expect(sameDay.reminder, const TodoReminder.beforeDue(0));
      expect(sameDay.dueMove, (date: due, minute: 840));
    });

    test('the due day itself at or before the due time does not move it', () {
      final pick = resolveTodoReminderPick(
        due: due,
        dueMinute: 9 * 60,
        date: due,
        minute: 9 * 60,
      );
      expect(pick.reminder, const TodoReminder.onDay(days: 0, minute: 540));
      expect(pick.dueMove, isNull);
    });
  });

  testWidgets('custom reminder can pick a day after the due date', (
    tester,
  ) async {
    final moves = <TodoDueMove>[];
    final changes = <List<TodoReminder>>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        theme: expressiveTestTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showTodoReminderSheet(
                  context,
                  reminders: const <TodoReminder>[],
                  dueDate: due,
                  dueMinute: null,
                  allDayMinute: 9 * 60,
                  onChanged: changes.add,
                  onDueMoved: moves.add,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final l10n = tester.element(find.text('open')).l10n;
    await tester.tap(find.text(l10n.todoReminderCustom));
    await tester.pumpAndSettle();
    // 截止日 3 月 10 日之后的 20 日可以点（以前的上限就是截止日）。
    await tester.tap(find.text('20'));
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    // 时间选择器按全天提醒的默认时刻打开，直接确定。
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(moves, <TodoDueMove>[(date: DateTime(2030, 3, 20), minute: null)]);
    expect(changes, <List<TodoReminder>>[
      const <TodoReminder>[TodoReminder.onDay(days: 0, minute: 540)],
    ]);
  });
}

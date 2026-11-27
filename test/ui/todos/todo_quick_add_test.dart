import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/todos/pages/todos_page.dart';
import 'package:node_diary/ui/todos/viewmodels/todo_quick_add_draft.dart';
import 'package:node_diary/ui/todos/viewmodels/todo_quick_parse.dart';
import 'package:node_diary/ui/todos/widgets/todo_labels.dart';
import 'package:node_diary/ui/todos/widgets/todo_quick_add_sheet.dart';

import 'todos_page_harness.dart';

/// 快速新建：识别出的重复与提醒落在属性按钮上、连续记录的“已添加”堆栈、
/// 多行粘贴的拆分，以及内联新建的重复识别。
void main() {
  Future<void> settle(WidgetTester tester) async {
    await settleTodos(tester);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<AppDatabase> openSheet(WidgetTester tester) async {
    // 够宽：一排属性按钮都排得下（横向列表只建看得见的）。
    final db = await pumpTodosPage(tester, width: 900, height: 1000);
    // 不 await：面板一直开着，直到测试结束卸载。
    showTodoQuickAddSheet(tester.element(find.byType(TodosPage))).ignore();
    await settle(tester);
    return db;
  }

  Finder sheetField() => find.descendant(
    of: find.byType(BottomSheet),
    matching: find.byType(TextField),
  );

  testWidgets('parsed repeat and reminder land on the pills and are saved', (
    tester,
  ) async {
    final db = await openSheet(tester);
    final l10n = todoL10n(tester);
    final context = tester.element(find.byType(TodosPage));
    await tester.enterText(sheetField(), '每天 9点 背单词 提前10分钟');
    await settle(tester);
    final rule = TodoRepeatRule(
      frequency: TodoRepeatFrequency.daily,
      anchor: todoToday,
    );
    expect(find.text(TodoLabels.repeat(l10n, rule)), findsOneWidget);
    expect(
      find.text(TodoLabels.reminder(context, const TodoReminder.beforeDue(10))),
      findsOneWidget,
    );

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    final row = await todoRowTitled(tester, db, '背单词');
    expect(decodeTodoRepeat(row.repeat)?.frequency, TodoRepeatFrequency.daily);
    expect(row.dueMinute, 9 * 60);
    expect(decodeTodoReminders(row.reminders), <TodoReminder>[
      const TodoReminder.beforeDue(10),
    ]);
    // 记进“已添加”，可撤销。
    expect(find.text(l10n.todoQuickAddedCount(1)), findsOneWidget);
    await tester.tap(find.byTooltip(l10n.todoQuickAddedUndo));
    await settle(tester);
    final open = await tester.runAsync(db.getOpenTodos);
    expect(open, isEmpty);
    await unmountTodos(tester);
  });

  testWidgets('pasted lines can be split into to-dos or kept as one', (
    tester,
  ) async {
    final db = await openSheet(tester);
    final l10n = todoL10n(tester);
    await tester.enterText(sheetField(), '买菜\n明天 交房租');
    await settle(tester);
    expect(find.text(l10n.todoQuickSplitPrompt(2)), findsOneWidget);
    await tester.tap(find.text(l10n.todoQuickSplit));
    await settle(tester);
    expect((await todoRowTitled(tester, db, '买菜')).dueDate, isNull);
    expect(
      (await todoRowTitled(tester, db, '交房租')).dueDate,
      formatAnniversaryDate(todoToday.add(const Duration(days: 1))),
    );
    expect(find.text(l10n.todoQuickAddedCount(2)), findsOneWidget);

    await tester.enterText(sheetField(), '一\n二');
    await settle(tester);
    await tester.tap(find.text(l10n.todoQuickKeepOne));
    await settle(tester);
    expect(tester.widget<TextField>(sheetField()).controller!.text, '一 二');
    await unmountTodos(tester);
  });

  testWidgets('inline add recognizes a weekly repeat', (tester) async {
    final db = await pumpTodosPage(tester);
    final l10n = todoL10n(tester);
    await tester.tap(find.text(l10n.todoInlineAddHint));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), '每周一三 例会');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settleTodos(tester);
    final row = await todoRowTitled(tester, db, '例会');
    final rule = decodeTodoRepeat(row.repeat)!;
    expect(rule.frequency, TodoRepeatFrequency.weekly);
    expect(rule.weekdays, <int>[1, 3]);
    await unmountTodos(tester);
  });

  group('TodoQuickAddDraft', () {
    final today = DateTime(2026, 11, 8);
    TodoQuickParse parse(TodoQuickAddDraft draft, String text) =>
        parseTodoQuickInput(text, today: today, ignore: draft.ignore);

    test('picking a date keeps what was parsed as manual values', () {
      final draft = TodoQuickAddDraft();
      final p = parse(draft, '每天 9点 背单词 提前10分钟');
      draft.pickDue(DateTime(2026, 11, 10), 9 * 60, p, allDayMinute: 540);
      final after = parse(draft, '每天 9点 背单词 提前10分钟');
      // 日期、时刻、重复、提醒都不再识别，以手动值为准。
      expect(after.tokens, isEmpty);
      expect(draft.effRepeat(after)?.anchor, DateTime(2026, 11, 10));
      expect(draft.effReminders(after, 540), <TodoReminder>[
        const TodoReminder.beforeDue(10),
      ]);
      // 改成全天：按分钟提前的提醒随之去掉。
      draft.pickDue(DateTime(2026, 11, 10), null, after, allDayMinute: 540);
      expect(draft.effReminders(after, 540), isEmpty);
    });

    test('clearing the date drops repeat and reminders', () {
      final draft = TodoQuickAddDraft(dueDate: today);
      final p = parse(draft, '每天 背单词');
      expect(draft.effRepeat(p), isNotNull);
      draft.clearDue();
      final after = parse(draft, '每天 背单词');
      expect(draft.effDate(after), isNull);
      expect(draft.effRepeat(after), isNull);
      expect(
        draft.inputFor('每天 背单词', after, allDayMinute: 540)?.repeat,
        isNull,
      );
    });
  });
}

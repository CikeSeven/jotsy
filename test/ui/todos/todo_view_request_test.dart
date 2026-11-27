import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/todos/models/todo_settings.dart';
import 'package:node_diary/ui/todos/models/todo_view.dart';
import 'package:node_diary/ui/todos/pages/todos_page.dart';
import 'package:node_diary/ui/todos/providers/todo_reminder_providers.dart';

import 'todos_page_harness.dart';

void main() {
  testWidgets(
    'a view request (tapping the daily digest) switches the page to today',
    (tester) async {
      await pumpTodosPage(
        tester,
        todoSettings: const TodoSettings(defaultViewKey: 'all'),
        seed: (AppDatabase db) async {
          await db.createTodo(TodoInput(title: '今天的', dueDate: todoToday));
          await db.createTodo(const TodoInput(title: '没日期'));
        },
      );
      expect(openTodoTitles(tester), containsAll(<String>['今天的', '没日期']));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TodosPage)),
      );
      container.read(todoViewRequestProvider.notifier).request(TodoView.today);
      await tester.pumpAndSettle();
      await settleTodos(tester);

      expect(openTodoTitles(tester), <String>['今天的']);
      expect(
        container.read(todoViewRequestProvider),
        isNull,
        reason: '请求被消费，回到这页时不会再换一次',
      );
      await unmountTodos(tester);
    },
  );
}

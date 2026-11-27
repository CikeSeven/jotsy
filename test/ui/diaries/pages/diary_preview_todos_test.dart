import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/todos/widgets/diary_linked_todos_section.dart';
import 'package:node_diary/ui/todos/widgets/todo_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 预览页的待办入口：“更多”里的添加待办与转为独立待办、正文后的相关待办；
/// 待办功能关闭时都不出现。
void main() {
  late AppDatabase database;
  late String diaryId;

  final checklistBody = jsonEncode(<String, Object?>{
    'document': <String, Object?>{
      'type': 'page',
      'children': <Object?>[
        <String, Object?>{
          'type': 'todo_list',
          'data': <String, Object?>{
            'checked': false,
            'delta': <Object?>[
              <String, Object?>{'insert': '买菜'},
            ],
          },
        },
        <String, Object?>{
          'type': 'todo_list',
          'data': <String, Object?>{
            'checked': true,
            'delta': <Object?>[
              <String, Object?>{'insert': '洗碗'},
            ],
          },
        },
      ],
    },
  });

  Future<void> setUpDiary({String? features, String? body}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.settings.app_features': ?features,
    });
    database = AppDatabase.forTesting(NativeDatabase.memory());
    diaryId = await database.createDiary(
      title: '周末',
      contentDocJson: body ?? '[{"insert":"正文\\n"}]',
      contentText: '正文',
      metadataJson: '{}',
    );
  }

  tearDown(() => database.close());

  Future<AppLocalizations> pumpPreview(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiaryPreviewPage(diaryId: diaryId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.element(find.byType(DiaryPreviewPage)).l10n;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('checklist items become linked to-dos; the body is unchanged', (
    tester,
  ) async {
    await setUpDiary(features: '{"todos":true}', body: checklistBody);
    final l10n = await pumpPreview(tester);

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.diaryPreviewAddTodo), findsOneWidget);
    await tester.tap(find.text(l10n.diaryPreviewConvertTodos));
    await tester.pumpAndSettle();
    // 未勾选的“买菜”默认选中，已勾选的“洗碗”不选。
    await tester.tap(find.text(l10n.todoConvertSubmit(1)));
    await tester.pumpAndSettle();

    final todos = await tester.runAsync(database.getOpenTodos);
    expect(todos!.single.title, '买菜');
    expect(todos.single.linkedDiaryId, diaryId);
    final diary = await tester.runAsync(
      () => database.select(database.diaries).getSingle(),
    );
    expect(diary!.content, checklistBody);
    // 新的待办出现在正文后的“相关待办”里。
    await tester.pumpAndSettle();
    expect(find.byType(DiaryLinkedTodosSection), findsOneWidget);
    expect(
      tester.widgetList<TodoTile>(find.byType(TodoTile)).single.row.title,
      '买菜',
    );
    await unmount(tester);
  });

  testWidgets('a repeating to-do is one row; its done occurrences fold in', (
    tester,
  ) async {
    await setUpDiary(features: '{"todos":true}');
    final today = DateTime.now();
    await tester.runAsync(() async {
      final id = await database.createTodo(
        TodoInput(
          title: '学刮痧',
          dueDate: today.subtract(const Duration(days: 1)),
          repeat: TodoRepeatRule(
            frequency: TodoRepeatFrequency.daily,
            anchor: today.subtract(const Duration(days: 1)),
          ),
          linkedDiaryId: diaryId,
        ),
      );
      await database.completeTodo(id);
      await database.completeTodo(id);
    });
    final l10n = await pumpPreview(tester);

    final tile = tester.widget<TodoTile>(find.byType(TodoTile));
    expect(tile.row.completedAt, isNull, reason: '只剩原待办这一行');
    expect(tile.seriesDoneCount, 2);
    expect(find.text(l10n.todoSeriesDoneCount(2)), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('without checklist items only “add a to-do” is offered', (
    tester,
  ) async {
    await setUpDiary(features: '{"todos":true}');
    final l10n = await pumpPreview(tester);
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.diaryPreviewAddTodo), findsOneWidget);
    expect(find.text(l10n.diaryPreviewConvertTodos), findsNothing);
    await unmount(tester);
  });

  testWidgets('with to-dos off nothing is offered', (tester) async {
    await setUpDiary(body: checklistBody);
    final l10n = await pumpPreview(tester);
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.diaryPreviewAddTodo), findsNothing);
    expect(find.text(l10n.diaryPreviewConvertTodos), findsNothing);
    await unmount(tester);
  });
}

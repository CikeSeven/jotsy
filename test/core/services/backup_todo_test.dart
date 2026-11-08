import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/backup_import_models.dart';
import 'package:node_diary/core/services/data_archive_service.dart';

import '../../support/backup_test_fixture.dart';

/// 待办与清单随完整备份导出、覆盖恢复与合并；日记包不带待办。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupTestFixture fixture;
  late String listId;
  late String todoId;
  setUp(() async {
    fixture = await BackupTestFixture.create();
    await fixture.seedCurrentData();
    listId = await fixture.database.createTodoList(
      name: '工作',
      colorKey: 'blue',
    );
    todoId = await fixture.database.createTodo(
      TodoInput(
        title: '交周报',
        listId: listId,
        dueDate: DateTime(2026, 11, 13),
        dueMinute: 15 * 60,
        reminders: const <TodoReminder>[TodoReminder.beforeDue(30)],
        repeat: TodoRepeatRule(
          frequency: TodoRepeatFrequency.weekly,
          anchor: DateTime(2026, 11, 13),
        ),
        steps: const <TodoStep>[TodoStep(id: 'a', title: '整理数据')],
      ),
    );
  });
  tearDown(() => fixture.dispose());

  Future<List<TodoRow>> todos() =>
      fixture.database.select(fixture.database.todos).get();
  Future<List<TodoListRow>> lists() =>
      fixture.database.select(fixture.database.todoLists).get();

  Future<BackupImportResult> importWith(
    Map<String, Object?> payload,
    BackupImportMode mode,
  ) async {
    final zip = await fixture.writeZip(payload);
    return DataArchiveService.importFromZip(
      database: fixture.database,
      settingsService: fixture.settings,
      zipPath: zip.path,
      mode: mode,
    );
  }

  Future<BackupArchivePreview> preview(Map<String, Object?> payload) async {
    final zip = await fixture.writeZip(payload);
    return DataArchiveService.inspectZip(
      database: fixture.database,
      zipPath: zip.path,
    );
  }

  test('a full backup restores todos and lists exactly', () async {
    final originalTodos = await todos();
    final originalLists = await lists();
    final payload = await fixture.capturePayload();
    final tables = payload['database'] as Map;
    expect(tables['todos'], hasLength(1));
    expect(tables['todoLists'], hasLength(1));

    await fixture.database.deleteTodoList(listId);
    await fixture.database.createTodo(const TodoInput(title: 'later'));
    final result = await importWith(payload, BackupImportMode.replaceAll);

    expect(await todos(), originalTodos);
    expect(await lists(), originalLists);
    expect(result.addedTodos, 1);
  });

  test('an old backup without the tables clears todos, and the preview '
      'says how many', () async {
    final legacy = fixture.emptyPayload();
    final check = await preview(legacy);
    expect(check.localTodoCount, 1);
    expect(check.todoCount, 0);

    await importWith(legacy, BackupImportMode.replaceAll);
    expect(await todos(), isEmpty);
    expect(await lists(), isEmpty);
  });

  test(
    'a todo whose list is missing from the file lands in the inbox',
    () async {
      final payload = await fixture.capturePayload();
      (payload['database'] as Map)['todoLists'] = <Object?>[];
      await importWith(payload, BackupImportMode.replaceAll);
      expect((await todos()).single.listId, isNull);
    },
  );

  test('a backup with an invalid due date is rejected', () async {
    final payload = await fixture.capturePayload();
    final tables = payload['database'] as Map;
    final row = Map<String, Object?>.from(
      (tables['todos'] as List).single as Map,
    );
    tables['todos'] = <Object?>[
      {...row, 'dueDate': '2026-02-30'},
    ];
    await expectLater(
      importWith(payload, BackupImportMode.replaceAll),
      throwsA(anything),
    );
    expect((await todos()).single.dueDate, '2026-11-13');
  });

  group('merging', () {
    late Map<String, Object?> payload;
    setUp(() async {
      payload = await fixture.capturePayload();
      final tables = payload['database'] as Map;
      final existing = Map<String, Object?>.from(
        (tables['todos'] as List).single as Map,
      );
      final list = Map<String, Object?>.from(
        (tables['todoLists'] as List).single as Map,
      );
      tables['diaries'] = <Object?>[];
      tables['diaryTags'] = <Object?>[];
      tables['anniversaries'] = <Object?>[];
      tables['todoLists'] = <Object?>[
        {...list, 'name': '文件里的名字', 'sortOrder': 9999.0},
      ];
      tables['todos'] = <Object?>[
        {...existing, 'title': 'from the file'},
        {...existing, 'id': 99, 'todoId': 'other-device', 'title': 'new one'},
      ];
    });

    test('offers overwrite when only todos overlap', () async {
      final check = await preview(payload);
      expect(check.existingDiaryCount, 0);
      expect(check.todoCount, 2);
      expect(check.existingTodoCount, 1);
      expect(check.availableModes, contains(BackupImportMode.mergeOverwrite));
    });

    test('merge keeps the local version and adds the new one', () async {
      final result = await importWith(payload, BackupImportMode.merge);
      final rows = await todos();
      expect(rows.map((row) => row.title).toSet(), <String>{'交周报', 'new one'});
      expect(
        rows.firstWhere((r) => r.todoId == 'other-device').id,
        isNot(99),
        reason: '文件里的本地 id 不沿用',
      );
      expect((await lists()).single.name, '工作');
      expect((result.addedTodos, result.replacedTodos), (1, 0));
    });

    test(
      'merge-overwrite replaces in place but keeps the local list order',
      () async {
        final before = (await todos()).single;
        final listBefore = (await lists()).single;
        final result = await importWith(
          payload,
          BackupImportMode.mergeOverwrite,
        );
        final replaced = (await todos()).firstWhere((r) => r.todoId == todoId);
        expect(replaced.id, before.id);
        expect(replaced.title, 'from the file');
        final list = (await lists()).single;
        expect(list.name, '文件里的名字');
        expect(list.sortOrder, listBefore.sortOrder);
        expect((result.addedTodos, result.replacedTodos), (1, 1));
      },
    );
  });

  test('a diary package carries no todos and leaves them alone', () async {
    final diary = await fixture.database
        .select(fixture.database.diaries)
        .getSingle();
    final zip = await DataArchiveService.exportDiariesToZip(
      database: fixture.database,
      diaryIds: <String>[diary.diaryId],
    );
    final check = await DataArchiveService.inspectZip(
      database: fixture.database,
      zipPath: zip.path,
    );
    expect(check.todoCount, 0);
    await DataArchiveService.importFromZip(
      database: fixture.database,
      settingsService: fixture.settings,
      zipPath: zip.path,
      mode: BackupImportMode.mergeOverwrite,
    );
    expect((await todos()).single.title, '交周报');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/backup_import_models.dart';
import 'package:node_diary/core/services/data_archive_service.dart';

import '../../support/backup_test_fixture.dart';

/// 专注记录随完整备份导出与覆盖恢复；合并按业务 id 取并集（已有的不动）；
/// 旧备份没有这张表时覆盖恢复后为空。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupTestFixture fixture;
  late String sessionId;
  setUp(() async {
    fixture = await BackupTestFixture.create();
    await fixture.seedCurrentData();
    final todoId = await fixture.database.createTodo(
      const TodoInput(title: '写报告'),
    );
    sessionId = (await fixture.database.addTodoFocusSession(
      TodoFocusInput(
        todoId: todoId,
        startedAt: DateTime(2026, 11, 28, 9),
        endedAt: DateTime(2026, 11, 28, 9, 25),
        plannedSeconds: 1500,
        focusedSeconds: 1500,
        outcome: TodoFocusOutcome.completed,
      ),
    ))!;
  });
  tearDown(() => fixture.dispose());

  Future<List<TodoFocusRow>> sessions() =>
      fixture.database.select(fixture.database.todoFocusSessions).get();

  Future<void> importWith(
    Map<String, Object?> payload,
    BackupImportMode mode,
  ) async {
    final zip = await fixture.writeZip(payload);
    await DataArchiveService.importFromZip(
      database: fixture.database,
      settingsService: fixture.settings,
      zipPath: zip.path,
      mode: mode,
    );
  }

  test('a full backup restores the sessions exactly', () async {
    final original = await sessions();
    final payload = await fixture.capturePayload();
    expect((payload['database'] as Map)['todoFocusSessions'], hasLength(1));
    await fixture.database.delete(fixture.database.todoFocusSessions).go();
    await importWith(payload, BackupImportMode.replaceAll);
    expect(await sessions(), original);
  });

  test('an old backup without the table clears them', () async {
    await importWith(fixture.emptyPayload(), BackupImportMode.replaceAll);
    expect(await sessions(), isEmpty);
  });

  test('merging adds new sessions and leaves existing ones alone', () async {
    final payload = await fixture.capturePayload();
    final tables = payload['database'] as Map;
    final row = Map<String, Object?>.from(
      (tables['todoFocusSessions'] as List).single as Map,
    );
    tables['todoFocusSessions'] = <Object?>[
      row,
      <String, Object?>{
        ...row,
        'id': 99,
        'sessionId': 'other-device',
        'focusedSeconds': 600,
      },
    ];
    for (final mode in <BackupImportMode>[
      BackupImportMode.merge,
      BackupImportMode.mergeOverwrite,
    ]) {
      await importWith(payload, mode);
      final rows = await sessions();
      expect(rows.map((r) => r.sessionId).toSet(), <String>{
        sessionId,
        'other-device',
      });
      expect(
        rows.firstWhere((r) => r.sessionId == 'other-device').id,
        isNot(99),
      );
    }
  });
}

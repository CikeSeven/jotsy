import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/backup_import_models.dart';
import 'package:node_diary/core/services/data_archive_service.dart';

import '../../support/backup_test_fixture.dart';

/// 日记留言随完整备份与日记包导出、覆盖恢复，合并时按 commentId 匹配；
/// 旧备份没有这一项。夹具里本机只有一篇日记。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupTestFixture fixture;
  late String diaryId;
  setUp(() async {
    fixture = await BackupTestFixture.create();
    await fixture.seedCurrentData();
    diaryId =
        (await fixture.database.select(fixture.database.diaries).getSingle())
            .diaryId;
  });
  tearDown(() => fixture.dispose());

  AppDatabase db() => fixture.database;

  Future<List<DiaryCommentRow>> comments() =>
      db().watchDiaryComments(diaryId).first;

  Future<BackupImportResult> importWith(
    Map<String, Object?> payload,
    BackupImportMode mode,
  ) async {
    final zip = await fixture.writeZip(payload);
    return DataArchiveService.importFromZip(
      database: db(),
      settingsService: fixture.settings,
      zipPath: zip.path,
      mode: mode,
    );
  }

  List<Object?> fileComments(Map<String, Object?> payload) =>
      (payload['database'] as Map)['diaryComments'] as List<Object?>;

  test('a full backup restores every comment as it was', () async {
    final first = await db().addDiaryComment(diaryId: diaryId, content: '一');
    await db().addDiaryComment(diaryId: diaryId, content: '二', mood: '😊');
    await db().updateDiaryComment(first, content: '一（改）');
    final original = await comments();
    final payload = await fixture.capturePayload();
    expect(fileComments(payload), hasLength(2));

    await db().deleteDiaryComment(first);
    await db().addDiaryComment(diaryId: diaryId, content: '备份之后写的');
    final result = await importWith(payload, BackupImportMode.replaceAll);

    expect(await comments(), original);
    expect(result.addedComments, 2);
  });

  test(
    'restoring an old backup without the table clears the comments',
    () async {
      await db().addDiaryComment(diaryId: diaryId, content: '会被清掉');
      await importWith(fixture.emptyPayload(), BackupImportMode.replaceAll);
      expect(await db().select(db().diaryComments).get(), isEmpty);
    },
  );

  test('a blank comment is rejected and changes nothing', () async {
    final payload = await fixture.capturePayload();
    (payload['database'] as Map)['diaryComments'] = <Object?>[
      {
        'id': 1,
        'commentId': 'c-blank',
        'diaryId': diaryId,
        'content': '  ',
        'createdAt': 0,
      },
    ];
    await expectLater(
      importWith(payload, BackupImportMode.replaceAll),
      throwsA(isA<FormatException>()),
    );
    await fixture.expectCurrentDataIntact();
  });

  test('a comment whose diary is not in the file is dropped', () async {
    final payload = await fixture.capturePayload();
    (payload['database'] as Map)['diaryComments'] = <Object?>[
      {
        'id': 1,
        'commentId': 'c-ghost',
        'diaryId': 'not-in-the-file',
        'content': '找不到日记',
        'createdAt': 0,
      },
      {
        'id': 2,
        'commentId': 'c-kept',
        'diaryId': diaryId,
        'content': '留下',
        'createdAt': 0,
      },
    ];
    final result = await importWith(payload, BackupImportMode.replaceAll);
    final rows = await db().select(db().diaryComments).get();
    expect(rows.map((row) => row.commentId), <String>['c-kept']);
    expect(result.addedComments, 1);
  });

  group('merging', () {
    late Map<String, Object?> payload;
    late String sharedId;
    setUp(() async {
      sharedId = await db().addDiaryComment(diaryId: diaryId, content: '本机版本');
      payload = await fixture.capturePayload();
      final rows = fileComments(payload).cast<Map<String, Object?>>();
      rows.single['content'] = '文件版本';
      rows.add(<String, Object?>{
        'id': 99,
        'commentId': 'c-from-file',
        'diaryId': diaryId,
        'content': '只在文件里',
        'mood': '🙂',
        'createdAt': 0,
      });
    });

    Future<Map<String, String>> byId() async => <String, String>{
      for (final row in await comments()) row.commentId: row.content,
    };

    test('merge keeps the local comment and adds the new one', () async {
      final result = await importWith(payload, BackupImportMode.merge);
      expect(await byId(), <String, String>{
        sharedId: '本机版本',
        'c-from-file': '只在文件里',
      });
      expect((result.addedComments, result.replacedComments), (1, 0));
    });

    test('merge-overwrite takes the comment from the file', () async {
      final result = await importWith(payload, BackupImportMode.mergeOverwrite);
      expect(await byId(), <String, String>{
        sharedId: '文件版本',
        'c-from-file': '只在文件里',
      });
      expect((result.addedComments, result.replacedComments), (1, 1));
    });
  });

  test('a diary package carries the comments of its diaries', () async {
    final commentId = await db().addDiaryComment(
      diaryId: diaryId,
      content: '随日记走',
    );
    final zip = await DataArchiveService.exportDiariesToZip(
      database: db(),
      diaryIds: <String>[diaryId],
    );
    await db().deleteDiaryComment(commentId);

    final result = await DataArchiveService.importFromZip(
      database: db(),
      settingsService: fixture.settings,
      zipPath: zip.path,
      mode: BackupImportMode.merge,
    );
    expect((await comments()).single.content, '随日记走');
    expect(result.addedComments, 1);
  });
}

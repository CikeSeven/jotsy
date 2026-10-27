import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/backup_constants.dart';
import 'package:node_diary/core/services/backup_import_models.dart';
import 'package:node_diary/core/services/backup_payload.dart';
import 'package:node_diary/core/services/data_archive_service.dart';
import 'package:node_diary/core/services/diary_media_cleanup_service.dart';
import 'package:path/path.dart' as p;

import '../../support/backup_test_fixture.dart';

/// 日记本随完整备份导出与覆盖恢复；合并按 notebookId 并入定义、按日记与
/// 日记本两张 id 映射改写成员关系；日记包只带包内日记所在的手动日记本；
/// 日记本封面参与媒体回收、恢复与合并时的路径重绑。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 两个内存库分别模拟两台设备，各自独立的执行器，不存在 drift 警告的竞态。
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late BackupTestFixture fixture;
  late AppDatabase db;
  setUp(() async {
    fixture = await BackupTestFixture.create();
    db = fixture.database;
  });
  tearDown(() => fixture.dispose());

  Future<String> diary(AppDatabase database, String title) =>
      database.createDiary(
        title: title,
        contentDocJson: jsonEncode([
          {'insert': '$title\n'},
        ]),
        contentText: title,
        metadataJson: '{}',
      );

  Future<File> media(String relative, List<int> bytes) async {
    final file = File(
      p.joinAll([fixture.documents.path, ...relative.split('/')]),
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file;
  }

  /// 业务 id 视角的成员关系：日记本 → 按成书位置排好的 (日记, 章节, 位置)。
  Future<Map<String, List<(String, String?, int)>>> memberships(
    AppDatabase database,
  ) async {
    final diaries = {
      for (final row in await database.select(database.diaries).get())
        row.id: row.diaryId,
    };
    final notebooks = {
      for (final row in await database.select(database.notebooks).get())
        row.id: row.notebookId,
    };
    final rows = await database.select(database.diaryNotebooks).get()
      ..sort((a, b) => a.position.compareTo(b.position));
    final result = <String, List<(String, String?, int)>>{};
    for (final row in rows) {
      result.putIfAbsent(notebooks[row.notebookId]!, () => []).add((
        diaries[row.diaryId]!,
        row.chapterId,
        row.position,
      ));
    }
    return result;
  }

  Future<BackupImportResult> importZip(File zip, BackupImportMode mode) =>
      DataArchiveService.importFromZip(
        database: db,
        settingsService: fixture.settings,
        zipPath: zip.path,
        mode: mode,
      );

  Future<BackupImportResult> importPayload(
    Map<String, Object?> payload,
    BackupImportMode mode,
  ) async => importZip(await fixture.writeZip(payload), mode);

  Future<Directory> switchDocuments(String name) async => fixture.documents =
      await Directory(p.join(fixture.root.path, name)).create();

  String relative(String path) =>
      p.relative(path, from: fixture.documents.path).replaceAll('\\', '/');

  String? coverOf(NotebookRow row) => row.parsedPayload.coverPath;

  test('a full backup restores notebooks, memberships and rebinds covers '
      'into the new installation', () async {
    final first = await diary(db, 'first');
    final second = await diary(db, 'second');
    final cover = await media('diary_covers/notebook_cover.jpg', [7, 8, 9]);
    final travel = await db.createNotebook(
      name: '旅行',
      visibility: NotebookVisibility.locked,
      payload: NotebookPayload(
        description: '路上',
        coverPath: cover.path,
        chapters: [NotebookChapter(id: 'c1', title: '出发')],
      ),
    );
    await db.updateNotebook(travel, isPinned: true, isClosed: true);
    await db.addDiariesToNotebook(travel, [second, first], chapterId: 'c1');
    final smart = await db.createNotebook(
      name: '最近',
      kind: NotebookKind.smart,
      payload: NotebookPayload(rules: const {'tags': <String>[]}),
    );
    final before = await db.select(db.notebooks).get();
    final beforeMemberships = await memberships(db);

    final zip = await DataArchiveService.exportToZip(
      database: db,
      settingsService: fixture.settings,
    );
    await switchDocuments('restored_documents');
    // 恢复前本机另有一本，覆盖恢复后它必须消失。
    await db.createNotebook(name: 'later');
    final result = await importZip(zip, BackupImportMode.replaceAll);

    expect(result.addedNotebooks, 2);
    final after = await db.select(db.notebooks).get();
    expect(after.map((row) => row.notebookId).toSet(), {travel, smart});
    for (final row in after) {
      final original = before.singleWhere(
        (b) => b.notebookId == row.notebookId,
      );
      // 本地 id、类型、可见性、置顶与合上状态都原样保留。
      expect(row.copyWith(payload: original.payload), original);
    }
    final restoredTravel = after.singleWhere((row) => row.notebookId == travel);
    expect(restoredTravel.notebookVisibility, NotebookVisibility.locked);
    expect(restoredTravel.parsedPayload.description, '路上');
    expect(
      restoredTravel.parsedPayload.chapters.single,
      NotebookChapter(id: 'c1', title: '出发'),
    );
    expect(
      coverOf(restoredTravel),
      p.join(fixture.documents.path, 'diary_covers', 'notebook_cover.jpg'),
    );
    expect(await File(coverOf(restoredTravel)!).readAsBytes(), [7, 8, 9]);
    expect(await memberships(db), beforeMemberships);
    expect(beforeMemberships[travel], [(second, 'c1', 0), (first, 'c1', 1)]);
  });

  test('an old backup without the tables decodes to no notebooks and '
      'restoring it clears local ones, which the preview counts', () async {
    await fixture.seedCurrentData();
    final legacy = fixture.emptyPayload();
    final decoded = BackupPayload.decode(jsonEncode(legacy));
    expect(decoded.notebooks, isEmpty);
    expect(decoded.diaryNotebooks, isEmpty);

    final preview = await DataArchiveService.inspectZip(
      database: db,
      zipPath: (await fixture.writeZip(legacy)).path,
    );
    expect(preview.localNotebookCount, 1);
    // 日记本本身不决定是否提供“合并并覆盖”。
    expect(preview.availableModes, [
      BackupImportMode.merge,
      BackupImportMode.replaceAll,
    ]);

    await importPayload(legacy, BackupImportMode.replaceAll);
    expect(await db.select(db.notebooks).get(), isEmpty);
    expect(await db.select(db.diaryNotebooks).get(), isEmpty);
  });

  group('decoding', () {
    late Map<String, Object?> payload;
    late Map tables;
    setUp(() async {
      await fixture.seedCurrentData();
      await db.createNotebook(name: 'smart', kind: NotebookKind.smart);
      payload = await fixture.capturePayload();
      tables = payload['database'] as Map;
    });

    test('drops dangling memberships and any pointing at a smart '
        'notebook, keeping the rest', () async {
      final notebooks = tables['notebooks'] as List;
      final manual = notebooks.cast<Map>().singleWhere(
        (row) => row['kind'] == 'manual',
      );
      final smart = notebooks.cast<Map>().singleWhere(
        (row) => row['kind'] == 'smart',
      );
      final valid = (tables['diaryNotebooks'] as List).single as Map;
      (tables['diaryNotebooks'] as List).addAll([
        {...valid, 'notebookId': smart['id']},
        {...valid, 'diaryId': 999},
        {...valid, 'notebookId': 999},
      ]);
      final decoded = BackupPayload.decode(jsonEncode(payload));
      expect(decoded.notebooks, hasLength(2));
      expect(decoded.diaryNotebooks.single.notebookId, manual['id']);
    });

    test('duplicate notebook ids or memberships reject the backup', () {
      for (final mutate in <void Function(Map tables)>[
        // 本地 id 重复。
        (tables) {
          final rows = tables['notebooks'] as List;
          rows.add({...(rows.first as Map), 'notebookId': 'another'});
        },
        // 业务 id 重复。
        (tables) {
          final rows = tables['notebooks'] as List;
          rows.add({...(rows.first as Map), 'id': 99});
        },
        // 同一篇日记在同一本里出现两次。
        (tables) {
          final rows = tables['diaryNotebooks'] as List;
          rows.add({...(rows.single as Map), 'position': 9});
        },
      ]) {
        final copy = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
        mutate(copy['database'] as Map);
        expect(
          () => BackupPayload.decode(jsonEncode(copy)),
          throwsFormatException,
        );
      }
    });

    test('a notebook with an empty name rejects the backup', () {
      ((tables['notebooks'] as List).first as Map)['name'] = '  ';
      expect(
        () => BackupPayload.decode(jsonEncode(payload)),
        throwsFormatException,
      );
    });

    test('payload rebuilds keep notebooks and memberships', () {
      // 悬空的标签关联触发 _withRestorableRelations 重建载荷。
      (tables['diaryTags'] as List).add({'diaryId': 999, 'tagId': 999});
      final decoded = BackupPayload.decode(jsonEncode(payload));
      expect(decoded.notebooks, hasLength(2));
      expect(decoded.diaryNotebooks, hasLength(1));
    });
  });

  test('merging a backup from another device adds missing notebooks after '
      'the local shelf and maps memberships to the new local diary ids, '
      'with no rows for smart notebooks', () async {
    final source = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(source.close);
    await switchDocuments('source_documents');
    final cover = await media('diary_covers/trip.jpg', [1, 2]);
    final a = await diary(source, 'a');
    final b = await diary(source, 'b');
    final trip = await source.createNotebook(
      name: 'trip',
      payload: NotebookPayload(
        coverPath: cover.path,
        chapters: [NotebookChapter(id: 'c1', title: 'one')],
      ),
    );
    await source.addDiariesToNotebook(trip, [a], chapterId: 'c1');
    await source.addDiariesToNotebook(trip, [b]);
    final smart = await source.createNotebook(
      name: 'smart',
      kind: NotebookKind.smart,
    );
    final zip = await DataArchiveService.exportToZip(
      database: source,
      settingsService: fixture.settings,
    );

    await switchDocuments('target_documents');
    await fixture.seedCurrentData();
    // 先占掉文件里的本地 id，导入的日记必须换成新 id。
    await diary(db, 'local');
    final localShelf = await db.select(db.notebooks).get();
    final result = await importZip(zip, BackupImportMode.merge);

    expect(result.addedDiaries, 2);
    expect(result.addedNotebooks, 2);
    final added = {
      for (final row in await db.select(db.notebooks).get())
        if (row.notebookId == trip || row.notebookId == smart)
          row.notebookId: row,
    };
    final localMax = localShelf
        .map((row) => row.sortOrder)
        .reduce((x, y) => x > y ? x : y);
    expect(added[trip]!.sortOrder, localMax + 1);
    expect(added[smart]!.sortOrder, localMax + 2);
    final localA = (await db.getDiaryWithTagsByDiaryId(a))!.diary.id;
    final localB = (await db.getDiaryWithTagsByDiaryId(b))!.diary.id;
    expect(
      await (db.select(db.diaryNotebooks)
            ..where((t) => t.notebookId.equals(added[trip]!.id)))
          .map((row) => (row.diaryId, row.chapterId, row.position))
          .get(),
      unorderedEquals([(localA, 'c1', 0), (localB, null, 1)]),
    );
    expect(
      await (db.select(
        db.diaryNotebooks,
      )..where((t) => t.notebookId.equals(added[smart]!.id))).get(),
      isEmpty,
    );
    // 封面落进本次导入的批次目录，文件随之搬入。
    final rebound = coverOf(added[trip]!)!;
    expect(
      relative(rebound),
      matches(RegExp(r'^diary_covers/import_\d+/trip\.jpg$')),
    );
    expect(await File(rebound).readAsBytes(), [1, 2]);
  });

  test('merging appends into an existing notebook in file order and drops '
      'chapters the local notebook no longer has', () async {
    final p1 = await diary(db, 'p1');
    final e1 = await diary(db, 'e1');
    final e2 = await diary(db, 'e2');
    final shelf = await db.createNotebook(
      name: 'shelf',
      payload: NotebookPayload(
        chapters: [NotebookChapter(id: 'c1', title: 'one')],
      ),
    );
    await db.addDiariesToNotebook(shelf, [p1]);
    await db.addDiariesToNotebook(shelf, [e2, e1], chapterId: 'c1');
    final payload = await fixture.capturePayload();

    // 本机：两篇被彻底删除（导入时按新增处理），章节已删，又加了一篇。
    await db.hardDeleteDiary(e1);
    await db.hardDeleteDiary(e2);
    await db.updateNotebook(shelf, payload: NotebookPayload());
    final s = await diary(db, 's');
    await db.addDiariesToNotebook(shelf, [s]);

    final result = await importPayload(payload, BackupImportMode.merge);
    expect(result.addedDiaries, 2);
    expect(result.addedNotebooks, 0);
    expect((await memberships(db))[shelf], [
      (p1, null, 0),
      (s, null, 1),
      (e2, null, 2),
      (e1, null, 3),
    ]);
    expect((await db.getNotebook(shelf))!.parsedPayload.chapters, isEmpty);
  });

  test('plain merge keeps a local definition and overwrite replaces it but '
      'keeps the local shelf order', () async {
    final shared = await db.createNotebook(
      name: 'file name',
      payload: NotebookPayload(
        chapters: [NotebookChapter(id: 'c1', title: 'one')],
      ),
    );
    final payload = await fixture.capturePayload();
    final row = ((payload['database'] as Map)['notebooks'] as List).single;
    (row as Map)['sortOrder'] = 40;
    row['isPinned'] = true;
    row['visibility'] = NotebookVisibility.hidden.name;

    await db.createNotebook(name: 'first');
    await db.reorderNotebooks([
      (await db.getNotebooks()).last.notebookId,
      shared,
    ]);
    await db.updateNotebook(
      shared,
      name: 'local name',
      payload: NotebookPayload(description: 'local'),
    );
    final local = (await db.getNotebook(shared))!;

    final preview = await DataArchiveService.inspectZip(
      database: db,
      zipPath: (await fixture.writeZip(payload)).path,
    );
    expect(preview.existingNotebookCount, 1);
    expect(preview.localNotebookCount, 2);
    // 只有日记本重复时不提供“覆盖已存在”。
    expect(
      preview.availableModes,
      isNot(contains(BackupImportMode.mergeOverwrite)),
    );

    final merged = await importPayload(payload, BackupImportMode.merge);
    expect(merged.addedNotebooks, 0);
    expect(await db.getNotebook(shared), local);

    final overwritten = await importPayload(
      payload,
      BackupImportMode.mergeOverwrite,
    );
    expect(overwritten.addedNotebooks, 0);
    final replaced = (await db.getNotebook(shared))!;
    expect(replaced.id, local.id);
    expect(replaced.name, 'file name');
    expect(replaced.isPinned, isTrue);
    expect(replaced.notebookVisibility, NotebookVisibility.hidden);
    expect(replaced.parsedPayload.chapters.single.id, 'c1');
    expect(replaced.sortOrder, local.sortOrder);
  });

  test('a replaced diary follows the file in the notebooks the file carries '
      'and keeps device-only memberships', () async {
    final d = await diary(db, 'd');
    final other = await diary(db, 'other');
    final x = await db.createNotebook(name: 'x');
    final y = await db.createNotebook(
      name: 'y',
      payload: NotebookPayload(
        chapters: [NotebookChapter(id: 'c1', title: 'one')],
      ),
    );
    await db.addDiariesToNotebook(x, [other]);
    await db.addDiariesToNotebook(y, [other, d], chapterId: 'c1');
    final payload = await fixture.capturePayload();

    // 本机之后：d 也进了 x、进了本机新建的 l，在 y 里换到未分章。
    await db.addDiariesToNotebook(x, [d]);
    final l = await db.createNotebook(name: 'l');
    await db.addDiariesToNotebook(l, [d]);
    await db.setNotebookEntriesChapter(y, [d], null);
    final before = await memberships(db);

    final merged = await importPayload(payload, BackupImportMode.merge);
    expect(merged.skippedDiaries, 2);
    expect(await memberships(db), before);

    final overwritten = await importPayload(
      payload,
      BackupImportMode.mergeOverwrite,
    );
    expect(overwritten.replacedDiaries, 2);
    final after = await memberships(db);
    // x 在文件里、文件版本的 d 不在 x 里 → 移出；l 是本机独有 → 保留。
    expect(after[x], [(other, null, 0)]);
    expect(after[l], [(d, null, 0)]);
    // y 里保持本机的成书位置，章节跟文件。
    expect(after[y], [(other, 'c1', 0), (d, 'c1', 1)]);
  });

  test('a replaced notebook that the file says is smart loses its rows, '
      'and a file membership into a local smart notebook is skipped', () async {
    final d = await diary(db, 'd');
    final shared = await db.createNotebook(name: 'shared');
    await db.addDiariesToNotebook(shared, [d]);
    final payload = await fixture.capturePayload();
    final tables = payload['database'] as Map;
    ((tables['notebooks'] as List).single as Map)['kind'] = 'smart';
    expect(BackupPayload.decode(jsonEncode(payload)).diaryNotebooks, isEmpty);

    await importPayload(payload, BackupImportMode.mergeOverwrite);
    expect((await db.getNotebook(shared))!.notebookKind, NotebookKind.smart);
    expect(await db.select(db.diaryNotebooks).get(), isEmpty);
  });

  test('a diary package carries only the manual notebooks its diaries are '
      'in, with their covers, and re-imports into an empty database', () async {
    final source = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(source.close);
    await switchDocuments('source_documents');
    final cover = await media('diary_covers/n1.jpg', [5, 5]);
    final unrelatedCover = await media('diary_covers/n3.jpg', [6]);
    final a = await diary(source, 'a');
    final b = await diary(source, 'b');
    final n1 = await source.createNotebook(
      name: 'n1',
      visibility: NotebookVisibility.hidden,
      payload: NotebookPayload(
        coverPath: cover.path,
        chapters: [NotebookChapter(id: 'c1', title: 'one')],
      ),
    );
    final n2 = await source.createNotebook(name: 'n2');
    await source.createNotebook(
      name: 'n3',
      payload: NotebookPayload(coverPath: unrelatedCover.path),
    );
    await source.createNotebook(name: 'smart', kind: NotebookKind.smart);
    await source.addDiariesToNotebook(n1, [b, a], chapterId: 'c1');
    await source.addDiariesToNotebook(n2, [b]);
    final package = await DataArchiveService.exportDiariesToZip(
      database: source,
      diaryIds: [a],
    );

    final archive = ZipDecoder().decodeBytes(await package.readAsBytes());
    expect(
      archive.files.map((file) => file.name),
      containsAll([diaryPackagePayloadFileName, 'diary_covers/n1.jpg']),
    );
    expect(
      archive.files.map((file) => file.name),
      isNot(contains('diary_covers/n3.jpg')),
    );
    final json =
        jsonDecode(
              utf8.decode(
                archive.findFile(diaryPackagePayloadFileName)!.content
                    as List<int>,
              ),
            )
            as Map<String, dynamic>;
    archive.clearSync();
    final tables = json['database'] as Map;
    expect(
      (tables['notebooks'] as List).map((row) => (row as Map)['notebookId']),
      [n1],
    );
    expect(tables['diaryNotebooks'] as List, hasLength(1));

    await switchDocuments('target_documents');
    final result = await importZip(package, BackupImportMode.merge);
    expect(result.addedDiaries, 1);
    expect(result.addedNotebooks, 1);
    final imported = (await db.getNotebook(n1))!;
    expect(imported.notebookVisibility, NotebookVisibility.hidden);
    expect((await memberships(db))[n1], [(a, 'c1', 1)]);
    expect(await File(coverOf(imported)!).readAsBytes(), [5, 5]);
  });

  test('nesting survives a full backup and a merge, and a package whose '
      'parent stays behind lands at the top level', () async {
    final source = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(source.close);
    await switchDocuments('source_documents');
    final a = await diary(source, 'a');
    final travel = await source.createNotebook(name: 'travel');
    final japan = await source.createNotebook(name: 'japan', parentId: travel);
    await source.addDiariesToNotebook(japan, [a]);
    final zip = await DataArchiveService.exportToZip(
      database: source,
      settingsService: fixture.settings,
    );
    final package = await DataArchiveService.exportDiariesToZip(
      database: source,
      diaryIds: [a],
    );

    await switchDocuments('target_documents');
    await importZip(package, BackupImportMode.merge);
    // 包里只有 japan，上级 travel 不在本机：落到顶层。
    expect((await db.getNotebook(japan))!.parentId, isNull);

    await importZip(zip, BackupImportMode.mergeOverwrite);
    expect((await db.getNotebook(japan))!.parentId, travel);

    await importZip(zip, BackupImportMode.replaceAll);
    expect((await db.getNotebook(japan))!.parentId, travel);
    expect((await db.getNotebook(travel))!.parentId, isNull);
  });

  test('media sweep keeps notebook covers', () async {
    final cover = await media('diary_covers/notebook.jpg', [1]);
    final orphan = await media('diary_covers/orphan.jpg', [2]);
    // 另一安装目录下的绝对路径：回收按托管目录定位，不按整路径比较。
    await db.createNotebook(
      name: 'covered',
      payload: NotebookPayload(
        coverPath: '/old/container/Documents/diary_covers/notebook.jpg',
      ),
    );
    final service = DiaryMediaCleanupService(
      database: db,
      settings: () async => fixture.settings,
      documentsDirectory: () async => fixture.documents,
      temporaryDirectory: () async => fixture.temporary,
      clock: () => DateTime.now().add(const Duration(days: 2)),
    );
    addTearDown(service.dispose);
    final report = await service.sweep();
    expect(report?.deletedFiles, 1);
    expect(await cover.exists(), isTrue);
    expect(await orphan.exists(), isFalse);
  });

  for (final mode in [
    BackupImportMode.replaceAll,
    BackupImportMode.mergeOverwrite,
  ]) {
    test('a write failure on memberships rolls notebooks back '
        '(${mode.name})', () async {
      await fixture.seedCurrentData();
      final incoming = await fixture.capturePayload();
      final tables = incoming['database'] as Map;
      ((tables['notebooks'] as List).single as Map)['name'] = 'incoming';
      ((tables['diaries'] as List).single as Map)['title'] = 'incoming diary';
      await db.customStatement('''
CREATE TRIGGER reject_notebook_restore BEFORE INSERT ON diary_notebooks
BEGIN SELECT RAISE(ABORT, 'forced notebook failure'); END;
''');
      // 合并时换成一篇新日记，它的成员行要插入，触发器才会拦下；日记本定义
      // 的替换已经写入，必须随事务一起回滚。
      if (mode == BackupImportMode.mergeOverwrite) {
        ((tables['diaries'] as List).single as Map)['diaryId'] =
            AppDatabase.newBusinessId();
      }
      await expectLater(
        importPayload(incoming, mode),
        throwsA(
          predicate(
            (error) => error.toString().contains('forced notebook failure'),
          ),
        ),
      );
      await fixture.expectCurrentDataIntact();
    });
  }
}

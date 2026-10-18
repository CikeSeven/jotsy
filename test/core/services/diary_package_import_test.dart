import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/backup_constants.dart';
import 'package:node_diary/core/services/backup_import_models.dart';
import 'package:node_diary/core/services/data_archive_service.dart';
import 'package:path/path.dart' as p;

import '../../support/backup_test_fixture.dart';

/// 日记包导出与合并/覆盖导入：本机数据在合并时保持不变，覆盖只作用于所选
/// 范围，失败时数据库与新拷贝的媒体一起回滚。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 两个内存库分别模拟两台设备，各自独立的执行器，不存在 drift 警告的竞态。
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late BackupTestFixture fixture;
  setUp(() async => fixture = await BackupTestFixture.create());
  tearDown(() => fixture.dispose());

  /// 另一台设备：独立的数据库与 documents 目录。导出完成后把 fixture 切回
  /// [target] 目录，模拟在本机导入。
  Future<AppDatabase> otherInstallation() async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    fixture.documents = await Directory(
      p.join(fixture.root.path, 'source_documents'),
    ).create();
    return database;
  }

  Future<void> useTargetDocuments() async {
    fixture.documents = await Directory(
      p.join(fixture.root.path, 'target_documents'),
    ).create();
  }

  Future<String> seedTravelDiary(AppDatabase database) async {
    final image = await _writeMedia(
      fixture.documents,
      'diary_images/media_a/photo.jpg',
      [1, 2, 3],
    );
    final cover = await _writeMedia(
      fixture.documents,
      'diary_covers/cover_1.jpg',
      [4, 5, 6],
    );
    final travel = await database.createTag(name: '旅行', color: 0xFF2255FF);
    final spring = await database.createTag(name: '春天', color: 0xFF22AA55);
    return database.createDiary(
      title: '春日小记',
      contentDocJson: jsonEncode([
        {
          'insert': {'image': image},
        },
        {'insert': '看花\n'},
      ]),
      contentText: '看花',
      metadataJson: '{"mood":"😊"}',
      cover: cover,
      tagIds: [travel, spring],
    );
  }

  Future<void> expectLocalDataIntact(String localDiaryId) async {
    final local = await fixture.database.getDiaryWithTagsByDiaryId(
      localDiaryId,
    );
    expect(local?.diary.title, 'current diary');
    expect(local?.diary.metadata, '{"keep":"metadata"}');
    final draft = await fixture.database
        .select(fixture.database.diaryDrafts)
        .getSingle();
    expect(draft.payload, '{"title":"current draft"}');
    for (final entry in fixture.originalMedia.entries) {
      expect(await File(entry.key).readAsBytes(), entry.value);
    }
    expect(
      await fixture.documents
          .list()
          .where((entry) => p.basename(entry.path).startsWith('.backup_'))
          .toList(),
      isEmpty,
    );
  }

  test(
    'a diary exported elsewhere merges in with its tags and only its media',
    () async {
      final source = await otherInstallation();
      final diaryId = await seedTravelDiary(source);
      final unrelated = await _writeMedia(
        fixture.documents,
        'diary_images/media_b/other.jpg',
        [9],
      );
      await source.createDiary(
        title: 'other',
        contentDocJson: jsonEncode([
          {
            'insert': {'image': unrelated},
          },
          {'insert': '\n'},
        ]),
        contentText: '',
        metadataJson: '{}',
      );
      final package = await DataArchiveService.exportDiariesToZip(
        database: source,
        diaryIds: [diaryId],
      );

      final archive = ZipDecoder().decodeBytes(await package.readAsBytes());
      // 旧版应用只认 backup_data.json；日记包换名后旧版会直接拒绝，不会把
      // 它当完整备份清空本机。
      expect(archive.files.map((file) => file.name).toSet(), {
        diaryPackagePayloadFileName,
        'diary_images/media_a/photo.jpg',
        'diary_covers/cover_1.jpg',
      });
      final payload =
          jsonDecode(
                utf8.decode(
                  archive.findFile(diaryPackagePayloadFileName)!.content
                      as List<int>,
                ),
              )
              as Map<String, dynamic>;
      expect(payload.containsKey('settings'), isFalse);
      archive.clearSync();

      await useTargetDocuments();
      final localDiaryId = await fixture.seedCurrentData();
      final localTravel = await fixture.database.createTag(
        name: '旅行',
        color: 0xFFFF0000,
      );
      await fixture.settings.setThemeMode(ThemeMode.dark);

      final preview = await DataArchiveService.inspectZip(
        database: fixture.database,
        zipPath: package.path,
      );
      expect(preview.kind, BackupArchiveKind.diaryPackage);
      expect(preview.diaryCount, 1);
      expect(preview.tagCount, 2);
      expect(preview.existingDiaryCount, 0);
      expect(preview.localDiaryCount, 1);
      expect(preview.localTagCount, 1);
      expect(preview.soleDiaryTitle, '春日小记');
      expect(preview.availableModes, [BackupImportMode.merge]);

      final result = await DataArchiveService.importFromZip(
        database: fixture.database,
        settingsService: fixture.settings,
        zipPath: package.path,
        mode: BackupImportMode.merge,
      );
      expect(result.addedDiaries, 1);
      expect(result.replacedDiaries, 0);
      expect(result.skippedDiaries, 0);

      await expectLocalDataIntact(localDiaryId);
      expect(fixture.settings.themeModeNotifier.value, ThemeMode.dark);

      final imported = (await fixture.database.getDiaryWithTagsByDiaryId(
        diaryId,
      ))!;
      expect(imported.diary.title, '春日小记');
      expect(imported.diary.metadata, '{"mood":"😊"}');
      final tags = {for (final tag in imported.tags) tag.name: tag};
      expect(tags.keys.toSet(), {'旅行', '春天'});
      // 同名标签复用本机那一个，颜色保持本机设置。
      expect(tags['旅行']!.id, localTravel);
      expect(tags['旅行']!.color, 0xFFFF0000);
      expect(tags['春天']!.color, 0xFF22AA55);

      final image =
          (((jsonDecode(imported.diary.content) as List).first as Map)['insert']
                  as Map)['image']
              as String;
      expect(
        _relative(image),
        matches(RegExp(r'^diary_images/import_\d+/media_a/photo\.jpg$')),
      );
      expect(await File(image).readAsBytes(), [1, 2, 3]);
      expect(
        _relative(imported.diary.cover!),
        matches(RegExp(r'^diary_covers/import_\d+/cover_1\.jpg$')),
      );
      expect(await File(imported.diary.cover!).readAsBytes(), [4, 5, 6]);
    },
  );

  test(
    're-importing keeps the local version unless overwrite is chosen',
    () async {
      final diaryId = await seedTravelDiary(fixture.database);
      final original = (await fixture.database.getDiaryWithTagsByDiaryId(
        diaryId,
      ))!;
      final package = await DataArchiveService.exportDiariesToZip(
        database: fixture.database,
        diaryIds: [diaryId],
      );
      await fixture.database.updateDiary(
        diaryId: diaryId,
        title: '本机修改',
        contentDocJson: jsonEncode([
          {'insert': '改过了\n'},
        ]),
        contentText: '改过了',
        metadataJson: '{}',
      );

      final preview = await DataArchiveService.inspectZip(
        database: fixture.database,
        zipPath: package.path,
      );
      expect(preview.existingDiaryCount, 1);
      expect(preview.availableModes, [
        BackupImportMode.merge,
        BackupImportMode.mergeOverwrite,
      ]);

      final merged = await DataArchiveService.importFromZip(
        database: fixture.database,
        settingsService: fixture.settings,
        zipPath: package.path,
        mode: BackupImportMode.merge,
      );
      expect(merged.addedDiaries, 0);
      expect(merged.skippedDiaries, 1);
      var current = (await fixture.database.getDiaryWithTagsByDiaryId(
        diaryId,
      ))!;
      expect(current.diary.title, '本机修改');
      expect(current.tags, isEmpty);
      expect(await _importBatches(fixture.documents), isEmpty);

      final overwritten = await DataArchiveService.importFromZip(
        database: fixture.database,
        settingsService: fixture.settings,
        zipPath: package.path,
        mode: BackupImportMode.mergeOverwrite,
      );
      expect(overwritten.replacedDiaries, 1);
      expect(overwritten.addedDiaries, 0);
      current = (await fixture.database.getDiaryWithTagsByDiaryId(diaryId))!;
      expect(current.diary.title, '春日小记');
      expect(current.diary.id, original.diary.id);
      expect(current.diary.createdAt, original.diary.createdAt);
      expect(current.tags.map((tag) => tag.id).toSet(), {
        for (final tag in original.tags) tag.id,
      });
      expect(
        await fixture.database.select(fixture.database.diaries).get(),
        hasLength(1),
      );
      expect(
        await fixture.database.select(fixture.database.tags).get(),
        hasLength(2),
      );
      expect(await File(current.diary.cover!).readAsBytes(), [4, 5, 6]);
    },
  );

  test('diary packages can never replace all local data', () async {
    final localDiaryId = await fixture.seedCurrentData();
    final package = await DataArchiveService.exportDiariesToZip(
      database: fixture.database,
      diaryIds: [localDiaryId],
    );
    final extra = await fixture.database.createDiary(
      title: 'not in the package',
      contentDocJson: '[{"insert":"\\n"}]',
      contentText: '',
      metadataJson: '{}',
    );

    await expectLater(fixture.import(package), throwsA(isA<FormatException>()));
    await expectLocalDataIntact(localDiaryId);
    expect(await fixture.database.getDiaryWithTagsByDiaryId(extra), isNotNull);
  });

  test(
    'merging a full backup adds diaries without touching local settings',
    () async {
      final source = await otherInstallation();
      final diaryId = await seedTravelDiary(source);
      await fixture.settings.setThemeMode(ThemeMode.dark);
      final backup = await DataArchiveService.exportToZip(
        database: source,
        settingsService: fixture.settings,
      );

      await useTargetDocuments();
      final localDiaryId = await fixture.seedCurrentData();
      await fixture.settings.setThemeMode(ThemeMode.light);

      final preview = await DataArchiveService.inspectZip(
        database: fixture.database,
        zipPath: backup.path,
      );
      expect(preview.kind, BackupArchiveKind.fullBackup);
      expect(preview.availableModes, [
        BackupImportMode.merge,
        BackupImportMode.replaceAll,
      ]);
      expect(preview.soleDiaryTitle, '春日小记');

      final result = await DataArchiveService.importFromZip(
        database: fixture.database,
        settingsService: fixture.settings,
        zipPath: backup.path,
        mode: BackupImportMode.merge,
      );
      expect(result.addedDiaries, 1);
      await expectLocalDataIntact(localDiaryId);
      expect(fixture.settings.themeModeNotifier.value, ThemeMode.light);
      final imported = (await fixture.database.getDiaryWithTagsByDiaryId(
        diaryId,
      ))!;
      expect(imported.tags.map((tag) => tag.name).toSet(), {'旅行', '春天'});
      expect(await File(imported.diary.cover!).readAsBytes(), [4, 5, 6]);
    },
  );

  test('a failed merge rolls back rows and removes copied media', () async {
    final source = await otherInstallation();
    final diaryId = await seedTravelDiary(source);
    final package = await DataArchiveService.exportDiariesToZip(
      database: source,
      diaryIds: [diaryId],
    );

    await useTargetDocuments();
    final localDiaryId = await fixture.seedCurrentData();
    await fixture.database.customStatement('''
CREATE TRIGGER reject_diary_tags BEFORE INSERT ON diary_tags
BEGIN SELECT RAISE(ABORT, 'forced merge failure'); END;
''');

    await expectLater(
      DataArchiveService.importFromZip(
        database: fixture.database,
        settingsService: fixture.settings,
        zipPath: package.path,
        mode: BackupImportMode.merge,
      ),
      throwsA(
        predicate((error) => error.toString().contains('forced merge failure')),
      ),
    );
    await expectLocalDataIntact(localDiaryId);
    expect(await fixture.database.getDiaryWithTagsByDiaryId(diaryId), isNull);
    expect(await fixture.database.select(fixture.database.tags).get(), isEmpty);
    expect(await _importBatches(fixture.documents), isEmpty);

    await fixture.database.customStatement('DROP TRIGGER reject_diary_tags');
    final retried = await DataArchiveService.importFromZip(
      database: fixture.database,
      settingsService: fixture.settings,
      zipPath: package.path,
      mode: BackupImportMode.merge,
    );
    expect(retried.addedDiaries, 1);
    expect(await _importBatches(fixture.documents), hasLength(2));
  });

  test('encrypted diary packages need the password before preview', () async {
    final diaryId = await seedTravelDiary(fixture.database);
    final package = await DataArchiveService.exportDiariesToZip(
      database: fixture.database,
      diaryIds: [diaryId],
      zipPassword: 'secret',
    );
    expect(
      await DataArchiveService.isZipPasswordProtected(zipPath: package.path),
      isTrue,
    );
    await expectLater(
      DataArchiveService.inspectZip(
        database: fixture.database,
        zipPath: package.path,
        zipPassword: 'wrong',
      ),
      throwsA(anything),
    );
    final preview = await DataArchiveService.inspectZip(
      database: fixture.database,
      zipPath: package.path,
      zipPassword: 'secret',
    );
    expect(preview.existingDiaryCount, 1);
  });

  test('exporting diaries that no longer exist fails', () async {
    await expectLater(
      DataArchiveService.exportDiariesToZip(
        database: fixture.database,
        diaryIds: ['missing'],
      ),
      throwsA(isA<StateError>()),
    );
  });
}

Future<String> _writeMedia(
  Directory documents,
  String key,
  List<int> bytes,
) async {
  final file = File(p.joinAll([documents.path, ...key.split('/')]));
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
  return file.path;
}

/// documents 下的相对路径（统一为 `/` 分隔）。
String _relative(String path) {
  final segments = p.split(path);
  final index = segments.lastIndexWhere(backupMediaDirectories.contains);
  return segments.skip(index).join('/');
}

/// 各托管目录下由合并导入创建的批次目录。
Future<List<String>> _importBatches(Directory documents) async {
  final batches = <String>[];
  for (final name in backupMediaDirectories) {
    final directory = Directory(p.join(documents.path, name));
    if (!await directory.exists()) continue;
    await for (final entity in directory.list()) {
      if (p.basename(entity.path).startsWith('import_')) {
        batches.add(p.relative(entity.path, from: documents.path));
      }
    }
  }
  return batches;
}

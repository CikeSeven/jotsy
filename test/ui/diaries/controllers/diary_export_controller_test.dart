import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/backup_constants.dart';
import 'package:node_diary/ui/diaries/controllers/diary_export_controller.dart';
import 'package:node_diary/ui/diaries/export/diary_export_format.dart';
import 'package:path/path.dart' as p;

import '../../../support/backup_test_fixture.dart';
import '../export/diary_export_test_fixtures.dart';

/// 导出控制器：格式分发、胶囊过滤、排序、打包与暂存清理。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupTestFixture fixture;
  late String seededId;
  final now = DateTime(2026, 10, 16, 12);

  setUp(() async {
    fixture = await BackupTestFixture.create();
    seededId = await fixture.seedCurrentData();
  });
  tearDown(() => fixture.dispose());

  Future<DiaryWithTags> diary(
    String title, {
    required DateTime createdAt,
    DateTime? capsuleUnlockAt,
    String content = '[{"insert":"正文\\n"}]',
  }) async {
    final id = await fixture.database.createDiary(
      title: title,
      contentDocJson: content,
      contentText: '正文',
      metadataJson: '{}',
      createdAtOverride: createdAt,
      capsuleLockedAt: capsuleUnlockAt == null ? null : createdAt,
      capsuleUnlockAt: capsuleUnlockAt,
    );
    return (await fixture.database.getDiaryWithTagsByDiaryId(id))!;
  }

  DiaryExportController controller({
    List<File>? shared,
    Future<String?> Function(File file, String fileName)? save,
  }) {
    return DiaryExportController(
      database: fixture.database,
      now: () => now,
      saveFile:
          ({
            required File file,
            required String fileName,
            required String dialogTitle,
            required String mimeType,
            required String extension,
          }) async => save == null ? null : await save(file, fileName),
      shareFile: (File file, {required String mimeType}) async =>
          shared?.add(file),
    );
  }

  Future<List<FileSystemEntity>> staged() async {
    final root = Directory(
      p.join(
        fixture.temporary.path,
        DiaryExportController.stagingDirectoryName,
      ),
    );
    return await root.exists()
        ? root.list(recursive: true).where((e) => e is File).toList()
        : <FileSystemEntity>[];
  }

  test(
    'sorts by date, skips sealed capsules and names the file by range',
    () async {
      final later = await diary('后来', createdAt: DateTime(2026, 5, 2));
      final earlier = await diary('先前', createdAt: DateTime(2026, 5, 1));
      final sealed = await diary(
        '胶囊',
        createdAt: DateTime(2026, 5, 3),
        capsuleUnlockAt: DateTime(2027, 1, 1),
      );

      final artifact = await controller().build(
        <DiaryWithTags>[later, sealed, earlier],
        options: const DiaryExportOptions(format: DiaryExportFormat.text),
        labels: testExportLabels,
        languageTag: 'zh',
      );

      expect(artifact.exportedCount, 2);
      expect(artifact.skippedCapsules, 1);
      expect(artifact.fileName, 'Jotsy 2026-05-01~2026-05-02.txt');
      final text = await artifact.file.readAsString();
      expect(text.indexOf('先前'), lessThan(text.indexOf('后来')));
      expect(text, isNot(contains('胶囊')));
    },
  );

  test('newest-first order reverses the diaries', () async {
    final a = await diary('一', createdAt: DateTime(2026, 5, 1));
    final b = await diary('二', createdAt: DateTime(2026, 5, 2));
    final artifact = await controller().build(
      <DiaryWithTags>[a, b],
      options: const DiaryExportOptions(
        format: DiaryExportFormat.csv,
        order: DiaryExportOrder.newestFirst,
      ),
      labels: testExportLabels,
      languageTag: 'zh',
    );
    final rows = (await artifact.file.readAsString()).split('\r\n');
    expect(rows[1], contains(',二,'));
    expect(rows[2], contains(',一,'));
  });

  test('only sealed capsules selected → nothing to export', () async {
    final sealed = await diary(
      '胶囊',
      createdAt: DateTime(2026, 5, 3),
      capsuleUnlockAt: DateTime(2027, 1, 1),
    );
    await expectLater(
      controller().build(
        <DiaryWithTags>[sealed],
        options: DiaryExportOptions.defaults,
        labels: testExportLabels,
        languageTag: 'zh',
      ),
      throwsA(
        isA<DiaryExportEmptyException>().having(
          (e) => e.skippedCapsules,
          'skippedCapsules',
          1,
        ),
      ),
    );
  });

  test('Markdown with media is zipped with the files under media/', () async {
    final seeded = (await fixture.database.getDiaryWithTagsByDiaryId(
      seededId,
    ))!;
    final artifact = await controller().build(
      <DiaryWithTags>[seeded],
      options: const DiaryExportOptions(format: DiaryExportFormat.markdown),
      labels: testExportLabels,
      languageTag: 'zh',
    );

    expect(artifact.extension, 'zip');
    expect(artifact.mimeType, 'application/zip');
    final archive = ZipDecoder().decodeBytes(await artifact.file.readAsBytes());
    final names = archive.files.map((ArchiveFile f) => f.name).toList();
    expect(names.where((n) => n.endsWith('.md')), hasLength(1));
    expect(names, contains('media/0001_keep.bin'));
    expect(names, contains('media/0002_keep.bin'));
    final markdown = utf8.decode(
      archive.files
              .firstWhere((ArchiveFile f) => f.name.endsWith('.md'))
              .content
          as List<int>,
    );
    expect(markdown, contains('](media/0001_keep.bin)'));
    expect(markdown, isNot(contains(fixture.documents.path)));
  });

  test(
    'a saved diary file holds the diary package and the stage is cleared',
    () async {
      final seeded = (await fixture.database.getDiaryWithTagsByDiaryId(
        seededId,
      ))!;
      final saved = File(p.join(fixture.root.path, 'saved.zip'));
      String? requestedName;
      final export = controller(
        save: (File file, String fileName) async {
          requestedName = fileName;
          await file.copy(saved.path);
          return saved.path;
        },
      );
      final artifact = await export.build(
        <DiaryWithTags>[seeded],
        options: const DiaryExportOptions(format: DiaryExportFormat.diaryFile),
        labels: testExportLabels,
        languageTag: 'zh',
      );

      expect(await export.save(artifact, dialogTitle: 'save'), isTrue);
      expect(requestedName, endsWith('current diary.zip'));
      final archive = ZipDecoder().decodeBytes(await saved.readAsBytes());
      expect(archive.findFile(diaryPackagePayloadFileName), isNotNull);
      expect(archive.findFile(backupPayloadFileName), isNull);
      expect(archive.findFile('diary_videos/keep.bin'), isNotNull);
      expect(await staged(), isEmpty);
      // 日记文件生成时的中间 zip 也已移走，缓存根目录不留残余。
      expect(
        fixture.temporary.listSync().whereType<File>().where(
          (File f) => f.path.endsWith('.zip'),
        ),
        isEmpty,
      );
    },
  );

  test('cancelled or failed saves still clear the stage', () async {
    final a = await diary('一', createdAt: DateTime(2026, 5, 1));
    final options = const DiaryExportOptions(format: DiaryExportFormat.html);

    final cancel = controller();
    final first = await cancel.build(
      <DiaryWithTags>[a],
      options: options,
      labels: testExportLabels,
      languageTag: 'zh',
    );
    expect(await cancel.save(first, dialogTitle: 'save'), isFalse);
    expect(await staged(), isEmpty);

    final failing = controller(
      save: (File file, String name) async =>
          throw PlatformException(code: 'copy_failed'),
    );
    final second = await failing.build(
      <DiaryWithTags>[a],
      options: options,
      labels: testExportLabels,
      languageTag: 'zh',
    );
    await expectLater(
      failing.save(second, dialogTitle: 'save'),
      throwsA(isA<PlatformException>()),
    );
    expect(await staged(), isEmpty);
  });

  test('shared files stay until the next export replaces the stage', () async {
    final a = await diary('一', createdAt: DateTime(2026, 5, 1));
    final shared = <File>[];
    final export = controller(shared: shared);
    final first = await export.build(
      <DiaryWithTags>[a],
      options: const DiaryExportOptions(format: DiaryExportFormat.word),
      labels: testExportLabels,
      languageTag: 'zh',
    );
    // Word 由包内文件流式打包而成，扩展名与类型仍是 docx。
    expect(first.fileName, endsWith('一.docx'));
    expect(first.mimeType, DiaryExportFormat.word.mimeType);
    await export.share(first);
    expect(shared.single.existsSync(), isTrue);

    await export.build(
      <DiaryWithTags>[a],
      options: const DiaryExportOptions(format: DiaryExportFormat.text),
      labels: testExportLabels,
      languageTag: 'zh',
    );
    expect(shared.single.existsSync(), isFalse);
    expect(await staged(), hasLength(1));
  });
}

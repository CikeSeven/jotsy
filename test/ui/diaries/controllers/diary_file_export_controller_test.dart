import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/backup_constants.dart';
import 'package:node_diary/ui/diaries/controllers/diary_file_export_controller.dart';
import 'package:path/path.dart' as p;

import '../../../support/backup_test_fixture.dart';

/// 导出日记文件：保存成功、取消与失败都不能把临时 ZIP 留在缓存里。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupTestFixture fixture;
  late String diaryId;
  setUp(() async {
    fixture = await BackupTestFixture.create();
    diaryId = await fixture.seedCurrentData();
  });
  tearDown(() => fixture.dispose());

  Future<List<FileSystemEntity>> leftovers() =>
      fixture.temporary.list().toList();

  test('a saved diary file contains the diary package', () async {
    final saved = File(p.join(fixture.root.path, 'saved.zip'));
    String? requestedName;
    final result = await DiaryFileExportController.export(
      database: fixture.database,
      diaryId: diaryId,
      fileName: 'jotsy_current_1.zip',
      dialogTitle: 'save',
      saveFile:
          ({
            required File zipFile,
            required String fileName,
            required String dialogTitle,
          }) async {
            requestedName = fileName;
            await zipFile.copy(saved.path);
            return saved.path;
          },
    );

    expect(result, isTrue);
    expect(requestedName, 'jotsy_current_1.zip');
    final archive = ZipDecoder().decodeBytes(await saved.readAsBytes());
    expect(archive.findFile(diaryPackagePayloadFileName), isNotNull);
    expect(archive.findFile(backupPayloadFileName), isNull);
    // seedCurrentData 的正文引用了视频与附件，二者随日记一起打包。
    expect(archive.findFile('diary_videos/keep.bin'), isNotNull);
    expect(archive.findFile('diary_attachments/keep.bin'), isNotNull);
    expect(archive.findFile('diary_images/keep.bin'), isNull);
    archive.clearSync();
    expect(await leftovers(), isEmpty);
  });

  test('cancelling the save reports false and cleans up', () async {
    final result = await DiaryFileExportController.export(
      database: fixture.database,
      diaryId: diaryId,
      fileName: 'x.zip',
      dialogTitle: 'save',
      saveFile:
          ({
            required File zipFile,
            required String fileName,
            required String dialogTitle,
          }) async => null,
    );
    expect(result, isFalse);
    expect(await leftovers(), isEmpty);
  });

  test('save failures reach the caller and still clean up', () async {
    await expectLater(
      DiaryFileExportController.export(
        database: fixture.database,
        diaryId: diaryId,
        fileName: 'x.zip',
        dialogTitle: 'save',
        saveFile:
            ({
              required File zipFile,
              required String fileName,
              required String dialogTitle,
            }) async => throw PlatformException(code: 'copy_failed'),
      ),
      throwsA(isA<PlatformException>()),
    );
    expect(await leftovers(), isEmpty);
  });
}

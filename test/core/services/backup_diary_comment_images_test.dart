import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/backup_import_models.dart';
import 'package:node_diary/core/services/data_archive_service.dart';
import 'package:path/path.dart' as p;

import '../../support/backup_test_fixture.dart';

/// 留言图片随完整备份、合并导入与日记包走：文件打包、换了安装目录后路径
/// 重绑到本机，合并时只搬实际写入的留言的图片。
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

  Future<String> managedImage(String batch, String name, String body) async {
    final file = File(
      p.join(fixture.documents.path, 'diary_images', batch, name),
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(body);
    return file.path;
  }

  Future<DiaryCommentRow> single(String commentId) => (db().select(
    db().diaryComments,
  )..where((t) => t.commentId.equals(commentId))).getSingle();

  Future<BackupImportResult> importZip(File zip, BackupImportMode mode) =>
      DataArchiveService.importFromZip(
        database: db(),
        settingsService: fixture.settings,
        zipPath: zip.path,
        mode: mode,
      );

  test('a full backup carries comment images and restores them', () async {
    final image = await managedImage('media_a', 'sea.jpg', 'sea');
    final commentId = await db().addDiaryComment(
      diaryId: diaryId,
      content: '',
      images: <String>[image],
    );
    final payload = await fixture.capturePayload();
    await db().deleteDiaryComment(commentId);
    await File(image).delete();

    final zip = await fixture.writeZip(
      payload,
      files: <String, List<int>>{
        'diary_images/media_a/sea.jpg': 'sea'.codeUnits,
      },
    );
    await importZip(zip, BackupImportMode.replaceAll);

    final restored = await single(commentId);
    expect(restored.hasText, isFalse);
    final path = restored.imagePaths.single;
    expect(p.isWithin(fixture.documents.path, path), isTrue);
    expect(await File(path).readAsString(), 'sea');
  });

  test('merging rebinds images from another installation', () async {
    final payload = await fixture.capturePayload();
    (payload['database'] as Map)['diaryComments'] = <Object?>[
      <String, Object?>{
        'id': 7,
        'commentId': 'c-photo',
        'diaryId': diaryId,
        'content': '另一台手机上写的',
        'createdAt': 0,
        'images': encodeDiaryCommentImages(<String>[
          '/data/other/app_flutter/diary_images/media_q/hill.jpg',
          'https://example.com/remote.jpg',
        ]),
      },
    ];
    final zip = await fixture.writeZip(
      payload,
      files: <String, List<int>>{
        'diary_images/media_q/hill.jpg': 'hill'.codeUnits,
      },
    );
    final result = await importZip(zip, BackupImportMode.merge);

    expect(result.addedComments, 1);
    final images = (await single('c-photo')).imagePaths;
    expect(images, hasLength(2));
    // 合并导入落进新的批次子目录，文件随之搬过来；不是本机托管文件的地址
    // 原样保留。
    expect(p.isWithin(fixture.documents.path, images.first), isTrue);
    expect(images.first, contains('${p.separator}media_q${p.separator}'));
    expect(await File(images.first).readAsString(), 'hill');
    expect(images.last, 'https://example.com/remote.jpg');
  });

  test('merge keeps the local comment and does not move its images', () async {
    final local = await managedImage('media_l', 'local.jpg', 'local');
    final commentId = await db().addDiaryComment(
      diaryId: diaryId,
      content: '本机',
      images: <String>[local],
    );
    final payload = await fixture.capturePayload();
    final rows = ((payload['database'] as Map)['diaryComments'] as List)
        .cast<Map<String, Object?>>();
    rows.single['images'] = encodeDiaryCommentImages(<String>[
      '/elsewhere/diary_images/media_f/file.jpg',
    ]);
    final zip = await fixture.writeZip(
      payload,
      files: <String, List<int>>{
        'diary_images/media_f/file.jpg': 'file'.codeUnits,
      },
    );
    await importZip(zip, BackupImportMode.merge);

    expect((await single(commentId)).imagePaths, <String>[local]);
    final moved =
        await Directory(p.join(fixture.documents.path, 'diary_images'))
            .list(recursive: true)
            .where((entity) => p.basename(entity.path) == 'file.jpg')
            .toList();
    expect(moved, isEmpty);
  });

  test('a photo-only comment passes validation', () async {
    final payload = await fixture.capturePayload();
    (payload['database'] as Map)['diaryComments'] = <Object?>[
      <String, Object?>{
        'id': 1,
        'commentId': 'c-only-photo',
        'diaryId': diaryId,
        'content': '',
        'createdAt': 0,
        'images': encodeDiaryCommentImages(<String>['/x/diary_images/m/a.jpg']),
      },
    ];
    final zip = await fixture.writeZip(payload);
    final result = await importZip(zip, BackupImportMode.replaceAll);
    expect(result.addedComments, 1);
  });

  test('a diary package carries the images of its comments', () async {
    final image = await managedImage('media_p', 'pack.jpg', 'pack');
    final commentId = await db().addDiaryComment(
      diaryId: diaryId,
      content: '带图',
      images: <String>[image],
    );
    final zip = await DataArchiveService.exportDiariesToZip(
      database: db(),
      diaryIds: <String>[diaryId],
    );
    await db().deleteDiaryComment(commentId);
    await File(image).delete();

    await importZip(zip, BackupImportMode.merge);
    final path = (await single(commentId)).imagePaths.single;
    expect(await File(path).readAsString(), 'pack');
  });
}

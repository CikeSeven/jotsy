import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/backup_import_models.dart';
import 'package:node_diary/core/services/data_archive_service.dart';
import 'package:path/path.dart' as p;

import '../../support/backup_test_fixture.dart';

/// AI 对话里用户附带的图片随完整备份走：文件打包、换了安装目录后路径重绑
/// 到本机、墓碑（被存储管理删掉的位置）原样保留；合并时只搬实际写入的
/// 对话的图片。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupTestFixture fixture;
  setUp(() async {
    fixture = await BackupTestFixture.create();
    await fixture.seedCurrentData();
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

  Future<AiMessageRow> message(String messageId) => (db().select(
    db().aiMessages,
  )..where((t) => t.messageId.equals(messageId))).getSingle();

  Future<BackupImportResult> importZip(File zip, BackupImportMode mode) =>
      DataArchiveService.importFromZip(
        database: db(),
        settingsService: fixture.settings,
        zipPath: zip.path,
        mode: mode,
      );

  test('a full backup restores chat images and keeps removed slots', () async {
    final image = await managedImage('media_a', 'sea.jpg', 'sea');
    final conversation = await db().createAiConversation(title: '海边');
    final messageId = await db().addAiMessage(
      conversationId: conversation,
      role: AiMessageRole.user,
      content: '',
      imagesJson: encodeAiMessageImages([kAiMessageImageRemoved, image]),
    );
    final payload = await fixture.capturePayload();
    await db().deleteAiConversation(conversation);
    await File(image).delete();

    final zip = await fixture.writeZip(
      payload,
      files: <String, List<int>>{
        'diary_images/media_a/sea.jpg': 'sea'.codeUnits,
      },
    );
    await importZip(zip, BackupImportMode.replaceAll);

    final images = decodeAiMessageImages((await message(messageId)).images);
    expect(images, hasLength(2));
    // 墓碑留在原位，第二张（P2）仍是第二张。
    expect(images.first, kAiMessageImageRemoved);
    expect(p.isWithin(fixture.documents.path, images.last), isTrue);
    expect(await File(images.last).readAsString(), 'sea');
  });

  test('merging rebinds chat images from another installation', () async {
    final conversation = await db().createAiConversation(title: '别处');
    final messageId = await db().addAiMessage(
      conversationId: conversation,
      role: AiMessageRole.user,
      content: '看图',
      imagesJson: encodeAiMessageImages([
        '/data/other/app_flutter/diary_images/media_q/hill.jpg',
      ]),
    );
    final payload = await fixture.capturePayload();
    // 本机没有这段对话：合并时整段新增，文件搬进本机。
    await db().deleteAiConversation(conversation);
    final zip = await fixture.writeZip(
      payload,
      files: <String, List<int>>{
        'diary_images/media_q/hill.jpg': 'hill'.codeUnits,
      },
    );
    await importZip(zip, BackupImportMode.merge);

    final images = decodeAiMessageImages((await message(messageId)).images);
    expect(p.isWithin(fixture.documents.path, images.single), isTrue);
    expect(images.single, contains('${p.separator}media_q${p.separator}'));
    expect(await File(images.single).readAsString(), 'hill');
  });

  test('merge keeps the local chat and does not move its images', () async {
    final local = await managedImage('media_l', 'local.jpg', 'local');
    final conversation = await db().createAiConversation(title: '本机');
    final messageId = await db().addAiMessage(
      conversationId: conversation,
      role: AiMessageRole.user,
      content: '本机',
      imagesJson: encodeAiMessageImages([local]),
    );
    final payload = await fixture.capturePayload();
    final rows = ((payload['database'] as Map)['aiMessages'] as List)
        .cast<Map<String, Object?>>();
    rows.single['images'] = encodeAiMessageImages([
      '/elsewhere/diary_images/media_f/file.jpg',
    ]);
    final zip = await fixture.writeZip(
      payload,
      files: <String, List<int>>{
        'diary_images/media_f/file.jpg': 'file'.codeUnits,
      },
    );
    await importZip(zip, BackupImportMode.merge);

    expect(decodeAiMessageImages((await message(messageId)).images), [local]);
    final moved =
        await Directory(p.join(fixture.documents.path, 'diary_images'))
            .list(recursive: true)
            .where((entity) => p.basename(entity.path) == 'file.jpg')
            .toList();
    expect(moved, isEmpty);
  });
}

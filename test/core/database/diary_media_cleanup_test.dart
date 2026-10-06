import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;
  late AppDatabase database;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('jotsy_media_cleanup_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => root.path);
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await root.delete(recursive: true);
  });

  test(
    'soft deletion retains files and permanent deletion cleans only managed assets',
    () async {
      final video = await DiaryMediaStorageService.importFile(
        kind: DiaryMediaKind.video,
        fileName: 'delete.mp4',
        bytes: [1],
      );
      final attachment = await DiaryMediaStorageService.importFile(
        kind: DiaryMediaKind.attachment,
        fileName: 'delete.pdf',
        bytes: [2],
      );
      final external = File(p.join(root.path, 'external.pdf'));
      await external.writeAsBytes([3]);
      final diaryId = await database.createDiary(
        title: '',
        contentText: '',
        metadataJson: '{}',
        contentDocJson: jsonEncode([
          {
            'insert': {'video': video.path},
          },
          {'insert': '\n'},
          {
            'insert': {diaryAttachmentEmbedType: attachment.encode()},
          },
          {'insert': '\n'},
          {
            'insert': {'file': external.path},
          },
          {'insert': '\n'},
        ]),
      );
      await database.softDeleteDiary(diaryId);
      expect(await File(video.path).exists(), isTrue);
      expect(await File(attachment.path).exists(), isTrue);
      await database.hardDeleteDiary(diaryId);
      expect(await File(video.path).exists(), isFalse);
      expect(await File(attachment.path).exists(), isFalse);
      expect(await external.exists(), isTrue);
      expect(await database.select(database.diaries).get(), isEmpty);
    },
  );
}

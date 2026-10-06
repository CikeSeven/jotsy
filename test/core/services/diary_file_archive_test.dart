import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/services/data_archive_service.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;
  late Directory documents;
  late Directory temporary;
  late AppDatabase database;
  late SettingsService settings;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('jotsy_file_archive_test_');
    documents = await Directory(p.join(root.path, 'documents')).create();
    temporary = await Directory(p.join(root.path, 'temporary')).create();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => switch (call.method) {
            'getApplicationDocumentsDirectory' => documents.path,
            'getTemporaryDirectory' => temporary.path,
            _ => null,
          },
        );
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
  });

  tearDown(() async {
    await database.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await root.delete(recursive: true);
  });

  test(
    'encrypted backups restore attachments and wrong passwords retain current data',
    () async {
      final file = await DiaryMediaStorageService.importFile(
        kind: DiaryMediaKind.attachment,
        fileName: 'encrypted.pdf',
        bytes: [1, 2, 3, 4],
      );
      final content = jsonEncode([
        {
          'insert': {diaryAttachmentEmbedType: file.encode()},
        },
        {'insert': '\n'},
      ]);
      await database.createDiary(
        title: 'keep me',
        contentDocJson: content,
        contentText: '',
        metadataJson: '{}',
      );
      final zip = await DataArchiveService.exportToZip(
        database: database,
        settingsService: settings,
        zipPassword: 'test-password',
      );
      expect(
        await DataArchiveService.isZipPasswordProtected(zipPath: zip.path),
        isTrue,
      );
      await expectLater(
        DataArchiveService.importFromZip(
          database: database,
          settingsService: settings,
          zipPath: zip.path,
          zipPassword: 'wrong-password',
        ),
        throwsA(anything),
      );
      expect(
        (await database.select(database.diaries).getSingle()).title,
        'keep me',
      );
      expect(await File(file.path).readAsBytes(), [1, 2, 3, 4]);
      final relativePath = p.relative(file.path, from: documents.path);
      documents = await Directory(
        p.join(root.path, 'encrypted_import_documents'),
      ).create();
      await DataArchiveService.importFromZip(
        database: database,
        settingsService: settings,
        zipPath: zip.path,
        zipPassword: 'test-password',
      );
      final restoredPath = p.join(documents.path, relativePath);
      final diary = await database.select(database.diaries).getSingle();
      expect(extractDiaryFilePaths(diary.content), {restoredPath});
      expect(await File(restoredPath).readAsBytes(), [1, 2, 3, 4]);
    },
  );

  test(
    'backup restores video and attachment bytes, metadata, aliases and drafts',
    () async {
      final video = await DiaryMediaStorageService.importFile(
        kind: DiaryMediaKind.video,
        fileName: '旅行.mp4',
        bytes: [1, 2, 3],
      );
      final file = await DiaryMediaStorageService.importFile(
        kind: DiaryMediaKind.attachment,
        fileName: '会议 报告.pdf',
        bytes: [4, 5, 6, 7],
      );
      final relativeVideo = p.relative(video.path, from: documents.path);
      final relativeFile = p.relative(file.path, from: documents.path);
      final remote =
          'https://example.invalid/${relativeFile.replaceAll('\\', '/')}';
      final missing = p.join(documents.path, 'diary_videos', 'missing.mp4');
      final content = jsonEncode([
        {
          'insert': {'video': video.path},
        },
        {'insert': '\n'},
        {
          'insert': {diaryAttachmentEmbedType: file.encode()},
        },
        {'insert': '\n'},
        {
          'insert': {
            'file': {
              'url': file.path,
              'name': file.name,
              'size': file.sizeBytes,
              'custom': 'preserve this metadata',
            },
          },
        },
        {'insert': '\n'},
        {
          'insert': {'file': File(file.path).uri.toString()},
        },
        {'insert': '\n'},
        {
          'insert': {'video': remote},
        },
        {'insert': '\n'},
        {
          'insert': {'video': missing},
        },
        {'insert': '\n'},
      ]);
      await database.createDiary(
        title: '',
        contentDocJson: content,
        contentText: '',
        metadataJson: '{}',
      );
      await settings.setCreateDiaryDraftRaw(
        jsonEncode({'title': '', 'contentDocJson': content, 'contentText': ''}),
      );
      final zip = await DataArchiveService.exportToZip(
        database: database,
        settingsService: settings,
      );
      await documents.delete(recursive: true);
      documents = await Directory(
        p.join(root.path, 'new_phone_documents'),
      ).create();
      await DataArchiveService.importFromZip(
        database: database,
        settingsService: settings,
        zipPath: zip.path,
      );
      final restoredVideo = p.join(documents.path, relativeVideo);
      final restoredFile = p.join(documents.path, relativeFile);
      expect(await File(restoredVideo).readAsBytes(), [1, 2, 3]);
      expect(await File(restoredFile).readAsBytes(), [4, 5, 6, 7]);
      final diary = await database.select(database.diaries).getSingle();
      expect(extractDiaryFilePaths(diary.content), {
        restoredVideo,
        restoredFile,
        remote,
        missing,
      });
      final inserts = (jsonDecode(diary.content) as List)
          .where((op) => op['insert'] is Map)
          .map((op) => op['insert'] as Map)
          .toList();
      final restored = DiaryFileAttachment.tryDecode(
        inserts[1][diaryAttachmentEmbedType],
      );
      expect(restored?.displayName, '会议 报告.pdf');
      expect(restored?.sizeBytes, 4);
      expect(inserts[2]['file'], {
        'url': restoredFile,
        'name': file.name,
        'size': 4,
        'custom': 'preserve this metadata',
      });
      expect(inserts[3]['file'], restoredFile);
      final draft = jsonDecode(settings.createDiaryDraftRaw!) as Map;
      expect(
        extractDiaryFilePaths(draft['contentDocJson'] as String),
        extractDiaryFilePaths(diary.content),
      );
      expect(
        diaryDocumentHasVisibleContent(
          decodeDiaryContentToDocument(diary.content),
        ),
        isTrue,
      );
    },
  );

  test(
    'legacy backups restore video and file nodes as usable diary embeds',
    () async {
      final video = await DiaryMediaStorageService.importFile(
        kind: DiaryMediaKind.video,
        fileName: 'legacy.mp4',
        bytes: [1],
      );
      final file = await DiaryMediaStorageService.importFile(
        kind: DiaryMediaKind.attachment,
        fileName: '旧文件.pdf',
        bytes: [2, 3],
      );
      final relativeVideo = p.relative(video.path, from: documents.path);
      final relativeFile = p.relative(file.path, from: documents.path);
      final content = jsonEncode({
        'root': {
          'children': [
            {
              'type': 'video',
              'attributes': {'url': video.path, 'width': 320},
            },
            {
              'type': 'file',
              'attributes': {'url': file.path, 'name': '旧文件.pdf', 'size': 2},
            },
          ],
        },
      });
      await database.createDiary(
        title: 'legacy',
        contentDocJson: content,
        contentText: '',
        metadataJson: '{}',
      );
      final zip = await DataArchiveService.exportToZip(
        database: database,
        settingsService: settings,
      );
      documents = await Directory(
        p.join(root.path, 'legacy_imported_documents'),
      ).create();
      await DataArchiveService.importFromZip(
        database: database,
        settingsService: settings,
        zipPath: zip.path,
      );
      final diary = await database.select(database.diaries).getSingle();
      final nodes =
          ((jsonDecode(diary.content) as Map)['root'] as Map)['children']
              as List;
      expect(nodes[0]['attributes'], {
        'url': p.join(documents.path, relativeVideo),
        'width': 320,
      });
      final document = decodeDiaryContentToDocument(diary.content);
      final embeds = document
          .toDelta()
          .toJson()
          .where((op) => op['insert'] is Map)
          .toList();
      expect(embeds, hasLength(2));
      final restoredFile = DiaryFileAttachment.tryDecode(
        (embeds[1]['insert'] as Map)[diaryAttachmentEmbedType],
      );
      expect(restoredFile?.path, p.join(documents.path, relativeFile));
      expect(restoredFile?.name, '旧文件.pdf');
      expect(await File(restoredFile!.path).readAsBytes(), [2, 3]);
    },
  );
}

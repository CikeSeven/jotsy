import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  late Directory root;
  late Directory documents;
  late Directory temp;
  late AppDatabase database;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('jotsy_media_migration_');
    documents = await Directory(p.join(root.path, 'documents')).create();
    temp = await Directory(p.join(root.path, 'temporary')).create();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          return switch (call.method) {
            'getTemporaryDirectory' => temp.path,
            'getApplicationDocumentsDirectory' => documents.path,
            _ => null,
          };
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'v7 migration rebinds existing imported image and cover references',
    () async {
      final imageDirectory = Directory(p.join(documents.path, 'diary_images'));
      final coverDirectory = Directory(p.join(documents.path, 'diary_covers'));
      await imageDirectory.create();
      await coverDirectory.create();

      final restoredImage = p.join(imageDirectory.path, 'body.png');
      final restoredCover = p.join(coverDirectory.path, 'cover.jpg');
      await File(restoredImage).writeAsBytes(<int>[1, 2, 3]);
      await File(restoredCover).writeAsBytes(<int>[4, 5, 6]);

      const oldImage =
          '/data/user/0/com.jotsy.diary/app_flutter/diary_images/body.png';
      const oldCover =
          '/data/user/0/com.jotsy.diary/app_flutter/diary_covers/cover.jpg';
      const missingImage =
          '/data/user/0/com.jotsy.diary/app_flutter/diary_images/missing.png';
      final content = jsonEncode(<Map<String, Object>>[
        <String, Object>{
          'insert': <String, String>{'image': oldImage},
        },
        <String, Object>{
          'insert': <String, String>{'image': missingImage},
        },
        <String, Object>{
          'insert': <String, String>{
            'image': 'https://example.invalid/remote.png',
          },
        },
        <String, Object>{'insert': '\n'},
      ]);

      final databaseFile = File(p.join(root.path, 'legacy_v7.sqlite'));
      final legacy = sqlite3.open(databaseFile.path);
      legacy.execute('''
CREATE TABLE diaries (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  diary_id TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL DEFAULT '',
  content TEXT NOT NULL,
  content_text TEXT NOT NULL,
  cover TEXT NULL,
  metadata TEXT NOT NULL DEFAULT '{}',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  is_archived INTEGER NOT NULL DEFAULT 0,
  archived_at INTEGER NULL,
  is_pinned INTEGER NOT NULL DEFAULT 0,
  capsule_unlock_at INTEGER NULL,
  capsule_locked_at INTEGER NULL,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  deleted_at INTEGER NULL
)
''');
      legacy.execute('''
CREATE TABLE tags (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  color INTEGER NOT NULL
)
''');
      legacy.execute('''
CREATE TABLE diary_tags (
  diary_id INTEGER NOT NULL REFERENCES diaries (id) ON DELETE CASCADE,
  tag_id INTEGER NOT NULL REFERENCES tags (id) ON DELETE CASCADE,
  PRIMARY KEY (diary_id, tag_id)
)
''');
      legacy.execute(
        '''INSERT INTO diaries (id, diary_id, title, content, content_text, cover,
         metadata, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        <Object?>[
          1,
          'imported',
          'Imported diary',
          content,
          'keep this text',
          oldCover,
          '{}',
          DateTime(2026, 10, 1).millisecondsSinceEpoch,
          DateTime(2026, 10, 1).millisecondsSinceEpoch,
        ],
      );
      legacy.execute('PRAGMA user_version = 7');
      legacy.close();

      database = AppDatabase.forTesting(NativeDatabase(databaseFile));
      final diary = (await database.select(database.diaries).get()).single;
      final importedOps = jsonDecode(diary.content) as List<dynamic>;

      expect(
        (importedOps[0] as Map<String, dynamic>)['insert']['image'],
        restoredImage,
      );
      expect(
        (importedOps[1] as Map<String, dynamic>)['insert']['image'],
        missingImage,
      );
      expect(
        (importedOps[2] as Map<String, dynamic>)['insert']['image'],
        'https://example.invalid/remote.png',
      );
      expect(diary.cover, restoredCover);
      expect(diary.contentText, 'keep this text');
      expect(diary.title, 'Imported diary');
    },
  );
}

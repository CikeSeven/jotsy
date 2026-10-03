import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/data_archive_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  late Directory testRoot;
  late Directory temporaryDirectory;
  late Directory documentsDirectory;
  late AppDatabase database;
  late SettingsService settingsService;

  setUp(() async {
    testRoot = await Directory.systemTemp.createTemp(
      'jotsy_data_archive_test_',
    );
    temporaryDirectory = await Directory(
      p.join(testRoot.path, 'temporary'),
    ).create();
    documentsDirectory = await Directory(
      p.join(testRoot.path, 'documents'),
    ).create();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          return switch (call.method) {
            'getTemporaryDirectory' => temporaryDirectory.path,
            'getApplicationDocumentsDirectory' => documentsDirectory.path,
            _ => null,
          };
        });
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settingsService = await SettingsService.create();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    await database.close();
    if (await testRoot.exists()) {
      await testRoot.delete(recursive: true);
    }
  });

  test('export and import round-trips the diary card tag limit', () async {
    await settingsService.setDiaryCardTagLimit(7);
    final backup = await DataArchiveService.exportToZip(
      database: database,
      settingsService: settingsService,
    );

    await settingsService.setDiaryCardTagLimit(2);
    await DataArchiveService.importFromZip(
      database: database,
      settingsService: settingsService,
      zipPath: backup.path,
    );

    expect(settingsService.diaryCardTagLimit, 7);
    final recreatedSettings = await SettingsService.create();
    expect(recreatedSettings.diaryCardTagLimit, 7);
  });

  test(
    'import restores private image paths for a different app installation',
    () async {
      final oldImages = Directory(
        p.join(documentsDirectory.path, 'diary_images'),
      );
      final oldCovers = Directory(
        p.join(documentsDirectory.path, 'diary_covers'),
      );
      await oldImages.create();
      await oldCovers.create();

      final oldImagePath = p.join(oldImages.path, 'entry.png');
      final missingImagePath = p.join(oldImages.path, 'missing.png');
      final oldCoverPath = p.join(oldCovers.path, 'cover.png');
      await File(oldImagePath).writeAsBytes(<int>[1, 2, 3]);
      await File(oldCoverPath).writeAsBytes(<int>[4, 5, 6]);

      await database
          .into(database.diaries)
          .insert(
            DiariesCompanion.insert(
              diaryId: 'quill-media',
              title: const Value<String>('Quill media'),
              content: jsonEncode(<Map<String, Object>>[
                <String, Object>{
                  'insert': <String, String>{'image': oldImagePath},
                },
                <String, Object>{
                  'insert': <String, String>{'image': missingImagePath},
                },
                <String, Object>{
                  'insert': <String, String>{
                    'image': 'https://example.invalid/remote.jpg',
                  },
                },
                <String, Object>{
                  'insert': <String, String>{
                    'image': 'data:image/png;base64,AA==',
                  },
                },
                <String, Object>{'insert': '\n'},
              ]),
              contentText: '',
              cover: Value<String?>(oldCoverPath),
              createdAt: DateTime(2026, 10, 1),
              updatedAt: DateTime(2026, 10, 1),
            ),
          );
      await database
          .into(database.diaries)
          .insert(
            DiariesCompanion.insert(
              diaryId: 'legacy-media',
              title: const Value<String>('Legacy media'),
              content: jsonEncode(<String, Object>{
                'root': <String, Object>{
                  'children': <Object>[
                    <String, Object>{
                      'type': 'image',
                      'attributes': <String, String>{'url': oldImagePath},
                    },
                  ],
                },
              }),
              contentText: '',
              createdAt: DateTime(2026, 10, 2),
              updatedAt: DateTime(2026, 10, 2),
            ),
          );

      final backup = await DataArchiveService.exportToZip(
        database: database,
        settingsService: settingsService,
      );

      documentsDirectory = await Directory(
        p.join(testRoot.path, 'imported_documents'),
      ).create();
      await DataArchiveService.importFromZip(
        database: database,
        settingsService: settingsService,
        zipPath: backup.path,
      );

      final imported = await database.select(database.diaries).get();
      final quillDiary = imported.singleWhere(
        (diary) => diary.diaryId == 'quill-media',
      );
      final importedImagePath = p.join(
        documentsDirectory.path,
        'diary_images',
        'entry.png',
      );
      final importedCoverPath = p.join(
        documentsDirectory.path,
        'diary_covers',
        'cover.png',
      );
      final quillOps = jsonDecode(quillDiary.content) as List<dynamic>;
      expect(
        (quillOps[0] as Map<String, dynamic>)['insert']['image'],
        importedImagePath,
      );
      expect(
        (quillOps[1] as Map<String, dynamic>)['insert']['image'],
        missingImagePath,
      );
      expect(
        (quillOps[2] as Map<String, dynamic>)['insert']['image'],
        'https://example.invalid/remote.jpg',
      );
      expect(
        (quillOps[3] as Map<String, dynamic>)['insert']['image'],
        'data:image/png;base64,AA==',
      );
      expect(quillDiary.cover, importedCoverPath);
      expect(await File(importedImagePath).readAsBytes(), <int>[1, 2, 3]);
      expect(await File(importedCoverPath).readAsBytes(), <int>[4, 5, 6]);

      final legacy = imported.singleWhere(
        (diary) => diary.diaryId == 'legacy-media',
      );
      final legacyNode =
          (jsonDecode(legacy.content)
                  as Map<String, dynamic>)['root']['children'][0]
              as Map<String, dynamic>;
      expect(legacyNode['attributes']['url'], importedImagePath);
    },
  );

  test(
    'missing or malformed tag limits preserve the current setting',
    () async {
      await settingsService.setDiaryCardTagLimit(9);
      final missingLimitBackup = await _writeMinimalBackup(
        directory: temporaryDirectory,
        fileName: 'missing_limit.zip',
        settings: <String, Object?>{},
      );

      await DataArchiveService.importFromZip(
        database: database,
        settingsService: settingsService,
        zipPath: missingLimitBackup.path,
      );
      expect(settingsService.diaryCardTagLimit, 9);

      final malformedLimitBackup = await _writeMinimalBackup(
        directory: temporaryDirectory,
        fileName: 'malformed_limit.zip',
        settings: <String, Object?>{'diaryCardTagLimit': 'invalid'},
      );
      await DataArchiveService.importFromZip(
        database: database,
        settingsService: settingsService,
        zipPath: malformedLimitBackup.path,
      );
      expect(settingsService.diaryCardTagLimit, 9);
    },
  );

  test(
    'numeric string tag limits restore through SettingsService clamping',
    () async {
      final backup = await _writeMinimalBackup(
        directory: temporaryDirectory,
        fileName: 'numeric_string_limit.zip',
        settings: <String, Object?>{'diaryCardTagLimit': '99'},
      );

      await DataArchiveService.importFromZip(
        database: database,
        settingsService: settingsService,
        zipPath: backup.path,
      );

      expect(settingsService.diaryCardTagLimit, 20);
      final recreatedSettings = await SettingsService.create();
      expect(recreatedSettings.diaryCardTagLimit, 20);
    },
  );
}

Future<File> _writeMinimalBackup({
  required Directory directory,
  required String fileName,
  required Map<String, Object?> settings,
}) async {
  final payload = <String, Object?>{
    'formatVersion': 1,
    'database': <String, Object?>{
      'diaries': <Object?>[],
      'tags': <Object?>[],
      'diaryTags': <Object?>[],
    },
    'settings': settings,
  };
  final payloadBytes = utf8.encode(jsonEncode(payload));
  final archive = Archive()
    ..addFile(
      ArchiveFile('backup_data.json', payloadBytes.length, payloadBytes),
    );
  final zipBytes = ZipEncoder().encode(archive);
  if (zipBytes == null) {
    throw StateError('Failed to encode test backup.');
  }
  return File(
    p.join(directory.path, fileName),
  ).writeAsBytes(zipBytes, flush: true);
}

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/backup_constants.dart';
import 'package:node_diary/core/services/data_archive_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// 隔离备份验证的数据库、设置与媒体；调用方通过 documents 模拟另一安装目录。
class BackupTestFixture {
  BackupTestFixture._(this.root, this.documents, this.temporary, this.database);

  static const _channel = MethodChannel('plugins.flutter.io/path_provider');
  final Directory root;
  Directory documents;
  final Directory temporary;
  final AppDatabase database;
  late final SettingsService settings;
  final Map<String, List<int>> originalMedia = {};

  static Future<BackupTestFixture> create() async {
    final root = await Directory.systemTemp.createTemp('jotsy_backup_test_');
    final fixture = BackupTestFixture._(
      root,
      await Directory(p.join(root.path, 'documents')).create(),
      await Directory(p.join(root.path, 'temporary')).create(),
      AppDatabase.forTesting(NativeDatabase.memory()),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _channel,
          (call) async => switch (call.method) {
            'getApplicationDocumentsDirectory' => fixture.documents.path,
            'getTemporaryDirectory' => fixture.temporary.path,
            _ => null,
          },
        );
    SharedPreferences.setMockInitialValues({});
    fixture.settings = await SettingsService.create();
    return fixture;
  }

  Future<void> dispose() async {
    await database.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    await root.delete(recursive: true);
  }

  Future<String> seedCurrentData() async {
    final embeds = <Object>[];
    for (final name in backupMediaDirectories) {
      final file = File(p.join(documents.path, name, 'keep.bin'));
      await file.parent.create(recursive: true);
      final bytes = [0, 255, name.length];
      await file.writeAsBytes(bytes);
      originalMedia[file.path] = bytes;
      if (name == 'diary_videos' || name == 'diary_attachments') {
        embeds.add({
          'insert': {
            name == 'diary_videos' ? 'video' : 'attachment': file.path,
          },
        });
        embeds.add({'insert': '\n'});
      }
    }
    final diaryId = await database.createDiary(
      title: 'current diary',
      contentDocJson: jsonEncode(embeds),
      contentText: '',
      metadataJson: '{"keep":"metadata"}',
    );
    await settings.setCreateDiaryDraftRaw('{"title":"current draft"}');
    return diaryId;
  }

  Future<Map<String, Object?>> capturePayload() async {
    final zip = await DataArchiveService.exportToZip(
      database: database,
      settingsService: settings,
    );
    final archive = ZipDecoder().decodeBytes(
      await zip.readAsBytes(),
      verify: true,
    );
    try {
      final file = archive.files.singleWhere(
        (file) => file.name == backupPayloadFileName,
      );
      return (jsonDecode(utf8.decode(file.content as List<int>)) as Map)
          .cast<String, Object?>();
    } finally {
      archive.clearSync();
    }
  }

  Map<String, Object?> emptyPayload() => {
    'formatVersion': 1,
    'database': {'diaries': [], 'tags': [], 'diaryTags': []},
    'settings': <String, Object?>{},
  };

  Future<File> writeZip(
    Map<String, Object?> payload, {
    Map<String, List<int>> files = const {},
    String? password,
  }) async {
    final bytes = utf8.encode(jsonEncode(payload));
    final archive = Archive()
      ..addFile(
        ArchiveFile(backupPayloadFileName, bytes.length, bytes)
          ..compress = false,
      );
    for (final entry in files.entries) {
      archive.addFile(
        ArchiveFile(entry.key, entry.value.length, entry.value)
          ..compress = false,
      );
    }
    final target = File(
      p.join(
        temporary.path,
        'probe_${DateTime.now().microsecondsSinceEpoch}.zip',
      ),
    );
    await target.writeAsBytes(ZipEncoder(password: password).encode(archive)!);
    return target;
  }

  Future<void> import(File zip, {String? password}) =>
      DataArchiveService.importFromZip(
        database: database,
        settingsService: settings,
        zipPath: zip.path,
        zipPassword: password,
      );

  Future<void> expectCurrentDataIntact() async {
    expect(
      (await database.select(database.diaries).getSingle()).title,
      'current diary',
    );
    expect(settings.createDiaryDraftRaw, '{"title":"current draft"}');
    for (final entry in originalMedia.entries) {
      expect(await File(entry.key).readAsBytes(), entry.value);
    }
    expect(
      await documents
          .list()
          .where(
            (entry) => p.basename(entry.path).startsWith('.backup_import_'),
          )
          .toList(),
      isEmpty,
    );
  }
}

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/backup_file_save_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.jotsy.diary/backup_file_saver');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('Android backup save sends file path instead of ZIP bytes', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return '/storage/emulated/0/Download/backup.zip';
        });

    final savePath = await BackupFileSaveService.saveAndroidBackupFile(
      zipFile: File('/tmp/node_note_backup.zip'),
      fileName: 'node_note_backup.zip',
    );

    expect(savePath, '/storage/emulated/0/Download/backup.zip');
    expect(calls, hasLength(1));
    expect(calls.single.method, 'saveBackupFile');
    expect(calls.single.arguments, <String, Object?>{
      'sourcePath': '/tmp/node_note_backup.zip',
      'fileName': 'node_note_backup.zip',
      'mimeType': 'application/zip',
    });
  });
}

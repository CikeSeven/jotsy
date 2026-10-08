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

  test('mobile backup save sends the ZIP path to its native picker', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return '/storage/emulated/0/Download/backup.zip';
        });

    final savePath = await BackupFileSaveService.saveNativeBackupFile(
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

  test(
    'canceling the native save returns null and preserves the source ZIP',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'jotsy_save_cancel_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final source = await File(
        '${directory.path}/backup.zip',
      ).writeAsBytes([1, 2, 3]);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => null);
      expect(
        await BackupFileSaveService.saveNativeBackupFile(
          zipFile: source,
          fileName: 'backup.zip',
        ),
        isNull,
      );
      expect(await source.readAsBytes(), [1, 2, 3]);
    },
  );

  test(
    'native save failures preserve the source ZIP and reach the caller',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'jotsy_save_failure_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final source = await File(
        '${directory.path}/backup.zip',
      ).writeAsBytes([1, 2, 3]);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => throw PlatformException(code: 'copy_failed'),
          );
      await expectLater(
        BackupFileSaveService.saveNativeBackupFile(
          zipFile: source,
          fileName: 'backup.zip',
        ),
        throwsA(isA<PlatformException>()),
      );
      expect(await source.readAsBytes(), [1, 2, 3]);
    },
  );
}

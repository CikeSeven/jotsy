import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/backup_archive_io.dart';

void main() {
  test(
    'worker writes the same indented UTF-8 JSON for large multilingual payloads',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'backup_json_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final payload = <String, Object?>{
        'formatVersion': 1,
        'diaries': [
          for (var i = 0; i < 1000; i++)
            {'id': i, 'text': '中文 日本語 русский 😀\n' * 20},
        ],
        'optional': null,
      };
      final file = File('${directory.path}/payload.json');
      await BackupArchiveIO.writeJson(file.path, payload);
      expect(
        await file.readAsString(),
        const JsonEncoder.withIndent('  ').convert(payload),
      );
      expect(jsonDecode(await file.readAsString()), payload);
    },
  );

  test('worker propagates file failures to the caller', () async {
    final directory = await Directory.systemTemp.createTemp(
      'backup_json_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    await expectLater(
      BackupArchiveIO.writeJson('${directory.path}/missing/payload.json', {
        'a': 1,
      }),
      throwsA(isA<FileSystemException>()),
    );
  });
}

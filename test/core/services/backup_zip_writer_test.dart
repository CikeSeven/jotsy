import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/backup_zip_reader.dart';
import 'package:node_diary/core/services/backup_zip_writer.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late Directory input;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('jotsy_zip_writer_');
    input = await Directory(p.join(root.path, 'input')).create();
  });
  tearDown(() => root.delete(recursive: true));

  for (final password in ['password', '密码123']) {
    test(
      'streamed AES ZIP64 backups remain readable by the previous archive decoder ($password)',
      () async {
        final video = File(
          p.join(input.path, 'diary_videos', 'media_1', '旅行..mp4'),
        );
        await video.parent.create(recursive: true);
        final bytes = Uint8List.fromList(
          List.generate(2 * 1024 * 1024 + 31, (index) => index % 251),
        );
        await video.writeAsBytes(bytes);
        final payload = await File(
          p.join(input.path, 'backup_data.json'),
        ).writeAsString('{"formatVersion":1}');
        final empty = await File(
          p.join(input.path, 'empty.txt'),
        ).writeAsBytes([]);
        final zip = File(p.join(root.path, 'backup.zip'));
        BackupZipWriter.writeEncryptedDirectory(input.path, zip.path, password);
        expect(BackupZipReader.isPasswordProtected(zip.path), isTrue);
        // 验证旧库能独立解密并校验我们的目录、ZIP64 长度/偏移和整条目认证码。
        final archive = ZipDecoder().decodeBytes(
          await zip.readAsBytes(),
          verify: true,
          password: password,
        );
        try {
          expect(archive.files, hasLength(3));
          final restored = archive.files.singleWhere(
            (entry) => entry.name.endsWith('.mp4'),
          );
          expect(restored.size, bytes.length);
          expect(getCrc32(restored.content as List<int>), getCrc32(bytes));
          expect(await video.readAsBytes(), bytes);
          expect(await payload.readAsString(), '{"formatVersion":1}');
          expect(await empty.length(), 0);
        } finally {
          archive.clearSync();
        }
      },
    );
  }

  test('failed encrypted exports remove the incomplete ZIP', () {
    final zip = File(p.join(root.path, 'partial.zip'));
    expect(
      () => BackupZipWriter.writeEncryptedDirectory(
        p.join(root.path, 'missing'),
        zip.path,
        'password',
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(zip.existsSync(), isFalse);
  });
}

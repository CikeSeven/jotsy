import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/backup_zip_reader.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  setUp(
    () async =>
        root = await Directory.systemTemp.createTemp('jotsy_zip_reader_'),
  );
  tearDown(() => root.delete(recursive: true));

  for (final compressed in [false, true]) {
    for (final password in [null, 'stream-password']) {
      test(
        'large ${compressed ? 'deflated' : 'stored'} ${password == null ? 'plain' : 'encrypted'} entries are decoded in bounded chunks',
        () async {
          final bytes = Uint8List.fromList(
            List.generate(2 * 1024 * 1024 + 31, (index) => index % 251),
          );
          // archive 的 STORE 加密会原地修改输入 Uint8List，先保留原文件校验值。
          final expectedCrc = getCrc32(bytes);
          final archive = Archive()
            ..addFile(
              ArchiveFile('diary_videos/clip..mp4', bytes.length, bytes)
                ..compress = compressed,
            );
          final zip = await File(
            p.join(root.path, 'backup.zip'),
          ).writeAsBytes(ZipEncoder(password: password).encode(archive)!);
          final output = await Directory(p.join(root.path, 'output')).create();
          var maximumChunk = 0;
          var reads = 0;
          BackupZipReader.extract(
            zip.path,
            output.path,
            password: password,
            onChunkRead: (count) {
              reads++;
              if (count > maximumChunk) maximumChunk = count;
            },
          );
          final restored = File(
            p.join(output.path, 'diary_videos', 'clip..mp4'),
          );
          expect(await restored.length(), bytes.length);
          expect(
            await restored.openRead().fold<int>(
              0,
              (crc, chunk) => getCrc32(chunk, crc),
            ),
            expectedCrc,
          );
          expect(maximumChunk, inInclusiveRange(1, 64 * 1024));
          if (!compressed) expect(reads, greaterThan(30));
        },
      );
    }
  }

  for (final path in [
    '../escape.bin',
    'diary_videos/../escape.bin',
    '/absolute.bin',
    r'C:\escape.bin',
  ]) {
    test(
      'unsafe ZIP path $path rejects extraction without escaping the working directory',
      () async {
        final archive = Archive()..addFile(ArchiveFile(path, 1, [1]));
        final zip = await File(
          p.join(root.path, 'unsafe.zip'),
        ).writeAsBytes(ZipEncoder().encode(archive)!);
        final output = await Directory(p.join(root.path, 'output')).create();
        expect(
          () => BackupZipReader.extract(zip.path, output.path),
          throwsA(isA<FormatException>()),
        );
        expect(await File(p.join(root.path, 'escape.bin')).exists(), isFalse);
      },
    );
  }

  test(
    'duplicate normalized ZIP paths reject extraction instead of replacing media',
    () async {
      final archive = Archive()
        ..addFile(ArchiveFile('diary_videos/clip.mp4', 1, [1]))
        ..addFile(ArchiveFile('diary_videos/./clip.mp4', 1, [2]));
      final zip = await File(
        p.join(root.path, 'duplicates.zip'),
      ).writeAsBytes(ZipEncoder().encode(archive)!);
      final output = await Directory(p.join(root.path, 'output')).create();
      expect(
        () => BackupZipReader.extract(zip.path, output.path),
        throwsA(isA<FormatException>()),
      );
    },
  );
}

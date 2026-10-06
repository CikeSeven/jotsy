import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('jotsy_media_storage_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => root.path);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await root.delete(recursive: true);
  });

  for (final kind in DiaryMediaKind.values) {
    test(
      '$kind import retains bytes after the original file is removed',
      () async {
        final source = File(p.join(root.path, 'picked.mp4'));
        await source.writeAsBytes([1, 2, 3, 4]);
        final file = await DiaryMediaStorageService.importFile(
          kind: kind,
          fileName: '旅行 视频.mp4',
          sourcePath: source.path,
        );
        await source.delete();
        expect(file.displayName, '旅行 视频.mp4');
        expect(file.sizeBytes, 4);
        expect(p.basename(file.path), '旅行 视频.mp4');
        expect(await File(file.path).readAsBytes(), [1, 2, 3, 4]);
        expect(
          p.isWithin(
            p.join(root.path, DiaryMediaStorageService.directoryNameFor(kind)),
            file.path,
          ),
          isTrue,
        );
      },
    );
  }

  test('same-name attachments are preserved independently', () async {
    final first = await DiaryMediaStorageService.importFile(
      kind: DiaryMediaKind.attachment,
      fileName: '报告.pdf',
      bytes: [1, 2],
    );
    final second = await DiaryMediaStorageService.importFile(
      kind: DiaryMediaKind.attachment,
      fileName: '报告.pdf',
      bytes: [3, 4],
    );
    expect(first.path, isNot(second.path));
    expect(await File(first.path).readAsBytes(), [1, 2]);
    expect(await File(second.path).readAsBytes(), [3, 4]);
  });

  test('video imports accept file streams without a filesystem path', () async {
    final file = await DiaryMediaStorageService.importFile(
      kind: DiaryMediaKind.video,
      fileName: 'stream.mp4',
      readStream: Stream.fromIterable([
        [1, 2],
        [3, 4, 5],
      ]),
    );
    expect(file.sizeBytes, 5);
    expect(await File(file.path).readAsBytes(), [1, 2, 3, 4, 5]);
  });

  test('failed streams remove incomplete managed files', () async {
    await expectLater(
      DiaryMediaStorageService.importFile(
        kind: DiaryMediaKind.video,
        fileName: 'broken.mp4',
        readStream: Stream.error(const FileSystemException('copy interrupted')),
      ),
      throwsA(isA<FileSystemException>()),
    );
    final videos = Directory(p.join(root.path, 'diary_videos'));
    expect(await videos.list(recursive: true).toList(), isEmpty);
  });

  test('cleanup deletes managed copies and preserves external files', () async {
    final external = File(p.join(root.path, 'external.pdf'));
    await external.writeAsBytes([5]);
    final file = await DiaryMediaStorageService.importFile(
      kind: DiaryMediaKind.attachment,
      fileName: '../报告.pdf',
      sourcePath: external.path,
    );
    expect(p.basename(file.path), '报告.pdf');
    await DiaryMediaStorageService.deleteManagedDiaryFile(external.path);
    expect(await external.exists(), isTrue);
    await DiaryMediaStorageService.deleteManagedDiaryFile(
      File(file.path).uri.toString(),
    );
    expect(await File(file.path).exists(), isFalse);
    expect(await File(file.path).parent.exists(), isFalse);
    expect(await external.exists(), isTrue);
  });
}

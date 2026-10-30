import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_media_index.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_media_refs.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late Directory dataRoot;
  late Directory stateDir;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('jotsy_sync_media_');
    dataRoot = await Directory(p.join(root.path, 'data')).create();
    stateDir = Directory(p.join(root.path, 'state'));
  });

  tearDown(() => root.delete(recursive: true));

  Future<File> write(String key, List<int> bytes) async {
    final file = File(p.joinAll(<String>[dataRoot.path, ...key.split('/')]));
    await file.parent.create(recursive: true);
    return file.writeAsBytes(bytes);
  }

  test(
    'hashes multi-chunk files correctly and reuses unchanged entries',
    () async {
      // 远大于 openRead 的单块大小（64 KiB），确认是分块流式累加的结果。
      final random = Random(7);
      final bytes = List<int>.generate(
        3 * 1024 * 1024 + 17,
        (_) => random.nextInt(256),
      );
      final file = await write('diary_videos/v.mp4', bytes);
      final index = SyncMediaIndex(stateDir: stateDir, dataRoot: dataRoot);

      final info = (await index.describe('diary_videos/v.mp4'))!;
      expect(info.sha256, sha256.convert(bytes).toString());
      expect(info.size, bytes.length);

      // 大小与修改时间都没变：直接用索引（新实例从文件读回）。
      final modified = await file.lastModified();
      final sameSize = List<int>.of(bytes)..[0] ^= 0xFF;
      await file.writeAsBytes(sameSize);
      await file.setLastModified(modified);
      final reloaded = SyncMediaIndex(stateDir: stateDir, dataRoot: dataRoot);
      expect(
        (await reloaded.describe('diary_videos/v.mp4'))!.sha256,
        info.sha256,
      );

      // 修改时间变了：重算。
      await file.setLastModified(modified.add(const Duration(seconds: 5)));
      expect(
        (await reloaded.describe('diary_videos/v.mp4'))!.sha256,
        sha256.convert(sameSize).toString(),
      );

      // 大小变了：重算。
      await file.writeAsBytes(<int>[1, 2, 3]);
      await file.setLastModified(modified);
      expect(
        (await reloaded.describe('diary_videos/v.mp4'))!.sha256,
        sha256.convert(<int>[1, 2, 3]).toString(),
      );
    },
  );

  test('missing files and invalid keys are left out', () async {
    await write('app_backgrounds/bg_1.jpg', <int>[9]);
    final index = SyncMediaIndex(stateDir: stateDir, dataRoot: dataRoot);
    final result = await index.describeAll(<String>[
      'app_backgrounds/bg_1.jpg',
      'diary_images/missing.jpg',
      'diary_images/../../etc/passwd',
      'not_managed/a.jpg',
      'app_backgrounds/../x',
    ]);
    expect(result.keys, <String>['app_backgrounds/bg_1.jpg']);
  });

  test('corrupt index file is treated as empty', () async {
    await stateDir.create(recursive: true);
    await File(
      p.join(stateDir.path, SyncMediaIndex.fileName),
    ).writeAsString('x');
    await write('diary_images/a.jpg', <int>[1]);
    final index = SyncMediaIndex(stateDir: stateDir, dataRoot: dataRoot);
    expect(
      (await index.describe('diary_images/a.jpg'))!.sha256,
      sha256.convert(<int>[1]).toString(),
    );
  });

  test('media keys map to paths only inside the data root', () {
    expect(
      syncMediaPathFor(dataRoot.path, 'diary_images/media_x/a.jpg'),
      p.join(dataRoot.path, 'diary_images', 'media_x', 'a.jpg'),
    );
    expect(syncMediaPathFor(dataRoot.path, 'diary_images/../a.jpg'), isNull);
    expect(syncMediaPathFor(dataRoot.path, 'diary_images'), isNull);
    expect(
      syncMediaKeyOfLocalPath('/x/diary_covers/c.jpg'),
      'diary_covers/c.jpg',
    );
    expect(
      syncMediaKeyOfLocalPath(r'C:\data\diary_images\a.jpg'),
      'diary_images/a.jpg',
    );
    expect(
      syncMediaKeyOfLocalPath('file:///x/diary_images/a%20b.jpg'),
      'diary_images/a b.jpg',
    );
    expect(syncMediaKeyOfLocalPath('diary_images/a.jpg'), isNull);
    expect(syncMediaKeyOfLocalPath('https://h/diary_images/a.jpg'), isNull);
  });
}

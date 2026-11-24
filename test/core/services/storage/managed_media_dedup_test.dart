import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/diary_cover_storage_service.dart';
import 'package:node_diary/core/services/diary_media_cleanup_service.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:node_diary/core/services/managed_media_write_gate.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/core/services/storage/managed_media_content_index.dart';
import 'package:node_diary/core/services/storage/managed_media_dedup.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('jotsy_media_dedup_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => root.path);
    ManagedMediaDedup.debugReset();
    ManagedMediaContentIndex.debugReset();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await root.delete(recursive: true);
  });

  Future<String> importImage(List<int> bytes, {String name = 'a.jpg'}) async =>
      (await DiaryMediaStorageService.importFile(
        kind: DiaryMediaKind.image,
        fileName: name,
        bytes: bytes,
      )).path;

  Future<List<String>> filesIn(String directory) async {
    final folder = Directory(p.join(root.path, directory));
    if (!await folder.exists()) return const [];
    return [
      await for (final entity in folder.list(recursive: true))
        if (entity is File) p.relative(entity.path, from: folder.path),
    ];
  }

  Future<String> source(String name, List<int> bytes) async {
    final file = File(p.join(root.path, 'picked', name));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file.path;
  }

  test('importing identical bytes again reuses the first copy', () async {
    final first = await importImage([1, 2, 3], name: 'first.jpg');
    final again = await DiaryMediaStorageService.importFile(
      kind: DiaryMediaKind.image,
      fileName: 'again.jpg',
      bytes: [1, 2, 3],
    );
    expect(again.path, first);
    // 显示名跟着这次导入走，文件是共用的那份。
    expect(again.displayName, 'again.jpg');
    expect(await filesIn('diary_images'), hasLength(1));
    // 第二次导入的批次目录随新副本一起删掉了。
    expect(await Directory(p.join(root.path, 'diary_images')).list().length, 1);
  });

  test('same size with different content keeps both files', () async {
    final first = await importImage([1, 2, 3]);
    final second = await importImage([1, 2, 4]);
    expect(second, isNot(first));
    expect(await File(second).readAsBytes(), [1, 2, 4]);
  });

  test('a cover reuses the identical body image', () async {
    final body = await importImage([5, 6, 7, 8]);
    final cover = await DiaryCoverStorageService.importCover(
      await source('cover.jpg', [5, 6, 7, 8]),
    );
    expect(cover, body);
    expect(await filesIn('diary_covers'), isEmpty);
  });

  test('a body image never points into diary_covers', () async {
    final cover = await DiaryCoverStorageService.importCover(
      await source('cover.jpg', [9, 9, 9]),
    );
    final body = await importImage([9, 9, 9]);
    expect(p.isWithin(p.join(root.path, 'diary_images'), body), isTrue);
    expect(body, isNot(cover));
  });

  test('a video reuses an identical attachment', () async {
    final attachment = await DiaryMediaStorageService.importFile(
      kind: DiaryMediaKind.attachment,
      fileName: 'clip.mp4',
      bytes: [4, 4, 4, 4],
    );
    final video = await DiaryMediaStorageService.importFile(
      kind: DiaryMediaKind.video,
      fileName: 'clip.mp4',
      bytes: [4, 4, 4, 4],
    );
    expect(video.path, attachment.path);
    expect(await filesIn('diary_videos'), isEmpty);
  });

  test('rolling back an import never deletes a shared file', () async {
    final first = await importImage([1, 1, 1]);
    final reused = await importImage([1, 1, 1]);
    expect(reused, first);
    // 第二次导入失败回滚：删的是“自己刚导入的文件”，但它是共用的那份。
    await DiaryMediaStorageService.deleteManagedDiaryFile(reused);
    expect(await File(first).exists(), isTrue);
    // 第一次导入的回滚同样不能再删：它已经被共用了。
    await DiaryMediaStorageService.deleteManagedDiaryFile(first);
    expect(await File(first).exists(), isTrue);

    final fresh = await importImage([2, 2, 2]);
    await DiaryMediaStorageService.deleteManagedDiaryFile(fresh);
    expect(await File(fresh).exists(), isFalse);
  });

  test('rollback leaves files this run did not import', () async {
    final earlier = File(p.join(root.path, 'diary_images', 'm0', 'old.jpg'));
    await earlier.parent.create(recursive: true);
    await earlier.writeAsBytes([3, 3]);
    await DiaryMediaStorageService.deleteManagedDiaryFile(earlier.path);
    expect(await earlier.exists(), isTrue);
  });

  test('reuse restarts the cleanup grace period of an old file', () async {
    final first = await importImage([7, 7, 7]);
    await File(first).setLastModified(DateTime(2020));
    final before = DateTime.now().subtract(const Duration(seconds: 5));
    expect(await importImage([7, 7, 7]), first);
    expect((await File(first).lastModified()).isAfter(before), isTrue);
  });

  test('no reuse while another flow is placing files', () async {
    final first = await importImage([8, 8, 8]);
    final release = Completer<void>();
    final writer = ManagedMediaWriteGate.write(() => release.future);
    try {
      final second = await importImage([8, 8, 8]);
      expect(second, isNot(first));
    } finally {
      release.complete();
      await writer;
    }
  });

  test('a sweep running during reuse cannot remove the reused file', () async {
    // 没有任何引用、早已过了宽限期的文件：不复用的话这一轮回收会删掉它。
    final orphan = await importImage([7, 7, 7, 7]);
    await File(orphan).setLastModified(DateTime(2020));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.create();
    final temp = await Directory.systemTemp.createTemp('jotsy_dedup_tmp_');
    addTearDown(() => temp.delete(recursive: true));
    final hold = Completer<void>();
    final cleanup = DiaryMediaCleanupService(
      database: database,
      settings: () async {
        await hold.future;
        return settings;
      },
      documentsDirectory: () async => root,
      temporaryDirectory: () async => temp,
    );
    addTearDown(cleanup.dispose);

    final sweeping = cleanup.sweep();
    var adopted = false;
    final adopting = importImage([
      7,
      7,
      7,
      7,
    ]).whenComplete(() => adopted = true);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // 复用要等这一轮回收结束再确认文件还在。
    expect(adopted, isFalse);

    hold.complete();
    await sweeping;
    expect(await adopting, orphan);
    expect(await File(orphan).exists(), isTrue);
  });

  test('files placed later by sync or restore are found too', () async {
    await importImage([1]);
    // 同步就位的文件：另一个批次目录，不经导入。
    final synced = File(p.join(root.path, 'diary_images', 'media_s', 'x.jpg'));
    await synced.parent.create(recursive: true);
    await synced.writeAsBytes([6, 5, 4]);
    expect(await importImage([6, 5, 4]), synced.path);
  });
}

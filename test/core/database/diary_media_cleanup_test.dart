import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/audio_embed_codec.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/services/diary_media_cleanup_service.dart';
import 'package:node_diary/core/services/long_image_tile_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 所有测试文件都按真实时间创建；回收时钟拨到两天后，使其超出 24h 宽限期。
  final now = DateTime.now().add(const Duration(days: 2));
  late Directory root;
  late Directory documents;
  late Directory cache;
  late AppDatabase database;
  late SettingsService settings;

  Future<File> put(
    Directory base,
    String relative, {
    DateTime? modified,
  }) async {
    final file = File(p.joinAll([base.path, ...relative.split('/')]));
    await file.parent.create(recursive: true);
    await file.writeAsBytes([1, 2, 3, 4]);
    if (modified != null) await file.setLastModified(modified);
    return file;
  }

  // 正文里存的是旧安装根目录下的绝对路径，验证回收按托管目录定位而非整路径比较。
  String stored(String relative) => '/old/container/Documents/$relative';

  Future<String> createDiary(List<Map<String, Object?>> ops, {String? cover}) =>
      database.createDiary(
        title: '',
        contentText: '',
        metadataJson: '{}',
        contentDocJson: jsonEncode([
          ...ops,
          {'insert': '\n'},
        ]),
        cover: cover,
      );

  DiaryMediaCleanupService service({
    Future<SettingsService> Function()? from,
  }) => DiaryMediaCleanupService(
    database: database,
    settings: from ?? () async => settings,
    documentsDirectory: () async => documents,
    temporaryDirectory: () async => cache,
    clock: () => now,
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('jotsy_media_cleanup_test_');
    documents = await Directory(p.join(root.path, 'docs')).create();
    cache = await Directory(p.join(root.path, 'cache')).create();
    database = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsService.create();
  });

  tearDown(() async {
    await database.close();
    await root.delete(recursive: true);
  });

  test(
    'sweep removes expired orphans but keeps every referenced or fresh file',
    () async {
      final active = await put(documents, 'diary_images/media_1/a.jpg');
      final cover = await put(documents, 'diary_covers/cover_1.jpg');
      final recording = await put(documents, 'diary_recordings/rec_1.m4a');
      final recycled = await put(documents, 'diary_attachments/media_2/b.pdf');
      final drafted = await put(documents, 'diary_images/media_3/draft.jpg');
      final boxedImage = await put(documents, 'diary_images/media_7/box.jpg');
      final boxedCover = await put(documents, 'diary_covers/cover_box.jpg');
      final fresh = await put(
        documents,
        'diary_images/media_4/fresh.jpg',
        modified: now.subtract(const Duration(hours: 1)),
      );
      final external = await put(documents, 'notes/external.pdf');
      final orphans = [
        await put(documents, 'diary_images/media_5/orphan.jpg'),
        await put(documents, 'diary_videos/media_6/orphan.mp4'),
        await put(documents, 'diary_recordings/rec_old.m4a'),
        await put(documents, 'diary_covers/cover_old.jpg'),
      ];
      final staleCopy = await put(cache, 'file_picker/1700000000/IMG_1.jpg');
      final freshCopy = await put(
        cache,
        'diary_video_gallery/selection_1/0/clip.mp4',
        modified: now,
      );

      await createDiary([
        {
          'insert': {'image': stored('diary_images/media_1/a.jpg')},
        },
        {
          'insert': {
            diaryAudioEmbedType: DiaryAudioAttachment(
              path: stored('diary_recordings/rec_1.m4a'),
              duration: const Duration(seconds: 2),
            ).encode(),
          },
        },
      ], cover: stored('diary_covers/cover_1.jpg'));
      final binned = await createDiary([
        {
          'insert': {
            diaryAttachmentEmbedType: DiaryFileAttachment(
              path: stored('diary_attachments/media_2/b.pdf'),
            ).encode(),
          },
        },
      ]);
      await database.softDeleteDiary(binned);
      await settings.setCreateDiaryDraftRaw(
        jsonEncode({
          'contentDocJson': jsonEncode([
            {
              'insert': {'image': drafted.path},
            },
          ]),
        }),
      );
      // 草稿箱里的草稿：正文图片与封面都只被草稿引用。
      await database.saveDiaryDraft(
        title: 'draft',
        contentText: '',
        payload: jsonEncode({
          'contentDocJson': jsonEncode([
            {
              'insert': {'image': boxedImage.path},
            },
          ]),
          'cover': boxedCover.path,
        }),
      );

      final report = await service().sweep();

      for (final kept in [
        active,
        cover,
        recording,
        recycled,
        drafted,
        boxedImage,
        boxedCover,
        fresh,
        external,
        freshCopy,
      ]) {
        expect(await kept.exists(), isTrue, reason: kept.path);
      }
      for (final removed in [...orphans, staleCopy]) {
        expect(await removed.exists(), isFalse, reason: removed.path);
      }
      expect(report?.deletedFiles, 5);
      expect(report?.freedBytes, 20);
      // 删空的导入批次目录一并移除，托管根目录与缓存根目录保留。
      expect(
        await Directory(
          p.join(documents.path, 'diary_images/media_5'),
        ).exists(),
        isFalse,
      );
      expect(
        await Directory(p.join(cache.path, 'file_picker/1700000000')).exists(),
        isFalse,
      );
      expect(
        await Directory(p.join(documents.path, 'diary_images')).exists(),
        isTrue,
      );
      expect(
        await Directory(p.join(cache.path, 'file_picker')).exists(),
        isTrue,
      );
    },
  );

  test(
    'purging one diary keeps media still shared with another diary',
    () async {
      final shared = await put(documents, 'diary_images/media_1/shared.jpg');
      final ops = [
        {
          'insert': {'image': stored('diary_images/media_1/shared.jpg')},
        },
      ];
      final first = await createDiary(ops);
      final second = await createDiary(ops);
      final cleanup = service();

      await database.hardDeleteDiary(first);
      expect(await shared.exists(), isTrue);
      await cleanup.sweep();
      expect(await shared.exists(), isTrue);

      await database.hardDeleteDiary(second);
      await cleanup.sweep();
      expect(await shared.exists(), isFalse);
      expect(await database.select(database.diaries).get(), isEmpty);
    },
  );

  test('a failed reference read deletes nothing', () async {
    final orphan = await put(documents, 'diary_images/media_1/orphan.jpg');

    final report = await service(
      from: () =>
          Future<SettingsService>.error(StateError('prefs unavailable')),
    ).sweep();

    expect(report, isNull);
    expect(await orphan.exists(), isTrue);
  });

  test('long image tiles go once their original image is gone', () async {
    final live = await put(documents, 'diary_images/media_1/long.png');
    await createDiary([
      {
        'insert': {'image': stored('diary_images/media_1/long.png')},
      },
    ]);
    Future<Directory> tiles(String key, {String? source}) async {
      final dir = Directory(
        p.join(cache.path, LongImageTileService.directoryName, key),
      );
      await put(dir, '0.png');
      if (source != null) {
        await File(
          p.join(dir.path, LongImageTileService.manifestName),
        ).writeAsString(jsonEncode({'source': source, 'tiles': []}));
      }
      return dir;
    }

    final kept = await tiles('live', source: live.path);
    final orphaned = await tiles(
      'orphaned',
      source: p.join(documents.path, 'diary_images/media_1/deleted.png'),
    );
    // 中断的切片暂存目录没有清单。
    final staging = await tiles('live.tmp-1');

    await service().sweep();

    expect(await kept.exists(), isTrue);
    expect(await orphaned.exists(), isFalse);
    expect(await staging.exists(), isFalse);
  });
}

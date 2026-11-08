import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_media.dart';
import 'package:node_diary/core/services/diary_media_cleanup_service.dart';
import 'package:node_diary/core/services/editing_session_registry.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/core/services/storage/media_compressor.dart';
import 'package:node_diary/core/services/storage/storage_compress_plan.dart';
import 'package:node_diary/core/services/storage/storage_media_service.dart';
import 'package:node_diary/core/services/storage/storage_usage_models.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fake_media_compressor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 测试时钟取“真实时间之后 2 小时”而不是写死的日期：缓存子目录本身的
  // 修改时间是建目录时的真实时间（dart:io 改不了目录的时间），写死的
  // 日期一旦早于真实时间，旧缓存所在的目录就比“现在”还新、被当成没闲置。
  // 往后挪 2 小时（超过 1 小时的闲置门槛），目录本身的时间总算闲置，
  // 条目是否闲置只取决于测试给文件设的时间。
  final now = DateTime.now().add(const Duration(hours: 2));
  final old = DateTime(2025, 1, 1);
  late Directory root;
  late Directory temp;
  late AppDatabase database;
  late SettingsService settings;
  late FakeMediaCompressor compressor;

  Future<String> put(
    String relative,
    int length, {
    DateTime? modified,
    Directory? base,
  }) async {
    final file = File(p.joinAll([(base ?? root).path, ...relative.split('/')]));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(List<int>.filled(length, 1));
    await file.setLastModified(modified ?? old);
    return file.path;
  }

  String docWith(List<String> images, {String text = '文字'}) =>
      encodeDiaryBlocks({
        'document': {
          'type': 'page',
          'children': [
            {
              'type': 'paragraph',
              'data': {
                'delta': [
                  {'insert': text},
                ],
              },
            },
            for (final image in images)
              {
                'type': 'image',
                'data': {'url': image},
              },
          ],
        },
      });

  Future<String> createDiary(List<String> images, {String? cover}) =>
      database.createDiary(
        title: '日记',
        contentDocJson: docWith(images),
        contentText: '文字',
        metadataJson: '{}',
        cover: cover,
      );

  Future<Diary> diaryRow(String diaryId) => (database.select(
    database.diaries,
  )..where((t) => t.diaryId.equals(diaryId))).getSingle();

  List<String?> imagesOf(Diary diary) => [
    for (final media in diaryContentMedia(diary.content)) media.path,
  ];

  StorageMediaService service() => StorageMediaService(
    database: database,
    settings: () async => settings,
    mediaCleanup: DiaryMediaCleanupService(
      database: database,
      settings: () async => settings,
      documentsDirectory: () async => root,
      temporaryDirectory: () async => temp,
      clock: () => now,
    ),
    compressor: compressor,
    dataRoot: () async => root,
    temporaryDirectory: () async => temp,
    fontsPath: () async => null,
    clock: () => now,
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('jotsy_storage_root_');
    temp = await Directory.systemTemp.createTemp('jotsy_storage_temp_');
    database = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsService.create();
    compressor = FakeMediaCompressor();
  });

  tearDown(() async {
    EditingSessionRegistry.instance.debugReset();
    await database.close();
    await root.delete(recursive: true);
    await temp.delete(recursive: true);
  });

  group('scan', () {
    test('groups referenced media, orphans, covers and cache', () async {
      final shared = await put('diary_images/m1/shared.jpg', 4000);
      await put('diary_images/m1/orphan_old.jpg', 300);
      await put('diary_images/m1/orphan_new.jpg', 200, modified: now);
      final cover = await put('diary_covers/cover_1.jpg', 500);
      final video = await put('diary_videos/m2/clip.mp4', 9000);
      await put('diary_export/1/a.pdf', 700, base: temp);
      await put('diary_export/2/b.pdf', 100, base: temp, modified: now);
      await put('app_backgrounds/bg_1.jpg', 50);

      final diary = await createDiary([shared, video]);
      await database.addDiaryComment(
        diaryId: diary,
        content: '',
        images: [shared],
      );
      await database.createNotebook(
        name: '旅行',
        payload: NotebookPayload.defaults.copyWith(coverPath: cover),
      );
      compressor = FakeMediaCompressor(
        videoInfo: {
          video: const StorageVideoInfo(
            width: 3840,
            height: 2160,
            durationMs: 10000,
            bitrate: 40000000,
          ),
        },
        space: const StorageDeviceSpace(totalBytes: 100, freeBytes: 40),
      );

      final report = await service().scan();

      expect(report.media.map((e) => e.key), [
        'diary_videos/m2/clip.mp4',
        'diary_images/m1/shared.jpg',
        'diary_covers/cover_1.jpg',
      ]);
      final image = report.media[1];
      expect(image.refs.whereType<StorageDiaryRef>(), hasLength(1));
      expect(image.refs.whereType<StorageCommentRef>(), hasLength(1));
      expect(report.media[2].refs.single, isA<StorageNotebookCoverRef>());
      expect(report.bytesOf(StorageCategory.images), 4000);
      expect(report.bytesOf(StorageCategory.covers), 500);
      expect(report.bytesOf(StorageCategory.videos), 9000);
      expect(report.bytesOf(StorageCategory.backgrounds), 50);
      expect(report.orphanFiles, 2);
      expect(report.orphanBytes, 500);
      expect(report.clearableOrphanBytes, 300);
      expect(report.cacheBytes, 800);
      expect(report.clearableCacheBytes, 700);
      expect(report.videoInfo['diary_videos/m2/clip.mp4']?.shortSide, 2160);
      expect(report.deviceSpace?.freeBytes, 40);
    });

    test('keeps files mentioned only in metadata as in use', () async {
      final path = await put('diary_images/m1/meta.jpg', 100);
      await database.createDiary(
        title: '',
        contentDocJson: docWith(const []),
        contentText: '',
        metadataJson: jsonEncode({'import': path}),
      );

      final report = await service().scan();

      expect(report.orphanFiles, 0);
      expect(report.media.single.isEditable, isFalse);
    });
  });

  group('deleteMedia', () {
    test('removes every reference and then the file', () async {
      final target = await put('diary_images/m1/big.jpg', 5000);
      final keep = await put('diary_images/m1/keep.jpg', 100);
      final first = await createDiary([target, keep]);
      final second = await createDiary([target], cover: target);
      await database.addDiaryComment(
        diaryId: first,
        content: '',
        images: [target],
      );
      await database.saveDiaryDraft(
        title: '草稿',
        contentText: '',
        payload: jsonEncode({
          'contentDocJson': docWith([target]),
          'cover': target,
        }),
      );
      final replaced = Completer<void>();
      final subscription = EditingSessionRegistry.instance.dataReplaced.listen(
        (_) => replaced.complete(),
      );
      addTearDown(subscription.cancel);

      final result = await service().deleteMedia({'diary_images/m1/big.jpg'});

      expect(result.deletedFiles, 1);
      expect(result.freedBytes, 5000);
      expect(result.skippedRows, 0);
      expect(File(target).existsSync(), isFalse);
      expect(File(keep).existsSync(), isTrue);
      expect(imagesOf(await diaryRow(first)), [keep]);
      final secondRow = await diaryRow(second);
      expect(imagesOf(secondRow), isEmpty);
      expect(secondRow.cover, isNull);
      expect(secondRow.contentText, contains('文字'));
      expect(await database.select(database.diaryComments).get(), isEmpty);
      final draft = await database.select(database.diaryDrafts).getSingle();
      expect(draft.payload, isNot(contains('big.jpg')));
      await replaced.future;
    });

    test('refuses while an editor holds a copy', () async {
      final target = await put('diary_images/m1/big.jpg', 5000);
      await createDiary([target]);
      final lease = EditingSessionRegistry.instance.beginEditing('test');
      addTearDown(lease.end);

      await expectLater(
        service().deleteMedia({'diary_images/m1/big.jpg'}),
        throwsA(isA<StorageBusyException>()),
      );
      expect(File(target).existsSync(), isTrue);
    });
  });

  group('compressMedia', () {
    Future<List<StorageMediaEntry>> entriesOf(StorageMediaService s) async =>
        (await s.scan()).media;

    test(
      'writes a new file, rewrites references and drops the original',
      () async {
        final source = await put('diary_images/m1/photo.jpg', 8000);
        final diary = await createDiary([source]);
        final notebook = await database.createNotebook(
          name: '本子',
          payload: NotebookPayload.defaults.copyWith(coverPath: source),
        );
        final s = service();

        final result = await s.compressMedia(
          await entriesOf(s),
          imagePreset: StorageImagePreset.balanced,
          videoPreset: StorageVideoPreset.p720,
        );

        expect(result.compressed, 1);
        expect(result.savedBytes, 6000);
        final output = p.join(root.path, 'diary_images', 'm1', 'photo_1.jpg');
        expect(File(source).existsSync(), isFalse);
        expect(File(output).lengthSync(), 2000);
        expect(imagesOf(await diaryRow(diary)), [output]);
        final row = await (database.select(
          database.notebooks,
        )..where((t) => t.notebookId.equals(notebook))).getSingle();
        expect(row.parsedPayload.coverPath, output);
      },
    );

    test('keeps the original when the output is not smaller', () async {
      final source = await put('diary_images/m1/small.jpg', 1000);
      await createDiary([source]);
      compressor = FakeMediaCompressor(outputBytes: 990);
      final s = service();

      final result = await s.compressMedia(
        await entriesOf(s),
        imagePreset: StorageImagePreset.balanced,
        videoPreset: StorageVideoPreset.p720,
      );

      expect(result.compressed, 0);
      expect(result.unchanged, 1);
      expect(File(source).existsSync(), isTrue);
      expect(
        Directory(p.dirname(source)).listSync().map((e) => p.basename(e.path)),
        ['small.jpg'],
      );
    });

    test('edits made while encoding are kept and get the new file', () async {
      final source = await put('diary_images/m1/photo.jpg', 8000);
      final diary = await createDiary([source]);
      final s = service();
      final entries = await entriesOf(s);
      compressor = FakeMediaCompressor(
        beforeEach: (_) => database.updateDiaryContent(
          diaryId: diary,
          contentDocJson: docWith([source], text: '刚改过'),
          contentText: '刚改过',
        ),
      );

      final result = await service().compressMedia(
        entries,
        imagePreset: StorageImagePreset.balanced,
        videoPreset: StorageVideoPreset.p720,
      );

      // 引用在提交时（串行队列里）重新读取，压缩期间的改动不会被覆盖。
      expect(result.compressed, 1);
      final row = await diaryRow(diary);
      expect(row.contentText, '刚改过');
      expect(imagesOf(row), [
        p.join(root.path, 'diary_images', 'm1', 'photo_1.jpg'),
      ]);
    });

    test(
      'cancelling stops before the next file but keeps finished work',
      () async {
        final a = await put('diary_images/m1/a.jpg', 8000);
        final b = await put('diary_images/m1/b.jpg', 4000);
        await createDiary([a, b]);
        final s = service();
        final entries = await entriesOf(s);
        final cancel = StorageCancelToken();
        compressor = FakeMediaCompressor(
          beforeEach: (_) async => cancel.cancel(),
        );

        final result = await service().compressMedia(
          entries,
          imagePreset: StorageImagePreset.balanced,
          videoPreset: StorageVideoPreset.p720,
          cancel: cancel,
        );

        expect(result.cancelled, isTrue);
        expect(result.compressed, 1);
        expect(File(a).existsSync(), isFalse);
        expect(File(b).existsSync(), isTrue);
      },
    );
  });

  test('cleanUp clears idle cache and old orphans only', () async {
    final oldOrphan = await put('diary_images/m1/old.jpg', 300);
    final newOrphan = await put('diary_images/m1/new.jpg', 200, modified: now);
    final oldCache = await put('diary_share/1/x.jpg', 700, base: temp);
    final newCache = await put(
      'diary_share/2/y.jpg',
      100,
      base: temp,
      modified: now,
    );

    final freed = await service().cleanUp();

    expect(freed, 1000);
    expect(File(oldOrphan).existsSync(), isFalse);
    expect(File(newOrphan).existsSync(), isTrue);
    expect(File(oldCache).existsSync(), isFalse);
    expect(File(newCache).existsSync(), isTrue);
  });
}

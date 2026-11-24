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
import 'package:node_diary/core/services/storage/managed_media_content_index.dart';
import 'package:node_diary/core/services/storage/storage_media_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fake_media_compressor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.now();
  final old = DateTime(2025, 1, 1);
  late Directory root;
  late Directory temp;
  late AppDatabase database;
  late SettingsService settings;

  Future<String> put(String relative, List<int> bytes) async {
    final file = File(p.joinAll([root.path, ...relative.split('/')]));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    await file.setLastModified(old);
    return file.path;
  }

  String docWith(List<String> images) => encodeDiaryBlocks({
    'document': {
      'type': 'page',
      'children': [
        {
          'type': 'paragraph',
          'data': {
            'delta': [
              {'insert': '文字'},
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
    compressor: FakeMediaCompressor(),
    dataRoot: () async => root,
    temporaryDirectory: () async => temp,
    fontsPath: () async => null,
    clock: () => now,
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('jotsy_duplicates_root_');
    temp = await Directory.systemTemp.createTemp('jotsy_duplicates_temp_');
    database = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsService.create();
    ManagedMediaContentIndex.debugReset();
  });

  tearDown(() async {
    EditingSessionRegistry.instance.debugReset();
    await database.close();
    await root.delete(recursive: true);
    await temp.delete(recursive: true);
  });

  const photo = [1, 2, 3, 4, 5, 6];

  test('finds identical files and ignores same-size different ones', () async {
    final a = await put('diary_images/m1/a.jpg', photo);
    final b = await put('diary_images/m2/b.jpg', photo);
    final other = await put('diary_images/m3/c.jpg', [6, 5, 4, 3, 2, 1]);
    await createDiary([a]);
    await createDiary([b, other]);
    final s = service();

    final duplicates = await s.findDuplicates(await s.scan());

    expect(duplicates.groups, hasLength(1));
    final group = duplicates.groups.single;
    expect(group.keeper.key, 'diary_images/m1/a.jpg');
    expect(group.copies.map((entry) => entry.key), ['diary_images/m2/b.jpg']);
    expect(duplicates.savedBytes, photo.length);
  });

  test('merging points every reference at the kept file', () async {
    final a = await put('diary_images/m1/a.jpg', photo);
    final b = await put('diary_images/m2/b.jpg', photo);
    final cover = await put('diary_covers/cover_1.jpg', photo);
    final first = await createDiary([a]);
    final second = await createDiary([b]);
    final third = await createDiary(const [], cover: cover);
    await database.addDiaryComment(diaryId: first, content: '', images: [b]);
    final notebook = await database.createNotebook(
      name: '本子',
      payload: NotebookPayload.defaults.copyWith(coverPath: cover),
    );
    // a 与 b 各被两处引用（a：正文与草稿正文；b：正文与留言），封面那份
    // 不能当保留（正文不能指向 diary_covers）；平手时取定位键小的 a。
    await database.saveDiaryDraft(
      title: '草稿',
      contentText: '',
      payload: jsonEncode({
        'contentDocJson': docWith([a]),
        'cover': cover,
      }),
    );
    final secondBefore = await diaryRow(second);
    final replaced = Completer<void>();
    final subscription = EditingSessionRegistry.instance.dataReplaced.listen(
      (_) => replaced.complete(),
    );
    addTearDown(subscription.cancel);
    final s = service();
    final duplicates = await s.findDuplicates(await s.scan());

    final result = await s.mergeDuplicates(duplicates.groups);

    expect(result.mergedFiles, 2);
    expect(result.freedBytes, photo.length * 2);
    expect(result.skippedRows, 0);
    expect(File(a).existsSync(), isTrue);
    expect(File(b).existsSync(), isFalse);
    expect(File(cover).existsSync(), isFalse);
    expect(imagesOf(await diaryRow(first)), [a]);
    final secondAfter = await diaryRow(second);
    expect(imagesOf(secondAfter), [a]);
    // 改写的行刷新修改时间，局域网同步才会把改动带到对端。
    expect(secondAfter.updatedAt.isAfter(secondBefore.updatedAt), isTrue);
    // 封面可以指向 diary_images（备份恢复重绑封面时两个目录都找）。
    expect((await diaryRow(third)).cover, a);
    final notebookRow = await (database.select(
      database.notebooks,
    )..where((t) => t.notebookId.equals(notebook))).getSingle();
    expect(notebookRow.parsedPayload.coverPath, a);
    final comment = await database.select(database.diaryComments).getSingle();
    expect(comment.images, contains('a.jpg'));
    final draft = await database.select(database.diaryDrafts).getSingle();
    expect(draft.payload, contains('a.jpg'));
    expect(draft.payload, isNot(contains('cover_1.jpg')));
    await replaced.future;

    expect((await s.findDuplicates(await s.scan())).isEmpty, isTrue);
  });

  test('a body image is never moved into the covers folder', () async {
    final cover = await put('diary_covers/cover_1.jpg', photo);
    final body = await put('diary_images/m1/a.jpg', photo);
    // 封面那份引用更多，但正文不能指向 diary_covers：保留正文那份。
    await createDiary(const [], cover: cover);
    await createDiary(const [], cover: cover);
    final diary = await createDiary([body]);
    final s = service();

    await s.mergeDuplicates((await s.findDuplicates(await s.scan())).groups);

    expect(File(body).existsSync(), isTrue);
    expect(File(cover).existsSync(), isFalse);
    expect(imagesOf(await diaryRow(diary)), [body]);
  });

  test('merging re-checks content and skips files that changed', () async {
    final a = await put('diary_images/m1/a.jpg', photo);
    final b = await put('diary_images/m2/b.jpg', photo);
    await createDiary([a]);
    final second = await createDiary([b]);
    final s = service();
    final duplicates = await s.findDuplicates(await s.scan());
    // 扫描之后换进了同名同大小的另一份文件（例如覆盖恢复）。
    await File(b).writeAsBytes([9, 9, 9, 9, 9, 9]);

    final result = await s.mergeDuplicates(duplicates.groups);

    expect(result.mergedFiles, 0);
    expect(File(a).existsSync(), isTrue);
    expect(File(b).existsSync(), isTrue);
    expect(imagesOf(await diaryRow(second)), [b]);
  });

  test('refuses while an editor holds a copy', () async {
    final a = await put('diary_images/m1/a.jpg', photo);
    final b = await put('diary_images/m2/b.jpg', photo);
    await createDiary([a]);
    await createDiary([b]);
    final s = service();
    final duplicates = await s.findDuplicates(await s.scan());
    final lease = EditingSessionRegistry.instance.beginEditing('test');
    addTearDown(lease.end);

    await expectLater(
      s.mergeDuplicates(duplicates.groups),
      throwsA(isA<StorageBusyException>()),
    );
    expect(File(b).existsSync(), isTrue);
  });
}

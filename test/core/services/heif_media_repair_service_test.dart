import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_media.dart';
import 'package:node_diary/core/services/editing_session_registry.dart';
import 'package:node_diary/core/services/heif_image_converter.dart';
import 'package:node_diary/core/services/heif_media_repair_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

const List<int> heicBytes = [
  0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70, // size, "ftyp"
  0x68, 0x65, 0x69, 0x63, 0, 0, 0, 0, // "heic", minor version
  0x6D, 0x69, 0x66, 0x31, 0x68, 0x65, 0x69, 0x63, // "mif1", "heic"
];
const List<int> jpegBytes = [0xFF, 0xD8, 0xFF, 0xE0, 0, 16];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 11, 3, 12);
  late Directory root;
  late AppDatabase database;
  late SettingsService settings;
  late List<String> transcoded;

  Future<String> put(String relative, List<int> bytes) async {
    final file = File(p.joinAll([root.path, ...relative.split('/')]));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    await file.setLastModified(DateTime(2025));
    return file.path;
  }

  String at(String relative) => p.joinAll([root.path, ...relative.split('/')]);

  Future<String> createDiary(List<String> images, {String? cover}) =>
      database.createDiary(
        title: '',
        contentText: '',
        metadataJson: '{}',
        contentDocJson: jsonEncode([
          for (final image in images) ...[
            {
              'insert': {'image': image},
            },
            {'insert': '\n'},
          ],
          {'insert': '文字\n'},
        ]),
        cover: cover,
      );

  Future<Diary> diaryRow(String diaryId) => (database.select(
    database.diaries,
  )..where((t) => t.diaryId.equals(diaryId))).getSingle();

  HeifMediaRepairService service() => HeifMediaRepairService(
    database: database,
    settings: () async => settings,
    dataRoot: () async => root,
    clock: () => now,
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('jotsy_heif_repair_test_');
    database = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsService.create();
    transcoded = <String>[];
    HeifImageConverter.debugTranscoder = (source, target) async {
      transcoded.add(source);
      await File(target).writeAsBytes(jpegBytes);
      return true;
    };
  });

  tearDown(() async {
    HeifImageConverter.debugTranscoder = null;
    EditingSessionRegistry.instance.debugReset();
    await database.close();
    await root.delete(recursive: true);
  });

  test('converts stored HEIC images and rewrites every reference', () async {
    final heic = await put('diary_images/media_a/IMG_1.HEIC', heicBytes);
    final jpeg = await put('diary_images/media_b/IMG_2.jpg', jpegBytes);
    final cover = await put('diary_covers/cover_1.heic', heicBytes);
    final notebookCover = await put('diary_covers/cover_2.heic', heicBytes);
    await put('app_backgrounds/bg_1.heic', heicBytes);
    // 托管目录之外的 HEIC 不碰。
    final outside = await put('elsewhere/x.heic', heicBytes);

    final id = await createDiary([heic, jpeg, outside], cover: cover);
    final untouchedId = await createDiary([jpeg]);
    final before = await diaryRow(id);
    final untouchedBefore = await diaryRow(untouchedId);

    final notebookId = await database.createNotebook(name: '旅行');
    final payload = jsonEncode({
      'cover': notebookCover,
      'coverStyle': {'layout': 'spine'},
      'future': {'kept': true},
    });
    await (database.update(database.notebooks)
          ..where((t) => t.notebookId.equals(notebookId)))
        .write(NotebooksCompanion(payload: Value(payload)));
    await settings.setAppSurfaceRaw(
      jsonEncode({
        'v': 1,
        'global': {'kind': 'image', 'image': 'bg_1.heic'},
        'areas': {
          'editor': {
            'mode': 'custom',
            'background': {'kind': 'image', 'image': 'bg_1.heic'},
          },
        },
      }),
    );

    final report = await service().repair();

    expect(report!.convertedFiles, 4);
    expect(report.updatedRows, 2);
    expect(report.updatedBackgrounds, isTrue);

    final after = await diaryRow(id);
    expect(extractDiaryImageSources(after.content).toList(), [
      at('diary_images/media_a/IMG_1.jpg'),
      jpeg,
      outside,
    ]);
    expect(after.cover, at('diary_covers/cover_1.jpg'));
    expect(after.contentText, before.contentText);
    expect(
      after.updatedAt,
      before.updatedAt.add(const Duration(seconds: 1)),
      reason: '推后 1 秒，让按 (id, updatedAt) 缓存的卡片刷新',
    );
    expect(await File(at('diary_images/media_a/IMG_1.jpg')).readAsBytes(), [
      ...jpegBytes,
    ]);

    // 没引用 HEIC 的日记原样不动。
    final untouchedAfter = await diaryRow(untouchedId);
    expect(untouchedAfter.content, untouchedBefore.content);
    expect(untouchedAfter.updatedAt, untouchedBefore.updatedAt);

    final notebook = await (database.select(
      database.notebooks,
    )..where((t) => t.notebookId.equals(notebookId))).getSingle();
    expect(jsonDecode(notebook.payload), {
      'cover': at('diary_covers/cover_2.jpg'),
      'coverStyle': {'layout': 'spine'},
      'future': {'kept': true},
    });

    final surface = jsonDecode(settings.appSurfaceRaw!) as Map;
    expect((surface['global'] as Map)['image'], 'bg_1.jpg');
    expect(
      (((surface['areas'] as Map)['editor'] as Map)['background']
          as Map)['image'],
      'bg_1.jpg',
    );

    // 原 HEIC 保留并刷新修改时间：开着的页面写回旧路径时文件还在，之后由
    // 媒体回收按宽限期删除。
    expect(await File(heic).exists(), isTrue);
    expect(await File(heic).lastModified(), now);
    expect(transcoded, isNot(contains(outside)));
  });

  test('a second run finds nothing left to convert', () async {
    final heic = await put('diary_images/media_a/IMG_1.heic', heicBytes);
    await createDiary([heic]);
    await service().repair();
    transcoded.clear();

    final report = await service().repair();
    expect(report!.convertedFiles, 0);
    expect(transcoded, isEmpty);
  });

  test('failed conversions leave the diary as it was', () async {
    HeifImageConverter.debugTranscoder = (source, target) async => false;
    final heic = await put('diary_images/media_a/IMG_1.heic', heicBytes);
    final id = await createDiary([heic]);
    final before = await diaryRow(id);

    final report = await service().repair();

    expect(report!.convertedFiles, 0);
    final after = await diaryRow(id);
    expect(after.content, before.content);
    expect(after.updatedAt, before.updatedAt);
  });

  test('waits for open editors before rewriting', () async {
    final heic = await put('diary_images/media_a/IMG_1.heic', heicBytes);
    final id = await createDiary([heic]);
    final before = await diaryRow(id);
    final lease = EditingSessionRegistry.instance.beginEditing('editor');

    var finished = false;
    final pending = service().repair().then((report) {
      finished = true;
      return report;
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(finished, isFalse);
    expect((await diaryRow(id)).content, before.content);

    lease.end();
    final report = await pending;
    expect(report!.updatedRows, 1);
    expect(
      extractDiaryImageSources((await diaryRow(id)).content).single,
      at('diary_images/media_a/IMG_1.jpg'),
    );
  });

  test('rows changed after they were read are skipped', () async {
    final id = await createDiary([]);
    final row = await diaryRow(id);
    final written = await database.applyMediaPathRepairs(
      diaryRepairs: [
        DiaryMediaPathRepair(
          id: row.id,
          expectedContent: '${row.content} ',
          expectedCover: row.cover,
          content: '[]',
          cover: null,
        ),
      ],
    );
    expect(written, 0);
    expect((await diaryRow(id)).content, row.content);
  });
}

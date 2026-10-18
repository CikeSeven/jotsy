import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> save(String name, {String? templateId, DateTime? at}) {
    return db.saveDiaryTemplate(
      templateId: templateId,
      name: name,
      payload: '{"name":"$name"}',
      now: at,
    );
  }

  Future<List<String>> names() async =>
      (await db.watchDiaryTemplates().first).map((row) => row.name).toList();

  group('templates', () {
    test('new templates are appended after the existing ones', () async {
      await save('甲');
      await save('乙');
      await save('丙');
      expect(await names(), ['甲', '乙', '丙']);
      expect((await db.getDiaryTemplates()).map((row) => row.sortOrder), [
        0,
        1,
        2,
      ]);
    });

    test(
      'saving with an id updates content but keeps order and createdAt',
      () async {
        final first = await save('原名', at: DateTime(2026, 10, 18, 9));
        await save('第二个', at: DateTime(2026, 10, 18, 9, 5));
        await save('改名', templateId: first, at: DateTime(2026, 10, 18, 10));

        final row = (await db.getDiaryTemplate(first))!;
        expect(row.name, '改名');
        expect(row.payload, '{"name":"改名"}');
        expect(row.sortOrder, 0);
        expect(row.createdAt, DateTime(2026, 10, 18, 9));
        expect(row.updatedAt, DateTime(2026, 10, 18, 10));
        expect(await names(), ['改名', '第二个']);
      },
    );

    test('saving an id that no longer exists inserts it at the end', () async {
      final gone = await save('被删的');
      await save('留下的');
      await db.deleteDiaryTemplates([gone]);

      expect(await save('编辑页还开着', templateId: gone), gone);
      expect(await names(), ['留下的', '编辑页还开着']);
    });

    test('reordering rewrites the manual order', () async {
      final a = await save('甲');
      final b = await save('乙');
      final c = await save('丙');
      await db.reorderDiaryTemplates([c, a, b]);
      expect(await names(), ['丙', '甲', '乙']);
    });

    test(
      'templates missing from a reorder keep their order at the end',
      () async {
        final a = await save('甲');
        final b = await save('乙');
        await save('丙');
        await save('丁');
        await db.reorderDiaryTemplates([b, a]);
        expect(await names(), ['乙', '甲', '丙', '丁']);
      },
    );

    test('restoring deleted templates puts the same rows back', () async {
      final a = await save('甲');
      await save('乙');
      final before = await db.getDiaryTemplates();

      await db.deleteDiaryTemplates([a]);
      expect(await db.countDiaryTemplates(), 1);

      await db.restoreDiaryTemplates(before.where((r) => r.templateId == a));
      expect(await db.getDiaryTemplates(), before);
    });
  });

  group('tags by name', () {
    test('only missing tags are created and existing colors stay', () async {
      final existing = await db.createTag(name: '工作', color: 0xFF112233);

      final result = await db.ensureTagsByName([
        (name: ' 工作 ', color: 0xFFFF0000),
        (name: '旅行', color: 0xFF00FF00),
        (name: '旅行', color: 0xFF0000FF),
        (name: '   ', color: 0xFF000000),
        (name: 'x' * 41, color: 0xFF000000),
      ]);

      expect(result.ids['工作'], existing);
      expect(result.ids.keys, unorderedEquals(['工作', '旅行']));
      expect(result.created, {result.ids['旅行']});
      final tags = await db.watchAllTags().first;
      expect(tags.firstWhere((t) => t.name == '工作').color, 0xFF112233);
      expect(tags.firstWhere((t) => t.name == '旅行').color, 0xFF00FF00);
    });

    test('unused tags are deleted and tags still on a diary stay', () async {
      final used = await db.createTag(name: '在用', color: 1);
      final unused = await db.createTag(name: '没用', color: 2);
      await db.createDiary(
        title: '日记',
        contentDocJson: '[{"insert":"正文\\n"}]',
        contentText: '正文',
        metadataJson: '{}',
        tagIds: [used],
      );

      await db.deleteTagsIfUnused({used, unused});

      final ids = (await db.watchAllTags().first).map((t) => t.id);
      expect(ids, [used]);
    });
  });

  group('schema v12 migration', () {
    Future<File> v11DatabaseFile({required bool keepTemplatesTable}) async {
      final root = await Directory.systemTemp.createTemp('jotsy_v12_tpl');
      addTearDown(() => root.delete(recursive: true));
      final file = File('${root.path}/v11.sqlite');
      final original = AppDatabase.forTesting(NativeDatabase(file));
      try {
        await original.createDiary(
          title: '升级前的日记',
          contentDocJson: '[{"insert":"正文\\n"}]',
          contentText: '正文',
          metadataJson: '{}',
        );
        await original.saveDiaryDraft(
          title: '升级前的草稿',
          contentText: '',
          payload: '{}',
        );
        if (keepTemplatesTable) {
          await original.saveDiaryTemplate(
            templateId: 'kept-template',
            name: '降级时留下的模板',
            payload: '{}',
          );
        }
      } finally {
        await original.close();
      }
      final legacy = sqlite3.open(file.path);
      if (!keepTemplatesTable) legacy.execute('DROP TABLE diary_templates');
      legacy.execute('PRAGMA user_version = 11');
      legacy.close();
      return file;
    }

    test(
      'v11 upgrade creates the table and keeps diaries and drafts',
      () async {
        final file = await v11DatabaseFile(keepTemplatesTable: false);
        for (var attempt = 0; attempt < 2; attempt++) {
          final migrated = AppDatabase.forTesting(NativeDatabase(file));
          try {
            expect(await migrated.countDiaryTemplates(), attempt);
            if (attempt == 0) {
              await migrated.saveDiaryTemplate(name: '升级后新建', payload: '{}');
            }
            final diaries = await migrated.select(migrated.diaries).get();
            expect(diaries.single.title, '升级前的日记');
            expect(await migrated.countDiaryDrafts(), 1);
          } finally {
            await migrated.close();
          }
        }
      },
    );

    test(
      'upgrading over a templates table a downgrade left keeps its rows',
      () async {
        final file = await v11DatabaseFile(keepTemplatesTable: true);
        final migrated = AppDatabase.forTesting(NativeDatabase(file));
        try {
          final row = (await migrated.getDiaryTemplate('kept-template'))!;
          expect(row.name, '降级时留下的模板');
          final version = await migrated
              .customSelect('PRAGMA user_version')
              .getSingle();
          expect(version.read<int>('user_version'), migrated.schemaVersion);
        } finally {
          await migrated.close();
        }
      },
    );
  });
}

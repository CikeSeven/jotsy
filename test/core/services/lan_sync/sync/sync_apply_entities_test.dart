import 'dart:convert';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/editing_session_registry.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';

import 'sync_apply_test_support.dart';
import 'sync_test_devices.dart';

/// 写入层按实体：插入 / 更新 / 删除的列值与关联清理、规范形式往返、层级与
/// 顺序列表重排（规格 §6、§4.6 写入层须知）。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SyncTestDevice a;
  late SyncTestDevice b;

  setUp(() async {
    EditingSessionRegistry.instance.debugReset();
    a = await SyncTestDevice.create('apply_a');
    b = await SyncTestDevice.create('apply_b');
    await seedEveryEntity(a);
  });

  tearDown(() async {
    await a.dispose();
    await b.dispose();
  });

  Future<List<String>> names(String sql) async => [
    for (final row in await a.db.customSelect(sql).get())
      row.data.values.first as String,
  ];

  test('每种实体写到空库后读回的规范记录逐字节相同（含旧格式正文、坏 JSON、媒体、胶囊）', () async {
    final records = await a.records();
    final rig = SyncApplyRig(b);
    final result = await rig.applier.apply(await rig.planFor(records));

    expect(result.skipped, isEmpty);
    expect(canonicalByKey(await b.records()), canonicalByKey(records));
    expect(
      result.manifest!.toJson(),
      SyncManifest.fromRecords(records).toJson(),
    );
    expect(result.diaries.added, 5);
    // content_text 由正文重新生成，不搬运 A 的陈旧镜像。
    final texts = await b.db
        .customSelect('SELECT content_text FROM diaries')
        .get();
    expect(
      texts.map((row) => row.data['content_text']),
      isNot(contains('stale text')),
    );
    // 媒体引用还原成 B 自己的数据根。
    final cover = await b.db
        .customSelect("SELECT cover FROM diaries WHERE diary_id = 'diary-rich'")
        .getSingle();
    expect(cover.data['cover'], b.media('diary_covers/cover.jpg'));
  });

  test('更新日记：按原值写列；已有标签不改色，缺的按中性色建出、再由标签记录定色', () async {
    final rig = SyncApplyRig(a);
    final records = await rig.records();
    final rich = records[const SyncKey(SyncEntity.diary, 'diary-rich')]!;
    final edited = withFacet(
      withFacet(
        withFacet(rich, SyncFacet.content, {'title': 'Rich 2'}),
        SyncFacet.pin,
        {'pinned': false},
      ),
      SyncFacet.tags,
      {
        'names': ['fresh', 'grey', 'travel'],
      },
    );
    final freshTag = SyncRecord(const SyncKey(SyncEntity.tag, 'fresh'), {
      SyncFacet.color: {'color': 0xFF112233},
    });
    final result = await rig.applier.apply(
      await rig.planFor([edited, freshTag]),
    );

    expect(result.skipped, isEmpty);
    final row = await a.db
        .customSelect(
          "SELECT title, is_pinned, updated_at FROM diaries "
          "WHERE diary_id = 'diary-rich'",
        )
        .getSingle();
    expect(row.data['title'], 'Rich 2');
    expect(row.data['is_pinned'], 0);
    expect(row.data['updated_at'], 1700000100, reason: '不刷新 updatedAt');
    final colors = {
      for (final tag in await a.db.select(a.db.tags).get()) tag.name: tag.color,
    };
    expect(colors['travel'], 0xFF2196F3);
    expect(colors['fresh'], 0xFF112233);
    expect(colors['grey'], 0xFF9E9E9E);
    expect(
      (await rig.records())[rich.key]!.facets[SyncFacet.tags],
      edited.facets[SyncFacet.tags],
    );
  });

  test('删除日记：标签关联、成员关系、留言一并删除，纪念日解除关联', () async {
    final rig = SyncApplyRig(a);
    final localId = (await (a.db.select(
      a.db.diaries,
    )..where((t) => t.diaryId.equals('diary-rich'))).getSingle()).id;
    await rig.applier.apply(
      await rig.planFor(
        const [],
        deletes: const [SyncKey(SyncEntity.diary, 'diary-rich')],
      ),
    );

    expect(
      await (a.db.select(
        a.db.diaryTags,
      )..where((t) => t.diaryId.equals(localId))).get(),
      isEmpty,
    );
    expect(
      await (a.db.select(
        a.db.diaryNotebooks,
      )..where((t) => t.diaryId.equals(localId))).get(),
      isEmpty,
    );
    expect(await names("SELECT comment_id FROM diary_comments"), ['comment-2']);
    final ann = await (a.db.select(
      a.db.anniversaries,
    )..where((t) => t.anniversaryId.equals('ann-1'))).getSingle();
    expect(ann.linkedDiaryId, isNull);
  });

  test('删除日记本：清掉成员关系，子本不提升（parentId 原样）', () async {
    final rig = SyncApplyRig(a);
    final parentLocal = (await (a.db.select(
      a.db.notebooks,
    )..where((t) => t.notebookId.equals('nb-parent'))).getSingle()).id;
    await rig.applier.apply(
      await rig.planFor(
        const [],
        deletes: const [SyncKey(SyncEntity.notebook, 'nb-parent')],
      ),
    );

    expect(
      await (a.db.select(
        a.db.diaryNotebooks,
      )..where((t) => t.notebookId.equals(parentLocal))).get(),
      isEmpty,
    );
    final child = await (a.db.select(
      a.db.notebooks,
    )..where((t) => t.notebookId.equals('nb-child'))).getSingle();
    expect(child.parentId, 'nb-parent');
  });

  test('删除标签清掉它的关联；删除模板不动日记本里指向它的默认模板', () async {
    await (a.db.update(
      a.db.notebooks,
    )..where((t) => t.notebookId.equals('nb-empty'))).write(
      const NotebooksCompanion(payload: Value('{"templateId":"tpl-1"}')),
    );
    final rig = SyncApplyRig(a);
    final workId = (await (a.db.select(
      a.db.tags,
    )..where((t) => t.name.equals('work'))).getSingle()).id;
    final result = await rig.applier.apply(
      await rig.planFor(
        const [],
        deletes: const [
          SyncKey(SyncEntity.tag, 'work'),
          SyncKey(SyncEntity.template, 'tpl-1'),
        ],
      ),
    );

    expect(result.skipped, isEmpty);
    expect(
      await (a.db.select(
        a.db.diaryTags,
      )..where((t) => t.tagId.equals(workId))).get(),
      isEmpty,
    );
    final notebook = await (a.db.select(
      a.db.notebooks,
    )..where((t) => t.notebookId.equals('nb-empty'))).getSingle();
    expect(jsonDecode(notebook.payload), {'templateId': 'tpl-1'});
  });

  test('parentId 按记录精确写入；智能本改成手动本先清掉残留关联行', () async {
    final rig = SyncApplyRig(a);
    final records = await rig.records();
    final child = withFacet(
      records[const SyncKey(SyncEntity.notebook, 'nb-child')]!,
      SyncFacet.definition,
      {'parentId': 'nb-empty'},
    );
    final smart = withFacet(
      records[const SyncKey(SyncEntity.notebook, 'nb-smart')]!,
      SyncFacet.definition,
      {'kind': 'manual'},
    );
    final result = await rig.applier.apply(await rig.planFor([child, smart]));

    expect(result.skipped, isEmpty);
    final rows = {
      for (final row in await a.db.select(a.db.notebooks).get())
        row.notebookId: row,
    };
    expect(rows['nb-child']!.parentId, 'nb-empty');
    expect(rows['nb-smart']!.kind, 'manual');
    expect(
      await (a.db.select(
        a.db.diaryNotebooks,
      )..where((t) => t.notebookId.equals(rows['nb-smart']!.id))).get(),
      isEmpty,
    );
    final manifest = result.manifest!;
    expect(
      manifest.containsKey(
        const SyncKey(SyncEntity.membership, 'nb-smart|diary-rich'),
      ),
      isFalse,
    );
    expect(
      manifest.containsKey(SyncKey(SyncEntity.orderList, 'book:nb-smart')),
      isTrue,
    );
  });

  test('顺序列表按列表重排为 0..n-1，列表里没有的现有项按原相对顺序接在后面', () async {
    final rig = SyncApplyRig(a);
    final result = await rig.applier.apply(
      await rig.planFor([
        SyncRecord(const SyncKey(SyncEntity.orderList, SyncOrderListId.shelf), {
          SyncFacet.items: {
            'ids': ['nb-empty', 'nb-parent'],
          },
        }),
        SyncRecord(
          SyncKey(SyncEntity.orderList, SyncOrderListId.book('nb-parent')),
          {
            SyncFacet.items: {
              'ids': ['diary-uri', 'diary-rich'],
            },
          },
        ),
        SyncRecord(
          const SyncKey(SyncEntity.orderList, SyncOrderListId.templates),
          {
            SyncFacet.items: {
              'ids': ['tpl-1'],
            },
          },
        ),
      ]),
    );

    expect(result.skipped, isEmpty);
    expect(
      await names('SELECT notebook_id FROM notebooks ORDER BY sort_order'),
      ['nb-empty', 'nb-parent', 'nb-child', 'nb-smart'],
    );
    final book = await a.db
        .customSelect(
          'SELECT d.diary_id AS id, dn.position AS pos FROM diary_notebooks dn '
          'JOIN diaries d ON d.id = dn.diary_id JOIN notebooks n '
          "ON n.id = dn.notebook_id WHERE n.notebook_id = 'nb-parent' "
          'ORDER BY dn.position',
        )
        .get();
    expect(
      [for (final row in book) '${row.data['id']}@${row.data['pos']}'],
      ['diary-uri@0', 'diary-rich@1', 'diary-delta@2'],
    );
    final templates = {
      for (final row in await a.db.select(a.db.diaryTemplates).get())
        row.templateId: row.sortOrder,
    };
    expect(templates, {'tpl-1': 0, 'tpl-2': 1, 'builtin.daily': 5});
  });

  test('新模板与模板顺序同一计划：顺序列表最后执行，新模板排在列表给的位置', () async {
    final rig = SyncApplyRig(a);
    final template = (await rig
        .records())[const SyncKey(SyncEntity.template, 'tpl-1')]!;
    final fresh = SyncRecord(
      const SyncKey(SyncEntity.template, 'tpl-new'),
      template.facets,
    );
    final result = await rig.applier.apply(
      await rig.planFor([
        fresh,
        SyncRecord(
          const SyncKey(SyncEntity.orderList, SyncOrderListId.templates),
          {
            SyncFacet.items: {
              'ids': ['tpl-new', 'tpl-2', 'tpl-1'],
            },
          },
        ),
      ]),
    );

    expect(result.skipped, isEmpty);
    expect(
      await names(
        "SELECT template_id FROM diary_templates "
        "WHERE template_id NOT LIKE 'builtin.%' ORDER BY sort_order",
      ),
      ['tpl-new', 'tpl-2', 'tpl-1'],
    );
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/editing_session_registry.dart';

import '../../../../support/lan_sync_two_devices.dart';

/// 两台设备端到端：真实的 SyncLocalState、规划器与写入层，按会话层的顺序
/// 跑完整轮同步（规格 §3–§6）。每轮之后两边的规范记录必须逐字节相同，紧接着
/// 再规划一次必须没有任何写入。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late LanSyncTestDevice a;
  late LanSyncTestDevice b;

  setUp(() async {
    EditingSessionRegistry.instance.debugReset();
    final clock = LanSyncTestClock();
    a = await LanSyncTestDevice.create('device-a', clock: clock);
    b = await LanSyncTestDevice.create('device-b', clock: clock);
    await _seedA(a);
    await _seedB(b);
  });

  tearDown(() async {
    await a.dispose();
    await b.dispose();
  });

  /// 跑一轮并断言收敛：两边规范记录相同、下一次规划为空。
  Future<LanSyncRound> converge(
    LanSyncTestDevice initiator,
    LanSyncTestDevice responder,
  ) async {
    final round = await runLanSyncRound(initiator, responder);
    expect(round.initiatorResult!.skipped, isEmpty);
    expect(round.responderResult!.skipped, isEmpty);
    expect(await a.canonical(), await b.canonical());
    expect((await planLanSyncRound(a, b)).isEmpty, isTrue);
    expect((await planLanSyncRound(b, a)).isEmpty, isTrue);
    return round;
  }

  Future<void> sql(LanSyncTestDevice device, String statement) =>
      device.db.customStatement(statement);

  Future<Diary?> diary(LanSyncTestDevice device, String id) =>
      (device.db.select(
        device.db.diaries,
      )..where((t) => t.diaryId.equals(id))).getSingleOrNull();

  test('第一次同步：两边的数据合在一起，媒体、层级、章节、成员都到位', () async {
    final round = await converge(a, b);
    expect(round.plan.conflictCopies, isEmpty);
    expect(round.responderResult!.mediaFiles, 2);
    expect(round.initiatorResult!.mediaFiles, 1);

    for (final device in [a, b]) {
      expect(
        await File(
          device.mediaPath('diary_images/media_a/p.jpg'),
        ).readAsBytes(),
        [1, 2, 3],
      );
      expect(
        await File(
          device.mediaPath('diary_videos/media_b/v.mp4'),
        ).readAsBytes(),
        [9, 9],
      );
    }
    final notebooks = {
      for (final row in await b.db.select(b.db.notebooks).get())
        row.notebookId: row,
    };
    expect(notebooks['nb-a2']!.parentId, 'nb-a');
    expect(notebooks.keys, containsAll(['nb-a', 'nb-a2', 'nb-b', 'nb-smart']));
    final member = await b.db
        .customSelect(
          'SELECT dn.chapter_id AS c FROM diary_notebooks dn JOIN diaries d '
          "ON d.id = dn.diary_id JOIN notebooks n ON n.id = dn.notebook_id "
          "WHERE d.diary_id = 'a1' AND n.notebook_id = 'nb-a'",
        )
        .getSingle();
    expect(member.data['c'], 'ch1');
    expect((await diary(b, 'a1'))!.cover, b.mediaPath('diary_covers/a.jpg'));
    final comments = await b.db.select(b.db.diaryComments).get();
    expect(comments.map((c) => c.commentId), unorderedEquals(['c-a', 'c-b']));
  });

  test('两边改了不同的分面：再同步一轮就收敛', () async {
    await converge(a, b);
    await sql(a, "UPDATE diaries SET is_pinned = 1 WHERE diary_id = 'b1'");
    await sql(
      b,
      "UPDATE diaries SET title = 'A1 by B', updated_at = 1800000000 "
      "WHERE diary_id = 'a1'",
    );
    await converge(b, a);

    expect((await diary(a, 'a1'))!.title, 'A1 by B');
    expect((await diary(b, 'b1'))!.isPinned, isTrue);
  });

  test('同一篇两边都改了正文：恰好一份冲突副本，两边一致', () async {
    await converge(a, b);
    await sql(
      a,
      "UPDATE diaries SET title = 'from A', updated_at = 1800000000 "
      "WHERE diary_id = 'b2'",
    );
    await sql(
      b,
      "UPDATE diaries SET title = 'from B', updated_at = 1800000500 "
      "WHERE diary_id = 'b2'",
    );
    final round = await converge(a, b);

    expect(round.plan.conflictCopies, hasLength(1));
    final copy = round.plan.conflictCopies.single;
    expect(copy.originalId, 'b2');
    for (final device in [a, b]) {
      expect((await diary(device, 'b2'))!.title, 'from B');
      expect((await diary(device, copy.copyId))!.title, startsWith('from A'));
    }
    final diaries = await a.db.select(a.db.diaries).get();
    expect(diaries.where((d) => d.title.startsWith('from A')), hasLength(1));
  });

  test('一边彻底删除（清空回收站）：删除传播到另一边，连同关联', () async {
    await converge(a, b);
    await b.db.hardDeleteDiary('a1');
    final round = await converge(b, a);

    expect(round.plan.remote.diaryDeletions, 1);
    expect(await diary(a, 'a1'), isNull);
    expect(
      (await a.db.select(a.db.diaryComments).get()).map((c) => c.commentId),
      ['c-b'],
    );
    final anniversary = await (a.db.select(
      a.db.anniversaries,
    )..where((t) => t.anniversaryId.equals('ann-a'))).getSingle();
    expect(anniversary.linkedDiaryId, isNull);
  });

  test('中断的一轮（只有一边写了）：下一轮照常收敛', () async {
    await converge(a, b);
    await sql(a, "UPDATE diaries SET is_pinned = 1 WHERE diary_id = 'a3'");
    await sql(b, "UPDATE diaries SET is_archived = 1 WHERE diary_id = 'b2'");
    await sql(b, "UPDATE tags SET color = 7 WHERE name = 'home'");
    final interrupted = await runLanSyncRound(a, b, applyInitiator: false);
    expect(interrupted.responderResult!.diaries.updated, 1);
    expect(interrupted.initiatorResult, isNull);

    await converge(a, b);
    expect((await diary(a, 'b2'))!.isArchived, isTrue);
    expect((await diary(b, 'a3'))!.isPinned, isTrue);
    final home = await (a.db.select(
      a.db.tags,
    )..where((t) => t.name.equals('home'))).getSingle();
    expect(home.color, 7);
  });

  test('删除日记本、把子本挪到别处：对方按计划精确写 parentId', () async {
    await converge(a, b);
    await a.db.deleteNotebook('nb-a');
    await a.db.moveNotebook('nb-a2', 'nb-b');
    final round = await converge(a, b);
    expect(round.plan.local.isEmpty, isTrue);
    final rows = {
      for (final row in await b.db.select(b.db.notebooks).get())
        row.notebookId: row,
    };
    expect(rows.containsKey('nb-a'), isFalse);
    expect(rows['nb-a2']!.parentId, 'nb-b');
  });
}

DateTime _at(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000);

String _doc(List<Map<String, Object?>> children) => jsonEncode({
  'document': {'type': 'page', 'children': children},
});

Map<String, Object?> _text(String text) => {
  'type': 'paragraph',
  'data': {
    'delta': [
      {'insert': text},
    ],
  },
};

Future<int> _diary(
  AppDatabase db,
  String id, {
  required String content,
  String title = '',
  String? cover,
  int updated = 1700000100,
  bool archived = false,
  bool deleted = false,
}) => db
    .into(db.diaries)
    .insert(
      DiariesCompanion.insert(
        diaryId: id,
        title: Value(title),
        content: content,
        contentText: '',
        cover: Value(cover),
        createdAt: _at(1700000000),
        updatedAt: _at(updated),
        isArchived: Value(archived),
        archivedAt: Value(archived ? _at(1700000200) : null),
        isDeleted: Value(deleted),
        deletedAt: Value(deleted ? _at(1700000300) : null),
      ),
    );

Future<int> _tag(AppDatabase db, String name, int color) =>
    db.into(db.tags).insert(TagsCompanion.insert(name: name, color: color));

Future<void> _link(AppDatabase db, int diary, int tag) => db
    .into(db.diaryTags)
    .insert(DiaryTagsCompanion.insert(diaryId: diary, tagId: tag));

Future<int> _notebook(
  AppDatabase db,
  String id, {
  String kind = 'manual',
  String payload = '{}',
  int sortOrder = 0,
  String? parentId,
}) => db
    .into(db.notebooks)
    .insert(
      NotebooksCompanion.insert(
        notebookId: id,
        name: id,
        kind: Value(kind),
        payload: Value(payload),
        sortOrder: Value(sortOrder),
        parentId: Value(parentId),
        createdAt: _at(1700000000),
        updatedAt: _at(1700000000),
      ),
    );

Future<void> _member(
  AppDatabase db,
  int diary,
  int notebook, {
  String? chapter,
  int position = 0,
}) => db
    .into(db.diaryNotebooks)
    .insert(
      DiaryNotebooksCompanion.insert(
        diaryId: diary,
        notebookId: notebook,
        chapterId: Value(chapter),
        position: Value(position),
        addedAt: _at(1700000500),
      ),
    );

Future<void> _seedA(LanSyncTestDevice device) async {
  final db = device.db;
  final image = await device.writeMedia('diary_images/media_a/p.jpg', [
    1,
    2,
    3,
  ]);
  final cover = await device.writeMedia('diary_covers/a.jpg', [4]);
  final travel = await _tag(db, 'travel', 0xFF2196F3);
  final work = await _tag(db, 'work', 0xFFFF9800);
  final a1 = await _diary(
    db,
    'a1',
    title: 'A1',
    cover: cover,
    content: _doc([
      _text('hello from a'),
      {
        'type': 'image',
        'data': {'url': image},
      },
    ]),
  );
  await _diary(db, 'a2', title: 'A2', content: 'trashed', deleted: true);
  final a3 = await _diary(
    db,
    'a3',
    title: 'A3',
    content: 'old',
    archived: true,
  );
  await _link(db, a1, travel);
  await _link(db, a1, work);
  final nbA = await _notebook(
    db,
    'nb-a',
    payload: jsonEncode({
      'chapters': [
        {'id': 'ch1', 'title': 'One'},
      ],
    }),
  );
  final nbA2 = await _notebook(db, 'nb-a2', sortOrder: 1, parentId: 'nb-a');
  await _member(db, a1, nbA, chapter: 'ch1');
  await _member(db, a3, nbA, position: 1);
  await _member(db, a1, nbA2);
  await db
      .into(db.diaryComments)
      .insert(
        DiaryCommentsCompanion.insert(
          commentId: 'c-a',
          diaryId: 'a1',
          content: 'reread',
          createdAt: _at(1700001000),
        ),
      );
  await _template(db, 'tpl-a', 0);
  await db
      .into(db.anniversaries)
      .insert(
        AnniversariesCompanion.insert(
          anniversaryId: 'ann-a',
          title: 'Trip',
          baseDate: '2020-01-01',
          linkedDiaryId: const Value('a1'),
          createdAt: _at(1700000000),
          updatedAt: _at(1700000000),
        ),
      );
  await db
      .into(db.dayMoods)
      .insert(
        DayMoodsCompanion.insert(
          day: '2026-01-01',
          mood: 'good',
          updatedAt: _at(1700000000),
        ),
      );
}

Future<void> _seedB(LanSyncTestDevice device) async {
  final db = device.db;
  final video = await device.writeMedia('diary_videos/media_b/v.mp4', [9, 9]);
  final travel = await _tag(db, 'travel', 0xFF000000);
  final home = await _tag(db, 'home', 0xFF4CAF50);
  final b1 = await _diary(
    db,
    'b1',
    title: 'B1',
    content: _doc([
      {
        'type': 'video',
        'data': {'url': video},
      },
    ]),
  );
  final b2 = await _diary(db, 'b2', title: 'B2', content: 'plain b2');
  await _link(db, b1, home);
  await _link(db, b1, travel);
  await _link(db, b2, home);
  final nbB = await _notebook(db, 'nb-b');
  await _notebook(
    db,
    'nb-smart',
    kind: 'smart',
    sortOrder: 1,
    payload: jsonEncode({
      'rules': {
        'match': 'all',
        'items': [
          {'type': 'tag', 'name': 'home'},
        ],
      },
    }),
  );
  await _member(db, b1, nbB);
  await db
      .into(db.diaryComments)
      .insert(
        DiaryCommentsCompanion.insert(
          commentId: 'c-b',
          diaryId: 'b2',
          content: 'note',
          mood: const Value('🙂'),
          createdAt: _at(1700002000),
        ),
      );
  await _template(db, 'tpl-b', 0);
  await db
      .into(db.anniversaries)
      .insert(
        AnniversariesCompanion.insert(
          anniversaryId: 'ann-b',
          title: 'Home',
          baseDate: '2021-02-02',
          createdAt: _at(1700000000),
          updatedAt: _at(1700000000),
        ),
      );
  for (final (day, mood, updated) in [
    ('2026-01-01', 'bad', 1700000900),
    ('2026-01-02', 'calm', 1700000000),
  ]) {
    await db
        .into(db.dayMoods)
        .insert(
          DayMoodsCompanion.insert(
            day: day,
            mood: mood,
            updatedAt: _at(updated),
          ),
        );
  }
}

Future<void> _template(AppDatabase db, String id, int sortOrder) => db
    .into(db.diaryTemplates)
    .insert(
      DiaryTemplatesCompanion.insert(
        templateId: id,
        name: Value(id),
        payload: jsonEncode({'name': id, 'body': []}),
        sortOrder: Value(sortOrder),
        createdAt: _at(1700003000),
        updatedAt: _at(1700003000),
      ),
    );

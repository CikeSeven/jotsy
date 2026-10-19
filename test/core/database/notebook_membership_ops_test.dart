import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/notebooks/controllers/notebook_membership_ops.dart';
import 'package:node_diary/ui/notebooks/models/notebook_pick_selection.dart';

/// 收录的批量读写与撤销（首页多选、预览页“收进日记本”共用），以及新建
/// 日记时按章节收进日记本。
void main() {
  late AppDatabase db;
  late NotebookMembershipOps ops;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ops = NotebookMembershipOps(db);
  });
  tearDown(() => db.close());

  Future<String> diary(String title, {List<String>? notebookIds}) {
    return db.createDiary(
      title: title,
      contentDocJson: '[{"insert":"正文\\n"}]',
      contentText: '正文',
      metadataJson: '{}',
      notebookIds: notebookIds,
    );
  }

  Future<String> notebook(String name, {NotebookPayload? payload}) {
    return db.createNotebook(
      name: name,
      kind: NotebookKind.manual,
      payload: payload ?? NotebookPayload.defaults,
    );
  }

  /// 本子里的成员：按成书位置排好的 (日记标题, 章节 id)。
  Future<List<(String, String?)>> entries(String notebookId) async {
    final book = (await db.getNotebook(notebookId))!;
    final query =
        db.select(db.diaryNotebooks).join(<Join>[
            innerJoin(
              db.diaries,
              db.diaries.id.equalsExp(db.diaryNotebooks.diaryId),
            ),
          ])
          ..where(db.diaryNotebooks.notebookId.equals(book.id))
          ..orderBy(<OrderingTerm>[
            OrderingTerm.asc(db.diaryNotebooks.position),
          ]);
    return <(String, String?)>[
      for (final row in await query.get())
        (
          row.readTable(db.diaries).title,
          row.readTable(db.diaryNotebooks).chapterId,
        ),
    ];
  }

  final chapters = NotebookPayload(
    chapters: <NotebookChapter>[NotebookChapter(id: 'c1', title: '第一章')],
  );

  test('apply adds and removes in one go and undo restores chapters', () async {
    final travel = await notebook('旅行', payload: chapters);
    final food = await notebook('美食');
    final a = await diary('A', notebookIds: <String>[travel]);
    final b = await diary('B');
    await db.setNotebookEntriesChapter(travel, <String>[a], 'c1');

    final undo = await ops.apply(
      NotebookPickerResult(add: <String>{food}, remove: <String>{travel}),
      <String>[a, b],
    );
    expect(await entries(travel), isEmpty);
    expect(await entries(food), <(String, String?)>[('A', null), ('B', null)]);

    await ops.undo(undo);
    expect(await entries(travel), <(String, String?)>[('A', 'c1')]);
    expect(await entries(food), isEmpty);
  });

  test(
    'undoing an add keeps diaries that were already in the notebook',
    () async {
      final travel = await notebook('旅行');
      final a = await diary('A', notebookIds: <String>[travel]);
      final b = await diary('B');

      final undo = await ops.apply(
        NotebookPickerResult(add: <String>{travel}),
        <String>[a, b],
      );
      expect(undo.added[travel], <String>[b]);
      expect(await entries(travel), <(String, String?)>[
        ('A', null),
        ('B', null),
      ]);

      await ops.undo(undo);
      expect(await entries(travel), <(String, String?)>[('A', null)]);
    },
  );

  test('move transfers diaries and undo moves them back', () async {
    final travel = await notebook('旅行', payload: chapters);
    final food = await notebook('美食');
    final a = await diary('A', notebookIds: <String>[travel]);
    final b = await diary('B', notebookIds: <String>[travel, food]);
    await db.setNotebookEntriesChapter(travel, <String>[a], 'c1');

    final undo = await ops.move(
      fromId: travel,
      toId: food,
      diaryIds: <String>[a, b],
    );
    expect(await entries(travel), isEmpty);
    expect(await entries(food), <(String, String?)>[('B', null), ('A', null)]);

    await ops.undo(undo);
    expect(await entries(travel), <(String, String?)>[
      ('A', 'c1'),
      ('B', null),
    ]);
    // B 本来就在美食里：撤销不把它移出。
    expect(await entries(food), <(String, String?)>[('B', null)]);
  });

  test('remove and undo round-trip', () async {
    final travel = await notebook('旅行');
    final a = await diary('A', notebookIds: <String>[travel]);
    final undo = await ops.remove(travel, <String>[a]);
    expect(await entries(travel), isEmpty);
    await ops.undo(undo);
    expect(await entries(travel), <(String, String?)>[('A', null)]);
  });

  test('createDiary files a new diary into the given chapter', () async {
    final travel = await notebook('旅行', payload: chapters);
    final food = await notebook('美食');
    await db.createDiary(
      title: '新的一篇',
      contentDocJson: '[{"insert":"正文\\n"}]',
      contentText: '正文',
      metadataJson: '{}',
      notebookIds: <String>[travel, food],
      notebookChapterIds: <String, String>{travel: 'c1', food: 'c1'},
    );
    expect(await entries(travel), <(String, String?)>[('新的一篇', 'c1')]);
    // 章节只对它所在的本子有效：美食没有 c1，落到“未分章”。
    expect(await entries(food), <(String, String?)>[('新的一篇', null)]);
  });

  test(
    'updateDiary with the same notebooks keeps chapter and position',
    () async {
      final travel = await notebook('旅行', payload: chapters);
      final food = await notebook('美食');
      await diary('先来的', notebookIds: <String>[travel]);
      final a = await diary('A', notebookIds: <String>[travel]);
      await db.setNotebookEntriesChapter(travel, <String>[a], 'c1');
      await db.updateDiary(
        diaryId: a,
        title: 'A 改',
        contentDocJson: '[{"insert":"正文\\n"}]',
        contentText: '正文',
        metadataJson: '{}',
        notebookIds: <String>[travel, food],
      );
      expect(await entries(travel), <(String, String?)>[
        ('先来的', null),
        ('A 改', 'c1'),
      ]);
      expect(await entries(food), <(String, String?)>[('A 改', null)]);
    },
  );
}

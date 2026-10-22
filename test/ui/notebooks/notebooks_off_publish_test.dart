import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/controllers/publish_diary_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';

/// 日记本功能关闭后发布：草稿里留下的日记本（可能是私密本）不写成员关系，
/// 新日记出现在全部日记里；草稿本身原样保留。
void main() {
  late AppDatabase database;
  late String hidden;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    hidden = await database.createNotebook(
      name: '私密',
      kind: NotebookKind.manual,
      visibility: NotebookVisibility.hidden,
      payload: NotebookPayload(
        chapters: <NotebookChapter>[NotebookChapter(id: 'c1', title: '一')],
      ),
    );
  });
  tearDown(() => database.close());

  Future<(PublishDiaryController, DiaryMetaDraftController)> publisher({
    required bool notebooks,
  }) async {
    final meta = DiaryMetaDraftController(
      DiaryMetaDraft(notebookIds: <String>{hidden}),
    );
    addTearDown(meta.dispose);
    final controller = PublishDiaryController(
      initialDraft: NewDiaryDraft(
        title: '在本子里开的头',
        contentDocJson: '[{"insert":"正文\\n"}]',
        contentText: '正文',
        notebookIds: <String>[hidden],
        notebookChapterIds: <String, String>{hidden: 'c1'},
      ),
      meta: meta,
      notebooksEnabled: () => notebooks,
    );
    addTearDown(controller.dispose);
    return (controller, meta);
  }

  test('notebooks off: a draft holding notebook ids publishes with no '
      'membership and shows in all diaries', () async {
    final (controller, meta) = await publisher(notebooks: false);
    final id = await controller.submit(database);

    expect(await database.getDiaryNotebookIds(id), isEmpty);
    expect(await database.getActiveDiaryIds(), <String>[id]);
    expect(meta.value.notebookIds, <String>{hidden}, reason: '面板草稿不改');

    // 发表后的自动保存同样不写成员关系。
    meta.setMood('🙂');
    expect(await controller.flush(), isTrue);
    expect(await database.getDiaryNotebookIds(id), isEmpty);
  });

  test(
    'notebooks on: the same draft files the diary into the notebook',
    () async {
      final (controller, _) = await publisher(notebooks: true);
      final id = await controller.submit(database);

      expect(await database.getDiaryNotebookIds(id), <String>{hidden});
      expect(
        await database.getActiveDiaryIds(),
        isEmpty,
        reason: '私密本里的日记不出现在全部日记',
      );
    },
  );

  test('notebooks on: a notebook picked after publishing keeps the chapter '
      'the diary was started in', () async {
    final (controller, meta) = await publisher(notebooks: true);
    final id = await controller.submit(database);
    Future<String?> chapterOf() async => (await database.getNotebookContents(
      hidden,
    )).singleWhere((entry) => entry.diaryId == id).chapterId;
    expect(await chapterOf(), 'c1');

    // 取消再选回：仍落回在本子里新建时的章节。
    meta.setNotebookSelected(hidden, false);
    expect(await controller.flush(), isTrue);
    expect(await database.getDiaryNotebookIds(id), isEmpty);
    meta.setNotebookSelected(hidden, true);
    expect(await controller.flush(), isTrue);
    expect(await chapterOf(), 'c1');
  });
}

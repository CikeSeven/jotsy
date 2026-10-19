import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/controllers/diary_create_entry_flow.dart';
import 'package:node_diary/ui/diaries/controllers/publish_diary_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';
import 'package:node_diary/ui/home/pages/home_page.dart';

import '../../support/diary_drafts_harness.dart';
import 'notebook_test_support.dart';

/// 在日记本里写日记：新建空白时预先收进这本（带章节）并套用这本的默认
/// 模板；续写已有草稿原样打开；发布时同一事务收进并落到章节。
void main() {
  Future<void> pumpOpener(
    DiaryDraftsHarness h, {
    required String notebookId,
    String? chapterId,
  }) {
    return h.pump(
      Consumer(
        builder: (context, ref, _) => Scaffold(
          body: TextButton(
            onPressed: () => runDiaryCreateEntryFlow(
              context,
              ref,
              notebookId: notebookId,
              chapterId: chapterId,
            ),
            child: const Text('New'),
          ),
        ),
      ),
    );
  }

  Future<void> tapNew(DiaryDraftsHarness h) async {
    await h.tester.tap(find.text('New'));
    await h.settleAll();
  }

  EditDiaryPage editor(WidgetTester tester) =>
      tester.widget<EditDiaryPage>(find.byType(EditDiaryPage));

  testWidgets('a blank entry pre-fills the notebook, chapter and template', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final travel = await h.notebook(
      '旅行',
      payload: NotebookPayload(
        templateId: 'builtin.gratitude',
        chapters: <NotebookChapter>[NotebookChapter(id: 'c1', title: '一')],
      ),
    );
    await pumpOpener(h, notebookId: travel, chapterId: 'c1');
    await tapNew(h);

    final page = editor(tester);
    expect(page.createNotebookId, travel);
    expect(page.createNotebookChapterId, 'c1');
    expect(page.createTemplate?.template.id, 'builtin.gratitude');
    await h.unmount();
  });

  testWidgets('continuing an existing draft keeps its own notebooks', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final travel = await h.notebook('旅行');
    final draft = await h.seed('写了一半', updatedAt: DateTime(2026, 10, 1));
    await pumpOpener(h, notebookId: travel);
    await tapNew(h);
    await tester.tap(find.text('写了一半'));
    await h.settleAll();

    final page = editor(tester);
    expect(page.createDraftId, draft);
    expect(page.createNotebookId, isNull);
    expect(page.createTemplate, isNull);
    await h.unmount();
  });

  test('publishing files the diary into the notebooks and chapter', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final travel = await database.createNotebook(
      name: '旅行',
      kind: NotebookKind.manual,
      payload: NotebookPayload(
        chapters: <NotebookChapter>[NotebookChapter(id: 'c1', title: '一')],
      ),
    );
    final food = await database.createNotebook(
      name: '美食',
      kind: NotebookKind.manual,
      payload: NotebookPayload.defaults,
    );
    final meta = DiaryMetaDraftController(
      DiaryMetaDraft(notebookIds: <String>{travel, food}),
    );
    addTearDown(meta.dispose);
    final controller = PublishDiaryController(
      initialDraft: NewDiaryDraft(
        title: '在京都',
        contentDocJson: '[{"insert":"正文\\n"}]',
        contentText: '正文',
        notebookChapterIds: <String, String>{travel: 'c1'},
      ),
      meta: meta,
    );
    addTearDown(controller.dispose);
    final id = await controller.submit(database);

    expect(await database.getDiaryNotebookIds(id), <String>{travel, food});
    final scoped = await database.getActiveDiaryIds(
      scope: DiaryNotebookScope(notebookId: travel, chapterId: 'c1'),
    );
    expect(scoped, <String>[id]);
  });

  test('the FAB shortens long notebook names', () {
    expect(shortNotebookName('旅行'), '旅行');
    expect(shortNotebookName('一二三四五六'), '一二三四五六');
    expect(shortNotebookName('一二三四五六七八'), '一二三四五六…');
  });
}

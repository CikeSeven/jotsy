import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';

import '../../support/diary_drafts_harness.dart';
import '../../support/publish_panel_driver.dart';
import 'notebook_test_support.dart';

/// 编辑已发布日记：面板读回所在日记本；没改日记本时自动保存不动收录（别处
/// 同时做的改动不被覆盖）；改了才写回，仍在的本子保留章节。
void main() {
  late String travel;
  late String food;
  late String work;
  late String diary;

  Future<DiaryDraftsHarness> open(WidgetTester tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    travel = await h.notebook(
      '旅行',
      payload: NotebookPayload(
        chapters: <NotebookChapter>[NotebookChapter(id: 'c1', title: '一')],
      ),
    );
    food = await h.notebook('美食');
    work = await h.notebook('工作');
    diary = await h.diary('在京都', notebookIds: <String>[travel]);
    await tester.runAsync(
      () => h.database.setNotebookEntriesChapter(travel, <String>[diary], 'c1'),
    );
    await h.pump(EditDiaryPage(diaryId: diary));
    await h.settleAll();
    return h;
  }

  Future<Set<String>> notebooksOf(DiaryDraftsHarness h) async =>
      (await h.tester.runAsync(() => h.database.getDiaryNotebookIds(diary)))!;

  Future<String?> travelChapter(DiaryDraftsHarness h) async {
    final ids = (await h.tester.runAsync(
      () => h.database.getActiveDiaryIds(
        scope: DiaryNotebookScope(notebookId: travel, chapterId: 'c1'),
      ),
    ))!;
    return ids.contains(diary) ? 'c1' : null;
  }

  Future<void> autosave(DiaryDraftsHarness h) async {
    await h.tester.pump(const Duration(milliseconds: 600));
    await h.settleAll();
  }

  testWidgets('editing text leaves notebook memberships alone', (tester) async {
    final h = await open(tester);
    final driver = PublishPanelDriver(tester);
    expect(driver.draft.value.notebookIds, <String>{travel});

    // 编辑期间别处把它收进了美食。
    await tester.runAsync(
      () => h.database.addDiariesToNotebook(food, <String>[diary]),
    );
    await tester.enterText(find.widgetWithText(TextField, '在京都'), '在大阪');
    await autosave(h);

    expect(await notebooksOf(h), <String>{travel, food});
    expect(await travelChapter(h), 'c1');
    await h.unmount();
  });

  testWidgets('changing notebooks in the panel saves them and keeps chapters', (
    tester,
  ) async {
    final h = await open(tester);
    final driver = PublishPanelDriver(tester);
    driver.draft.setNotebookSelected(work, true);
    await autosave(h);

    expect(await notebooksOf(h), <String>{travel, work});
    expect(await travelChapter(h), 'c1');

    driver.draft.setNotebookSelected(travel, false);
    await autosave(h);
    expect(await notebooksOf(h), <String>{work});
    await h.unmount();
  });
}

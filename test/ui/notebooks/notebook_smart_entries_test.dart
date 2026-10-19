import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/diaries/pages/diary_search_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/notebooks/pages/notebook_editor_page.dart';
import 'package:node_diary/ui/notebooks/pages/notebooks_page.dart';
import 'package:node_diary/ui/notebooks/sections/notebook_shelf_sheet.dart';

import '../../support/diary_drafts_harness.dart';
import 'notebook_test_support.dart';

/// 智能日记本在别处的入口：书架与管理页的篇数、转为普通日记本、搜索页
/// “存为智能日记本”。
void main() {
  NotebookPayload pinnedRule() => NotebookPayload(
    rules: NotebookRuleSet(
      rules: const <NotebookRule>[NotebookFlagRule(NotebookFlagKind.pinned)],
    ).encode(),
  );

  Future<String> pinnedDiary(DiaryDraftsHarness h, String title) async {
    final id = await h.diary(title);
    await h.tester.runAsync(() => h.database.pinDiary(id));
    return id;
  }

  testWidgets('the shelf and the management page show smart counts', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.notebook('置顶的', kind: NotebookKind.smart, payload: pinnedRule());
    await pinnedDiary(h, '一');
    await pinnedDiary(h, '二');
    await h.diary('三');
    await h.pump(
      Scaffold(
        body: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => showNotebookShelfSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await h.settleAll();
    await tester.scrollUntilVisible(
      find.text('置顶的'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('2 篇'), findsOneWidget);
    await h.unmount();

    await h.pump(const NotebooksPage());
    await h.settleAll();
    expect(find.text('2 篇 · 智能'), findsOneWidget);

    // 规则命中的日记变化时篇数跟着变。
    await pinnedDiary(h, '四');
    await h.settleAll();
    expect(find.text('3 篇 · 智能'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('converting a smart notebook files the current matches', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final smart = await h.notebook(
      '置顶的',
      kind: NotebookKind.smart,
      payload: pinnedRule(),
    );
    final first = await pinnedDiary(h, '一');
    final second = await pinnedDiary(h, '二');
    final archived = await pinnedDiary(h, '归档的');
    await tester.runAsync(() => h.database.archiveDiary(archived));
    await h.diary('没置顶');
    await h.pump(const NotebooksPage());
    await h.settleAll();

    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey<String>('notebook_row_$smart')),
        matching: find.byTooltip('更多操作'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '转为普通日记本'));
    await h.settleAll();
    expect(find.text('把「置顶的」转为普通日记本？'), findsOneWidget);
    expect(find.text('现在符合条件的 2 篇日记会收进来（不含归档的），以后不再按条件自动更新。'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '转换'));
    await h.settleAll();

    final row = (await h.notebookRow(smart))!;
    expect(row.notebookKind, NotebookKind.manual);
    expect(row.parsedPayload.rules, isNull);
    final members = (await tester.runAsync(
      () => h.database.getActiveDiaryIds(
        scope: DiaryNotebookScope(notebookId: smart, bookOrder: true),
      ),
    ))!;
    // 按发表时间旧→新收进来，归档的不收。
    expect(members, <String>[first, second]);
    expect(find.text('已转为普通日记本，收进 2 篇'), findsOneWidget);
    expect(find.text('2 篇'), findsOneWidget);

    // 之后不再按规则自动更新。
    await pinnedDiary(h, '新置顶');
    final after = (await tester.runAsync(
      () => h.database.getActiveDiaryIds(
        scope: DiaryNotebookScope(notebookId: smart),
      ),
    ))!;
    expect(after, hasLength(2));
    await h.unmount();
  });

  testWidgets('the search page saves keyword and tags as a smart notebook', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    const tag = Tag(id: 1, name: '旅行', color: 0xff336699);
    await h.pump(
      const DiarySearchPage(initialKeyword: '樱花', initialTagIds: <int>{1}),
      overrides: [
        tagListProvider.overrideWith((ref) => Stream.value(const <Tag>[tag])),
        searchDiariesProvider.overrideWith(
          (ref, query) => Stream.value(
            PagedDiariesResult(
              items: const <DiaryWithTags>[],
              limit: query.limit,
              hasMore: false,
            ),
          ),
        ),
      ],
    );
    await h.settleAll();
    await tester.tap(find.byTooltip('存为智能日记本'));
    await h.settleAll();

    expect(find.byType(NotebookEditorPage), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find
                .descendant(
                  of: find.byType(NotebookEditorPage),
                  matching: find.byType(TextField),
                )
                .first,
          )
          .controller!
          .text,
      '樱花',
    );
    await tester.scrollUntilVisible(
      find.text('标签全部都含：#旅行'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(NotebookEditorPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('标题或正文包含“樱花”'), findsOneWidget);
    expect(find.text('标签全部都含：#旅行'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await h.settleAll();
    final row = (await h.shelf()).single;
    expect(row.notebookKind, NotebookKind.smart);
    expect(
      NotebookRuleSet.decode(row.parsedPayload.rules).rules,
      <NotebookRule>[
        NotebookTextRule(field: NotebookTextField.keyword, text: '樱花'),
        NotebookTagsRule(mode: NotebookTagMatch.all, names: <String>['旅行']),
      ],
    );
    await h.unmount();
  });

  testWidgets('the search action hides without conditions', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.pump(
      const DiarySearchPage(),
      overrides: [
        tagListProvider.overrideWith((ref) => Stream.value(const <Tag>[])),
      ],
    );
    await h.settleAll();
    expect(find.byTooltip('存为智能日记本'), findsNothing);
    await h.unmount();
  });
}

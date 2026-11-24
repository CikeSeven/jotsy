import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/device_auth_service.dart';
import 'package:node_diary/ui/notebooks/pages/notebook_contents_page.dart';
import 'package:node_diary/ui/notebooks/sections/notebook_contents_chapter_header.dart';

import '../../support/diary_drafts_harness.dart';
import '../../support/expressive_test_theme.dart';
import 'notebook_test_support.dart';

/// 目录页“转移目录”：整份目录转移、单个章节转移、面板内新建子本、候选过滤、
/// 转回上级（含私密转普通的提示）、提示条撤销、第 3 层叶子本只能往上转、上锁
/// 子本验证与私密提示、暗色主题。
void main() {
  final tokyo = NotebookChapter(id: 'c1', title: '东京');
  final kyoto = NotebookChapter(id: 'c2', title: '京都');

  Future<List<NotebookContentsEntry>> contentsOf(
    DiaryDraftsHarness h,
    String notebookId,
  ) async => (await h.tester.runAsync(
    () => h.database.getNotebookContents(notebookId),
  ))!;

  testWidgets(
    'transfers entire directory to an existing child notebook and filters '
    'ineligible children',
    (tester) async {
      final h = await DiaryDraftsHarness.create(tester);
      final travel = await h.notebook(
        '旅行',
        payload: NotebookPayload(chapters: <NotebookChapter>[tokyo, kyoto]),
      );
      final japan = await h.notebook('日本', parentId: travel);
      final kansai = await h.notebook('关西', parentId: japan);
      final closedChild = await h.notebook(
        '已合上',
        parentId: travel,
        closed: true,
      );
      final smartChild = await h.notebook(
        '智能子本',
        parentId: travel,
        kind: NotebookKind.smart,
      );
      final other = await h.notebook('其他本');

      final d1 = await h.diary('浅草寺', notebookIds: <String>[travel]);
      final d2 = await h.diary('岚山', notebookIds: <String>[travel]);
      final d3 = await h.diary('行前准备', notebookIds: <String>[travel]);
      await tester.runAsync(
        () => h.database.setNotebookEntriesChapter(travel, <String>[d1], 'c1'),
      );
      await tester.runAsync(
        () => h.database.setNotebookEntriesChapter(travel, <String>[d2], 'c2'),
      );

      await h.pump(NotebookContentsPage(notebookId: travel));
      await h.settleAll();

      await tester.tap(find.byTooltip('转移目录'));
      await h.settleAll();

      expect(find.text('将目录转移到哪个日记本'), findsOneWidget);
      expect(
        find.byKey(ValueKey<String>('notebook_transfer_target_$japan')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey<String>('notebook_transfer_target_$kansai')),
        findsOneWidget,
      );
      // 智能子本、已合上子本与其他顶层本不出现。
      expect(
        find.byKey(ValueKey<String>('notebook_transfer_target_$closedChild')),
        findsNothing,
      );
      expect(
        find.byKey(ValueKey<String>('notebook_transfer_target_$smartChild')),
        findsNothing,
      );
      expect(
        find.byKey(ValueKey<String>('notebook_transfer_target_$other')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(ValueKey<String>('notebook_transfer_target_$kansai')),
      );
      await h.settleAll();

      expect(find.text('确认转移'), findsOneWidget);
      expect(
        find.text(
          '将「旅行」的 2 个章节和 3 篇日记转移到「关西」？'
          '章节和顺序会一并保留，并从「旅行」移出，日记不会被删除。',
        ),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(TextButton, '转移'));
      await h.settleAll();

      expect(find.text('已将目录转移到「关西」'), findsOneWidget);
      expect(await contentsOf(h, travel), isEmpty);
      expect((await h.notebookRow(travel))!.parsedPayload.chapters, isEmpty);

      final moved = await contentsOf(h, kansai);
      expect(
        <(String, String?)>[for (final e in moved) (e.diaryId, e.chapterId)],
        <(String, String?)>[(d1, 'c1'), (d2, 'c2'), (d3, null)],
      );
      expect(
        (await h.notebookRow(
          kansai,
        ))!.parsedPayload.chapters.map((c) => c.title),
        <String>['东京', '京都'],
      );
      await h.unmount();
    },
  );

  testWidgets('moves a single chapter to a child notebook from chapter menu', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    final travel = await h.notebook(
      '旅行',
      payload: NotebookPayload(chapters: <NotebookChapter>[tokyo, kyoto]),
    );
    final kanto = await h.notebook('关东', parentId: travel);
    final d1 = await h.diary('新宿', notebookIds: <String>[travel]);
    final d2 = await h.diary('伏见稻荷', notebookIds: <String>[travel]);
    await tester.runAsync(
      () => h.database.setNotebookEntriesChapter(travel, <String>[d1], 'c1'),
    );
    await tester.runAsync(
      () => h.database.setNotebookEntriesChapter(travel, <String>[d2], 'c2'),
    );

    await h.pump(NotebookContentsPage(notebookId: travel));
    await h.settleAll();

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(NotebookContentsChapterHeader, '东京'),
        matching: find.byTooltip('章节操作'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('转移章节…').last);
    await h.settleAll();

    expect(find.text('将「东京」转移到哪个日记本'), findsOneWidget);
    await tester.tap(
      find.byKey(ValueKey<String>('notebook_transfer_target_$kanto')),
    );
    await h.settleAll();

    expect(
      find.text(
        '将章节「东京」及其中 1 篇日记转移到「关东」？'
        '章节和顺序会一并保留，并从「旅行」移出，日记不会被删除。',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, '转移'));
    await h.settleAll();

    expect(find.text('已将「东京」转移到「关东」'), findsOneWidget);
    expect(
      (await h.notebookRow(travel))!.parsedPayload.chapters.map((c) => c.title),
      <String>['京都'],
    );
    expect((await contentsOf(h, travel)).single.diaryId, d2);
    expect(
      (await h.notebookRow(kanto))!.parsedPayload.chapters.map((c) => c.title),
      <String>['东京'],
    );
    expect((await contentsOf(h, kanto)).single.diaryId, d1);
    await h.unmount();
  });

  testWidgets(
    'creates a new child notebook inline and transfers contents into it',
    (tester) async {
      final h = await DiaryDraftsHarness.create(tester);
      final work = await h.notebook(
        '工作',
        payload: NotebookPayload(chapters: <NotebookChapter>[tokyo]),
      );
      final d1 = await h.diary('周报', notebookIds: <String>[work]);
      await tester.runAsync(
        () => h.database.setNotebookEntriesChapter(work, <String>[d1], 'c1'),
      );

      await h.pump(NotebookContentsPage(notebookId: work));
      await h.settleAll();

      await tester.tap(find.byTooltip('转移目录'));
      await h.settleAll();

      expect(find.text('还没有子日记本，可在上方新建后转移'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('notebook_transfer_create_child')),
      );
      await h.settleAll();

      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('新建子日记本'),
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '2026归档');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, '创建'));
      await h.settleAll();

      // 建完子本后直接进入转移确认框。
      expect(find.text('确认转移'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '转移'));
      await h.settleAll();

      expect(find.text('已将目录转移到「2026归档」'), findsOneWidget);
      final shelf = await h.shelf();
      final created = shelf.firstWhere((n) => n.name == '2026归档');
      expect(created.parentId, work);
      expect(created.parsedPayload.chapters.map((c) => c.title), <String>[
        '东京',
      ]);
      expect((await contentsOf(h, created.notebookId)).single.diaryId, d1);
      expect(await contentsOf(h, work), isEmpty);
      await h.unmount();
    },
  );

  testWidgets(
    'max-depth leaf notebook only offers its parents, hides the entry when '
    'every parent is closed, and disables it when empty',
    (tester) async {
      final h = await DiaryDraftsHarness.create(tester);
      final level1 = await h.notebook('一级');
      final level2 = await h.notebook('二级', parentId: level1);
      final level3 = await h.notebook(
        '三级',
        parentId: level2,
        payload: NotebookPayload(chapters: <NotebookChapter>[tokyo]),
      );
      await h.diary('叶子篇', notebookIds: <String>[level3]);
      final closedTop = await h.notebook('合上一级', closed: true);
      final closedMid = await h.notebook(
        '合上二级',
        parentId: closedTop,
        closed: true,
      );
      final closedLeaf = await h.notebook('叶子', parentId: closedMid);
      await h.diary('孤叶', notebookIds: <String>[closedLeaf]);

      // 第 3 层最深叶子本：不能建子本，只能转回两级上级。
      await h.pump(NotebookContentsPage(notebookId: level3));
      await h.settleAll();
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(NotebookContentsChapterHeader, '东京'),
          matching: find.byTooltip('章节操作'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('转移章节…').last);
      await h.settleAll();
      expect(find.text('上级日记本'), findsOneWidget);
      expect(find.text('子日记本'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('notebook_transfer_create_child')),
        findsNothing,
      );
      expect(
        find.byKey(ValueKey<String>('notebook_transfer_target_$level1')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey<String>('notebook_transfer_target_$level2')),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(5, 5));
      await h.settleAll();

      // 上级全都合上了的叶子本：没有可转的目标，入口隐藏。
      await h.pump(NotebookContentsPage(notebookId: closedLeaf));
      await h.settleAll();
      expect(find.byTooltip('转移目录'), findsNothing);

      // 空目录的顶层本：顶栏显示按钮但禁用。
      await h.pump(NotebookContentsPage(notebookId: level1));
      await h.settleAll();
      final button = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (Widget w) => w is IconButton && w.tooltip == '转移目录',
        ),
      );
      expect(button.onPressed, isNull);
      await h.unmount();
    },
  );

  testWidgets(
    'undo on the snackbar restores a transfer, and a child can transfer its '
    'contents back to the parent',
    (tester) async {
      final h = await DiaryDraftsHarness.create(tester);
      final travel = await h.notebook(
        '旅行',
        payload: NotebookPayload(chapters: <NotebookChapter>[tokyo, kyoto]),
      );
      final japan = await h.notebook('日本', parentId: travel);
      final d1 = await h.diary('浅草寺', notebookIds: <String>[travel]);
      final d2 = await h.diary('岚山', notebookIds: <String>[travel]);
      await tester.runAsync(
        () => h.database.setNotebookEntriesChapter(travel, <String>[d1], 'c1'),
      );
      await tester.runAsync(
        () => h.database.setNotebookEntriesChapter(travel, <String>[d2], 'c2'),
      );
      Future<List<(String, String?)>> placements(String id) async =>
          <(String, String?)>[
            for (final e in await contentsOf(h, id)) (e.diaryId, e.chapterId),
          ];

      await h.pump(NotebookContentsPage(notebookId: travel));
      await h.settleAll();
      await tester.tap(find.byTooltip('转移目录'));
      await h.settleAll();
      // 顶层本没有上级：只有子本一组，不加分组标题。
      expect(find.text('上级日记本'), findsNothing);
      await tester.tap(
        find.byKey(ValueKey<String>('notebook_transfer_target_$japan')),
      );
      await h.settleAll();
      await tester.tap(find.widgetWithText(TextButton, '转移'));
      await h.settleAll();
      expect(find.text('已将目录转移到「日本」'), findsOneWidget);
      expect(await contentsOf(h, travel), isEmpty);

      await tester.tap(find.text('撤销'));
      await h.settleAll();
      expect(await placements(travel), <(String, String?)>[
        (d1, 'c1'),
        (d2, 'c2'),
      ]);
      expect(await contentsOf(h, japan), isEmpty);
      expect(
        (await h.notebookRow(travel))!.parsedPayload.chapters.map((c) => c.id),
        <String>['c1', 'c2'],
      );
      expect((await h.notebookRow(japan))!.parsedPayload.chapters, isEmpty);

      // 已经转到子本的内容：在子本的目录页转回上级。
      await tester.runAsync(
        () => h.database.transferNotebookContents(
          sourceId: travel,
          targetId: japan,
        ),
      );
      // 带 key：应用里每本各推一个路由，这里换本子也要换一个页面状态
      // （控制器在 initState 里按 notebookId 建好）。
      await h.pump(
        NotebookContentsPage(key: ValueKey<String>(japan), notebookId: japan),
      );
      await h.settleAll();
      await tester.tap(find.byTooltip('转移目录'));
      await h.settleAll();
      expect(find.text('上级日记本'), findsOneWidget);
      expect(find.text('子日记本'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('notebook_transfer_create_child')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(ValueKey<String>('notebook_transfer_target_$travel')),
      );
      await h.settleAll();
      expect(
        find.text(
          '将「日本」的 2 个章节和 2 篇日记转移到「旅行」？'
          '章节和顺序会一并保留，并从「日本」移出，日记不会被删除。',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, '转移'));
      await h.settleAll();
      expect(find.text('已将目录转移到「旅行」'), findsOneWidget);
      expect(await placements(travel), <(String, String?)>[
        (d1, 'c1'),
        (d2, 'c2'),
      ]);
      expect(await contentsOf(h, japan), isEmpty);
      await h.unmount();
    },
  );

  testWidgets(
    'warns that entries become public when transferring from a hidden child '
    'back to its normal parent in dark theme',
    (tester) async {
      final h = await DiaryDraftsHarness.create(tester);
      final daily = await h.notebook('日常');
      final hidden = await h.notebook(
        '隐藏子本',
        parentId: daily,
        visibility: NotebookVisibility.hidden,
      );
      final d1 = await h.diary('悄悄话', notebookIds: <String>[hidden]);

      await h.pump(
        Theme(
          data: expressiveTestTheme(Brightness.dark),
          child: NotebookContentsPage(notebookId: hidden),
        ),
      );
      await h.settleAll();
      await tester.tap(find.byTooltip('转移目录'));
      await h.settleAll();
      await tester.tap(
        find.byKey(ValueKey<String>('notebook_transfer_target_$daily')),
      );
      await h.settleAll();
      expect(find.text('「日常」不是私密日记本，转移后的日记会出现在全部日记里。'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '转移'));
      await h.settleAll();
      expect(find.text('已转移到「日常」，移入的日记会出现在全部日记里'), findsOneWidget);
      expect((await contentsOf(h, daily)).single.diaryId, d1);
      expect(await contentsOf(h, hidden), isEmpty);
      await h.unmount();
    },
  );

  testWidgets(
    'authenticates and warns about privacy when transferring into a locked '
    'sub-notebook',
    (tester) async {
      final auth = FakeDeviceAuth(results: <bool>[false, true]);
      final h = await DiaryDraftsHarness.create(tester);
      final normal = await h.notebook('日常');
      final vault = await h.notebook(
        '私密子本',
        parentId: normal,
        visibility: NotebookVisibility.locked,
      );
      final d1 = await h.diary('日记一', notebookIds: <String>[normal]);

      await h.pump(
        NotebookContentsPage(notebookId: normal),
        overrides: [deviceAuthServiceProvider.overrideWithValue(auth)],
      );
      await h.settleAll();

      // 第一次验证被拒：不弹确认框、不写库。
      await tester.tap(find.byTooltip('转移目录'));
      await h.settleAll();
      await tester.tap(
        find.byKey(ValueKey<String>('notebook_transfer_target_$vault')),
      );
      await h.settleAll();
      expect(auth.reasons, <String>['解锁「私密子本」']);
      expect(find.text('确认转移'), findsNothing);
      expect((await contentsOf(h, normal)).single.diaryId, d1);

      // 第二次验证通过：确认框展示私密提醒，确认后显示私密提示条。
      await tester.tap(find.byTooltip('转移目录'));
      await h.settleAll();
      await tester.tap(
        find.byKey(ValueKey<String>('notebook_transfer_target_$vault')),
      );
      await h.settleAll();
      expect(auth.reasons, hasLength(2));
      expect(
        find.text('「私密子本」是私密日记本，转移后的日记将只在该日记本中显示，不再出现在全部日记里。'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, '转移'));
      await h.settleAll();
      expect(find.text('已转移到「私密子本」，移入的日记只在该日记本中显示'), findsOneWidget);
      expect((await contentsOf(h, vault)).single.diaryId, d1);
      await h.unmount();
    },
  );

  testWidgets(
    'creating a child inside an already-unlocked locked parent does not '
    're-prompt authentication and renders cleanly in dark theme',
    (tester) async {
      final auth = FakeDeviceAuth(results: <bool>[true]);
      final h = await DiaryDraftsHarness.create(tester);
      final lockedParent = await h.notebook(
        '上锁父本',
        visibility: NotebookVisibility.locked,
      );
      final d1 = await h.diary('秘密', notebookIds: <String>[lockedParent]);

      await h.pump(
        Theme(
          data: expressiveTestTheme(Brightness.dark),
          child: NotebookContentsPage(notebookId: lockedParent),
        ),
        overrides: [deviceAuthServiceProvider.overrideWithValue(auth)],
      );
      await h.settleAll();

      await tester.tap(find.byTooltip('转移目录'));
      await h.settleAll();
      await tester.tap(
        find.byKey(const ValueKey<String>('notebook_transfer_create_child')),
      );
      await h.settleAll();
      await tester.enterText(find.byType(TextField), '子保险箱');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, '创建'));
      await h.settleAll();

      // 继承同一把锁的新子本不再重复验证。
      expect(auth.reasons, isEmpty);
      expect(find.text('确认转移'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '转移'));
      await h.settleAll();

      final child = (await h.shelf()).firstWhere((n) => n.name == '子保险箱');
      expect((await contentsOf(h, child.notebookId)).single.diaryId, d1);
      await h.unmount();
    },
  );
}

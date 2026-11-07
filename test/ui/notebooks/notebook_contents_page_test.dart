import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/notebooks/pages/notebook_contents_page.dart';
import 'package:node_diary/ui/notebooks/sections/notebook_contents_chapter_header.dart';
import 'package:node_diary/ui/notebooks/sections/notebook_contents_rows.dart';
import 'package:node_diary/ui/widgets/reorder_handle.dart';

import '../../support/diary_drafts_harness.dart';
import 'notebook_test_support.dart';

/// 目录页：按书序列出章节与日记，拖动换章并写回顺序，章节的改名 / 上下移 /
/// 删除，多选移到章节与移出（可撤销），没有章节时的提示。
void main() {
  final tokyo = NotebookChapter(id: 'c1', title: '东京');
  final kyoto = NotebookChapter(id: 'c2', title: '京都');

  Future<(DiaryDraftsHarness, String, Map<String, String>)> pumpContents(
    WidgetTester tester, {
    List<NotebookChapter> chapters = const <NotebookChapter>[],
    Map<String, String?> diaries = const <String, String?>{},
  }) async {
    final h = await DiaryDraftsHarness.create(tester);
    final travel = await h.notebook(
      '旅行',
      payload: NotebookPayload(chapters: chapters),
    );
    final ids = <String, String>{};
    for (final MapEntry(key: title, value: chapterId) in diaries.entries) {
      final id = await h.diary(title, notebookIds: <String>[travel]);
      ids[title] = id;
      if (chapterId != null) {
        await tester.runAsync(
          () => h.database.setNotebookEntriesChapter(travel, <String>[
            id,
          ], chapterId),
        );
      }
    }
    await h.pump(NotebookContentsPage(notebookId: travel));
    await h.settleAll();
    return (h, travel, ids);
  }

  Future<List<NotebookContentsEntry>> contents(
    DiaryDraftsHarness h,
    String notebookId,
  ) async => (await h.tester.runAsync(
    () => h.database.watchNotebookContents(notebookId).first,
  ))!;

  /// 屏幕上自上而下的章节名与日记标题。
  List<String> visibleOrder(WidgetTester tester) {
    final labels = <(double, String)>[];
    for (final element
        in find.byType(NotebookContentsChapterHeader).evaluate()) {
      final widget = element.widget as NotebookContentsChapterHeader;
      labels.add((
        tester.getTopLeft(find.byWidget(widget)).dy,
        '#${widget.chapter?.title ?? '未分章'}',
      ));
    }
    for (final element in find.byType(NotebookContentsEntryTile).evaluate()) {
      final widget = element.widget as NotebookContentsEntryTile;
      labels.add((tester.getTopLeft(find.byWidget(widget)).dy, widget.title));
    }
    labels.sort((a, b) => a.$1.compareTo(b.$1));
    return <String>[for (final label in labels) label.$2];
  }

  Future<void> dragEntry(DiaryDraftsHarness h, String title, double dy) async {
    final tester = h.tester;
    final handle = find.descendant(
      of: find.widgetWithText(NotebookContentsEntryTile, title),
      matching: find.byType(ReorderableDragStartListener),
    );
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    const steps = 20;
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(Offset(0, dy / steps));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    await h.settleAll();
  }

  Future<void> chapterMenu(
    DiaryDraftsHarness h,
    String chapter,
    String item,
  ) async {
    await h.tester.tap(
      find.descendant(
        of: find.widgetWithText(NotebookContentsChapterHeader, chapter),
        matching: find.byTooltip('章节操作'),
      ),
    );
    await h.tester.pumpAndSettle();
    await h.tester.tap(find.text(item).last);
    await h.settleAll();
  }

  testWidgets('lists chapters and entries in book order', (tester) async {
    final (h, _, _) = await pumpContents(
      tester,
      chapters: <NotebookChapter>[tokyo, kyoto],
      diaries: <String, String?>{'甲': 'c2', '乙': null, '丙': 'c1'},
    );
    expect(visibleOrder(tester), <String>['#东京', '丙', '#京都', '甲', '#未分章', '乙']);
    expect(find.text('添加章节，把日记分成几部分'), findsNothing);
    await h.unmount();
  });

  testWidgets('without chapters shows the entries and the chapter hint', (
    tester,
  ) async {
    final (h, _, _) = await pumpContents(
      tester,
      diaries: <String, String?>{'甲': null},
    );
    expect(find.text('添加章节，把日记分成几部分'), findsOneWidget);
    expect(find.byType(NotebookContentsChapterHeader), findsNothing);
    expect(visibleOrder(tester), <String>['甲']);
    await h.unmount();
  });

  testWidgets('dragging an entry into another chapter persists chapter and '
      'position', (tester) async {
    final (h, travel, ids) = await pumpContents(
      tester,
      chapters: <NotebookChapter>[tokyo, kyoto],
      diaries: <String, String?>{'甲': 'c1', '乙': 'c1', '丙': 'c2'},
    );
    // 把“甲”拖到“丙”的下方（京都一章的末尾）。
    final from = tester.getRect(
      find.widgetWithText(NotebookContentsEntryTile, '甲'),
    );
    final to = tester.getRect(
      find.widgetWithText(NotebookContentsEntryTile, '丙'),
    );
    await dragEntry(h, '甲', to.bottom - from.bottom);

    expect(visibleOrder(tester), <String>['#东京', '乙', '#京都', '丙', '甲', '#未分章']);
    final rows = await contents(h, travel);
    expect(
      <(String, String?)>[for (final r in rows) (r.diaryId, r.chapterId)],
      <(String, String?)>[
        (ids['乙']!, 'c1'),
        (ids['丙']!, 'c2'),
        (ids['甲']!, 'c2'),
      ],
    );
    await h.unmount();
  });

  testWidgets('dragging into the empty unassigned zone takes an entry out '
      'of its chapter', (tester) async {
    final (h, travel, ids) = await pumpContents(
      tester,
      chapters: <NotebookChapter>[tokyo],
      diaries: <String, String?>{'甲': 'c1', '乙': 'c1'},
    );
    expect(visibleOrder(tester), <String>['#东京', '甲', '乙', '#未分章']);
    expect(find.text('拖到这里移出章节'), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(NotebookContentsChapterHeader, '未分章'),
        matching: find.text('0 篇'),
      ),
      findsOneWidget,
    );
    final from = tester.getRect(
      find.widgetWithText(NotebookContentsEntryTile, '甲'),
    );
    final zone = tester.getRect(
      find.widgetWithText(NotebookContentsChapterHeader, '未分章'),
    );
    await dragEntry(h, '甲', zone.bottom - from.bottom);

    expect(visibleOrder(tester), <String>['#东京', '乙', '#未分章', '甲']);
    expect(find.text('拖到这里移出章节'), findsNothing);
    final rows = await contents(h, travel);
    expect(
      <(String, String?)>[for (final r in rows) (r.diaryId, r.chapterId)],
      <(String, String?)>[(ids['乙']!, 'c1'), (ids['甲']!, null)],
    );
    await h.unmount();
  });

  testWidgets('dragging above the first header lands in the first chapter', (
    tester,
  ) async {
    final (h, travel, ids) = await pumpContents(
      tester,
      chapters: <NotebookChapter>[tokyo, kyoto],
      diaries: <String, String?>{'甲': 'c1', '丙': 'c2'},
    );
    final from = tester.getRect(
      find.widgetWithText(NotebookContentsEntryTile, '丙'),
    );
    final top = tester.getRect(
      find.widgetWithText(NotebookContentsChapterHeader, '东京'),
    );
    await dragEntry(h, '丙', top.top - from.top - 20);

    expect(visibleOrder(tester), <String>['#东京', '丙', '甲', '#京都', '#未分章']);
    final rows = await contents(h, travel);
    expect(rows.first.diaryId, ids['丙']);
    expect(rows.first.chapterId, 'c1');
    await h.unmount();
  });

  testWidgets('adds, renames, moves and deletes chapters', (tester) async {
    final (h, travel, ids) = await pumpContents(
      tester,
      chapters: <NotebookChapter>[tokyo, kyoto],
      diaries: <String, String?>{'甲': 'c1'},
    );
    await tester.tap(find.byTooltip('新章节'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  大阪  ');
    await tester.pump();
    await tester.tap(find.text('创建'));
    await h.settleAll();
    var payload = (await h.notebookRow(travel))!.parsedPayload;
    expect(payload.chapters.map((c) => c.title), <String>['东京', '京都', '大阪']);

    await chapterMenu(h, '京都', '重命名');
    await tester.enterText(find.byType(TextField), '奈良');
    await tester.pump();
    await tester.tap(find.text('保存'));
    await h.settleAll();
    await chapterMenu(h, '奈良', '上移');
    payload = (await h.notebookRow(travel))!.parsedPayload;
    expect(payload.chapters.map((c) => c.title), <String>['奈良', '东京', '大阪']);
    expect(visibleOrder(tester).first, '#奈良');

    await chapterMenu(h, '东京', '删除');
    expect(find.text('删除章节「东京」？其中的 1 篇回到未分章，日记不会被删除'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await h.settleAll();
    payload = (await h.notebookRow(travel))!.parsedPayload;
    expect(payload.chapters.map((c) => c.title), <String>['奈良', '大阪']);
    final rows = await contents(h, travel);
    expect(rows.single.diaryId, ids['甲']);
    expect(rows.single.chapterId, isNull);
    expect(visibleOrder(tester), <String>['#奈良', '#大阪', '#未分章', '甲']);
    await h.unmount();
  });

  testWidgets('multi-select moves entries to a chapter and removes them '
      'with undo', (tester) async {
    final (h, travel, ids) = await pumpContents(
      tester,
      chapters: <NotebookChapter>[tokyo, kyoto],
      diaries: <String, String?>{'甲': 'c1', '乙': 'c1'},
    );
    await tester.tap(find.byTooltip('多选'));
    await tester.pumpAndSettle();
    expect(find.byType(ReorderHandle), findsNothing);
    await tester.tap(find.widgetWithText(NotebookContentsEntryTile, '甲'));
    await tester.pumpAndSettle();
    expect(find.text('已选 1 篇'), findsOneWidget);
    await tester.tap(find.text('移到章节…'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('notebook_chapter_pick_c2')),
    );
    await h.settleAll();
    var rows = await contents(h, travel);
    expect(rows.firstWhere((r) => r.diaryId == ids['甲']).chapterId, 'c2');
    expect(find.text('已将 1 篇移到「京都」'), findsOneWidget);
    // 移动后退出多选。
    expect(find.text('已选 1 篇'), findsNothing);

    await tester.tap(find.byTooltip('多选'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NotebookContentsEntryTile, '乙'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从本日记本移出'));
    await h.settleAll();
    rows = await contents(h, travel);
    expect(rows.map((r) => r.diaryId), <String>[ids['甲']!]);
    expect(find.text('已从「旅行」移出 1 篇'), findsOneWidget);

    await tester.tap(find.text('撤销'));
    await h.settleAll();
    rows = await contents(h, travel);
    expect(rows.map((r) => r.diaryId).toSet(), <String>{ids['甲']!, ids['乙']!});
    expect(rows.firstWhere((r) => r.diaryId == ids['乙']).chapterId, 'c1');
    await tester.pump(const Duration(seconds: 5));
    await h.unmount();
  });

  testWidgets('an empty notebook shows the empty hint', (tester) async {
    final (h, _, _) = await pumpContents(tester);
    expect(find.text('这本还没有日记'), findsOneWidget);
    await h.unmount();
  });

  /// 标题为 [title] 的章节标题行。
  Finder header(String title) =>
      find.widgetWithText(NotebookContentsChapterHeader, title);

  /// 日记行 [title] 是否看得见、点得到（收起的行仍在树里，只收到 0 高度）。
  bool shown(WidgetTester tester, String title) => find
      .widgetWithText(NotebookContentsEntryTile, title)
      .hitTestable()
      .evaluate()
      .isNotEmpty;

  testWidgets('tapping a chapter title collapses and expands its entries', (
    tester,
  ) async {
    final (h, _, _) = await pumpContents(
      tester,
      chapters: <NotebookChapter>[tokyo, kyoto],
      diaries: <String, String?>{'甲': 'c1', '乙': 'c1', '丙': 'c2'},
    );
    expect(shown(tester, '甲'), isTrue);
    await tester.tap(find.text('东京'));
    await tester.pumpAndSettle();
    expect(shown(tester, '甲'), isFalse);
    expect(shown(tester, '乙'), isFalse);
    expect(shown(tester, '丙'), isTrue);
    // 收起后篇数照旧，京都紧跟在东京下面。
    expect(
      find.descendant(of: header('东京'), matching: find.text('2 篇')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(header('京都')).dy,
      closeTo(tester.getBottomLeft(header('东京')).dy, 0.5),
    );

    await tester.tap(find.text('东京'));
    await tester.pumpAndSettle();
    expect(shown(tester, '甲'), isTrue);
    expect(shown(tester, '乙'), isTrue);

    // 空着的“未分章”没有箭头，点了也不收起（落点提示仍在）。
    expect(
      find.descendant(
        of: header('未分章'),
        matching: find.byIcon(FontAwesomeIcons.angleDown.data),
      ),
      findsNothing,
    );
    await tester.tap(find.text('未分章'));
    await tester.pumpAndSettle();
    expect(find.text('拖到这里移出章节'), findsOneWidget);
    await h.unmount();
  });

  testWidgets('dragging a chapter handle moves the whole chapter', (
    tester,
  ) async {
    final (h, travel, ids) = await pumpContents(
      tester,
      chapters: <NotebookChapter>[tokyo, kyoto],
      diaries: <String, String?>{'甲': 'c1', '乙': 'c1', '丙': 'c2'},
    );
    final handle = find.descendant(
      of: header('东京'),
      matching: find.byType(ReorderHandle),
    );
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    // 拿起后这一章的日记收进来，看起来整章一起移动。
    await tester.pump(const Duration(milliseconds: 400));
    expect(shown(tester, '甲'), isFalse);
    // 拖到京都的日记“丙”下面。
    final lifted = tester.getRect(header('东京'));
    final bing = tester.getRect(
      find.widgetWithText(NotebookContentsEntryTile, '丙'),
    );
    final dy = bing.bottom - lifted.bottom + 8;
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(Offset(0, dy / 10));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    await h.settleAll();

    expect(visibleOrder(tester), <String>['#京都', '丙', '#东京', '甲', '乙', '#未分章']);
    expect(shown(tester, '甲'), isTrue);
    final payload = (await h.notebookRow(travel))!.parsedPayload;
    expect(payload.chapters.map((c) => c.id), <String>['c2', 'c1']);
    // 只换章节顺序，日记的归属不变。
    final rows = await contents(h, travel);
    expect(rows.firstWhere((r) => r.diaryId == ids['甲']).chapterId, 'c1');
    expect(rows.firstWhere((r) => r.diaryId == ids['丙']).chapterId, 'c2');
    await h.unmount();
  });

  testWidgets('dropping an entry into a collapsed chapter expands it', (
    tester,
  ) async {
    final (h, travel, ids) = await pumpContents(
      tester,
      chapters: <NotebookChapter>[tokyo, kyoto],
      diaries: <String, String?>{'甲': 'c1', '乙': 'c1', '丙': 'c2'},
    );
    await tester.tap(find.text('东京'));
    await tester.pumpAndSettle();
    expect(shown(tester, '甲'), isFalse);
    // 把“丙”拖过京都的标题行，落在收起的东京下面。
    final from = tester.getRect(
      find.widgetWithText(NotebookContentsEntryTile, '丙'),
    );
    final kyotoRect = tester.getRect(header('京都'));
    await dragEntry(h, '丙', kyotoRect.top - from.top - 12);

    final rows = await contents(h, travel);
    expect(rows.firstWhere((r) => r.diaryId == ids['丙']).chapterId, 'c1');
    expect(shown(tester, '甲'), isTrue);
    expect(shown(tester, '乙'), isTrue);
    final order = visibleOrder(tester);
    expect(order.indexOf('丙'), lessThan(order.indexOf('#京都')));
    expect(order.first, '#东京');
    await h.unmount();
  });

  testWidgets('the unassigned header and multi-select show no chapter '
      'handle', (tester) async {
    final (h, _, _) = await pumpContents(
      tester,
      chapters: <NotebookChapter>[tokyo],
      diaries: <String, String?>{'甲': 'c1', '乙': null},
    );
    Finder handleIn(String title) => find.descendant(
      of: header(title),
      matching: find.byType(ReorderHandle),
    );
    expect(handleIn('东京'), findsOneWidget);
    expect(handleIn('未分章'), findsNothing);
    // 章节的手柄与日记行的手柄在同一列。
    expect(
      tester.getCenter(handleIn('东京')).dx,
      tester
          .getCenter(
            find.descendant(
              of: find.widgetWithText(NotebookContentsEntryTile, '甲'),
              matching: find.byType(ReorderHandle),
            ),
          )
          .dx,
    );
    await tester.tap(find.byTooltip('多选'));
    await tester.pumpAndSettle();
    expect(handleIn('东京'), findsNothing);
    await h.unmount();
  });
}

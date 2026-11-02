import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/device_auth_service.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/diaries/widgets/diary_selection_surface.dart';
import 'package:node_diary/ui/notebooks/providers/home_notebook_scope_provider.dart';

import '../../../support/diary_drafts_harness.dart';
import '../../notebooks/notebook_test_support.dart';

/// 首页多选的全选：顶栏“已选数量”那一块是全选开关。全选按列表的同一查询
/// 取 id（含还没分页加载的部分，排除归档与私密，范围与标签筛选生效），
/// 再点取消全选但留在多选；列表变化后“已全选”随之更新。
void main() {
  /// 首屏窗口为 20 篇：写 25 篇，后 5 篇（最早写的）不在首屏里。
  const total = 25;

  /// [database] 给出时夹具用它代替新建的内存库。
  Future<DiaryDraftsHarness> pumpHome(
    WidgetTester tester,
    Future<void> Function(DiaryDraftsHarness h) seed, {
    AppDatabase? database,
  }) async {
    final h = await DiaryDraftsHarness.create(tester, database: database);
    await seed(h);
    await h.pump(
      const DiariesPage(),
      overrides: [
        deviceAuthServiceProvider.overrideWithValue(FakeDeviceAuth()),
      ],
    );
    await h.settleAll();
    return h;
  }

  /// 依次写 [count] 篇“日记 00”…（越晚写的越靠前），返回 id（按写入顺序）。
  Future<List<String>> seedMany(
    DiaryDraftsHarness h,
    int count, {
    String prefix = '日记',
    List<int> tagIds = const <int>[],
    List<String>? notebookIds,
  }) async => (await h.tester.runAsync(() async {
    final ids = <String>[];
    for (var i = 0; i < count; i++) {
      ids.add(
        await h.database.createDiary(
          title: '$prefix ${i.toString().padLeft(2, '0')}',
          contentDocJson: '[{"insert":"正文\\n"}]',
          contentText: '正文',
          metadataJson: '{}',
          tagIds: tagIds,
          notebookIds: notebookIds,
          createdAtOverride: DateTime(2026, 1, 1).add(Duration(minutes: i)),
        ),
      );
    }
    return ids;
  }))!;

  Future<List<String>> activeIds(DiaryDraftsHarness h) async =>
      (await h.tester.runAsync(() => h.database.getActiveDiaryIds()))!;

  Finder card(String title) => find.ancestor(
    of: find.text(title),
    matching: find.byType(DiarySelectionSurface),
  );

  final selectAllToggle = find.byKey(const ValueKey<String>('head_select_all'));

  Finder toggleIcon(IconData icon) =>
      find.descendant(of: selectAllToggle, matching: find.byIcon(icon));

  /// 全选开关为实心（已全选）。
  final solidToggle = toggleIcon(FontAwesomeIcons.solidSquareCheck.data);

  /// 全选开关为描边（未全选）。
  final outlineToggle = toggleIcon(FontAwesomeIcons.squareCheck.data);

  Future<void> enterSelection(DiaryDraftsHarness h, String title) async {
    await h.tester.longPress(card(title));
    await h.tester.pumpAndSettle();
  }

  Future<void> tapSelectAll(DiaryDraftsHarness h) async {
    await h.tester.tap(selectAllToggle);
    await h.settleAll();
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(DiariesPage)));

  /// 顶栏的已选数量。按读屏值断言：测试字体比真实字体宽，400dp 宽的夹具里
  /// 顶栏可能只显示数字（见 `_SelectAllCount`），读屏值始终是完整文案。
  void expectSelected(WidgetTester tester, String count) {
    expect(tester.getSemantics(selectAllToggle).value, '已选择 $count 项');
  }

  testWidgets(
    'select all picks every diary of the list including unloaded pages '
    'but not archived or private ones',
    (tester) async {
      final h = await pumpHome(tester, (h) async {
        await seedMany(h, total);
        final archived = await h.diary('已归档的');
        await tester.runAsync(() => h.database.archiveDiary(archived));
        final secret = await h.notebook(
          '秘密',
          visibility: NotebookVisibility.hidden,
        );
        await h.diary('私密的', notebookIds: <String>[secret]);
      });
      // 首屏只加载了 20 篇。
      expect(card('日记 24'), findsOneWidget);
      expect(find.text('日记 00'), findsNothing);

      await enterSelection(h, '日记 24');
      expectSelected(tester, '1');
      expect(outlineToggle, findsOneWidget);

      await tapSelectAll(h);
      expectSelected(tester, '$total');
      expect(solidToggle, findsOneWidget);
      expect(
        tester.getSemantics(selectAllToggle),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          label: '取消全选',
          value: '已选择 $total 项',
        ),
      );
      await h.unmount();
    },
  );

  testWidgets('select all follows the tag filter and the notebook scope', (
    tester,
  ) async {
    late int travel;
    late String notebook;
    final h = await pumpHome(tester, (h) async {
      travel = (await tester.runAsync(
        () => h.database.createTag(name: '旅行', color: 0xff2196f3),
      ))!;
      notebook = await h.notebook('旅行本');
      await seedMany(h, 22, prefix: '旅行', tagIds: <int>[travel]);
      await seedMany(h, 4, prefix: '其他');
      await seedMany(h, 21, prefix: '本子里', notebookIds: <String>[notebook]);
    });

    container(tester).read(diaryFilterProvider.notifier).setTags(<int>[travel]);
    await h.settleAll();
    await enterSelection(h, '旅行 21');
    await tapSelectAll(h);
    expectSelected(tester, '22');
    expect(solidToggle, findsOneWidget);

    // 换到日记本里（退出多选），全选只取这本里的。
    await tester.tap(find.byTooltip('取消'));
    await tester.pumpAndSettle();
    container(tester).read(diaryFilterProvider.notifier).clearTags();
    container(tester).read(homeNotebookScopeProvider.notifier).enter(notebook);
    await h.settleAll();
    await enterSelection(h, '本子里 20');
    await tapSelectAll(h);
    expectSelected(tester, '21');
    await h.unmount();
  });

  testWidgets('tapping again deselects all but stays in selection mode', (
    tester,
  ) async {
    final h = await pumpHome(tester, (h) => seedMany(h, total));
    await enterSelection(h, '日记 24');
    await tapSelectAll(h);
    expectSelected(tester, '$total');

    await tapSelectAll(h);
    expectSelected(tester, '0');
    expect(outlineToggle, findsOneWidget);
    // 仍在多选：批量操作停用，点卡片是勾选而不是打开。
    final archive = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('归档'),
        matching: find.byType(IconButton),
      ),
    );
    expect(archive.onPressed, isNull);
    await tester.tap(card('日记 23'));
    await tester.pumpAndSettle();
    expectSelected(tester, '1');
    // 取消最后一篇照常退出多选。
    await tester.tap(card('日记 23'));
    await tester.pumpAndSettle();
    expect(selectAllToggle, findsNothing);
    await h.unmount();
  });

  testWidgets('the all-selected state follows changes to the list', (
    tester,
  ) async {
    final h = await pumpHome(tester, (h) => seedMany(h, total));
    await enterSelection(h, '日记 24');
    await tapSelectAll(h);
    expect(solidToggle, findsOneWidget);

    // 别处新写了一篇（比如局域网同步写入）：列表多了一篇没选上的。
    await tester.runAsync(
      () => h.database.createDiary(
        title: '新来的',
        contentDocJson: '[{"insert":"正文\\n"}]',
        contentText: '正文',
        metadataJson: '{}',
      ),
    );
    await h.settleAll();
    expectSelected(tester, '$total');
    expect(outlineToggle, findsOneWidget);

    await tapSelectAll(h);
    expectSelected(tester, '${total + 1}');
    expect(solidToggle, findsOneWidget);
    await h.unmount();
  });

  testWidgets('archiving after select all also archives unloaded diaries and '
      'undo brings them all back', (tester) async {
    late List<String> ids;
    final h = await pumpHome(tester, (h) async {
      ids = await seedMany(h, total);
    });
    await enterSelection(h, '日记 24');
    await tapSelectAll(h);

    await tester.tap(find.byTooltip('归档'));
    await h.settleAll();
    expect(find.text('已归档 $total 条日记'), findsOneWidget);
    expect(await activeIds(h), isEmpty);
    // 最早写的几篇从没加载过，同样归档了。
    final oldest = (await tester.runAsync(
      () => h.database.getDiaryWithTagsByDiaryId(ids.first),
    ))!;
    expect(oldest.diary.isArchived, isTrue);
    expect(selectAllToggle, findsNothing);

    await tester.tap(find.text('撤销'));
    await h.settleAll();
    expect((await activeIds(h)).toSet(), ids.toSet());
    await tester.pump(const Duration(seconds: 5));
    await h.unmount();
  });

  testWidgets('pin action reads unpin when every selected diary is pinned, '
      'including unloaded ones', (tester) async {
    final h = await pumpHome(tester, (h) async {
      final ids = await seedMany(h, total);
      await tester.runAsync(
        () => h.database.setDiariesPinned(ids, pinned: true),
      );
    });
    await enterSelection(h, '日记 24');
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    // 只选了一篇（已置顶）。
    expect(find.text('取消置顶'), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await tapSelectAll(h);
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    expect(find.text('取消置顶'), findsOneWidget);
    await tester.tap(find.text('取消置顶'));
    await h.settleAll();
    final pinned = (await tester.runAsync(
      () => h.database.watchDiaryTimeline().first,
    ))!.where((entry) => entry.isPinned);
    expect(pinned, isEmpty);
    await h.unmount();
  });

  testWidgets(
    'leaving selection while select all is reading drops the result',
    (tester) async {
      // 全选的读取卡在闸门上：先退出多选、再重新进入，最后放行读取。
      final database = _GatedDatabase();
      final h = await pumpHome(
        tester,
        (h) => seedMany(h, total),
        database: database,
      );
      await enterSelection(h, '日记 24');

      final gate = database.gate = Completer<void>();
      await tester.tap(selectAllToggle);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('取消'));
      await tester.pumpAndSettle();
      expect(selectAllToggle, findsNothing);

      // 重新进入多选后才读完：那次读取的结果也不能被套用。
      await enterSelection(h, '日记 24');
      gate.complete();
      await h.settleAll();
      expectSelected(tester, '1');

      // 对照：不打断时同一个闸门放行后照常全选。
      final second = database.gate = Completer<void>();
      await tester.tap(selectAllToggle);
      await tester.pumpAndSettle();
      expectSelected(tester, '1');
      second.complete();
      await h.settleAll();
      expectSelected(tester, '$total');
      await h.unmount();
    },
  );
}

/// [getActiveDiaryIds]（全选的读取）等 [gate] 放行才返回。
class _GatedDatabase extends AppDatabase {
  _GatedDatabase() : super.forTesting(NativeDatabase.memory());

  Completer<void>? gate;

  @override
  Future<List<String>> getActiveDiaryIds({
    String keyword = '',
    List<int> requiredTagIds = const <int>[],
    DiarySortMode sortMode = DiarySortMode.updatedDesc,
    DiaryListScope scope = DiaryListScope.all,
    bool matchComments = false,
  }) async {
    await gate?.future;
    return super.getActiveDiaryIds(
      keyword: keyword,
      requiredTagIds: requiredTagIds,
      sortMode: sortMode,
      scope: scope,
      matchComments: matchComments,
    );
  }
}

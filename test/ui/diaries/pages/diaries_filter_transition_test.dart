import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/diaries/widgets/diary_list_switch_reveal.dart';
import 'package:node_diary/ui/diaries/widgets/diary_tag_filter_bar.dart';
import 'package:node_diary/ui/diaries/providers/diary_draft_providers.dart';
import 'package:node_diary/ui/notebooks/providers/notebook_providers.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

const _tag = Tag(id: 1, name: 'Travel', color: 0xff336699);

DiaryWithTags _diary(String id, String title) => DiaryWithTags(
  diary: Diary(
    id: id.hashCode,
    diaryId: id,
    title: title,
    content: '[{"insert":"Content\\n"}]',
    contentText: 'Content',
    metadata: '{}',
    createdAt: DateTime(2026, 10, 4),
    updatedAt: DateTime(2026, 10, 4),
    isArchived: false,
    isPinned: false,
    isDeleted: false,
  ),
  tags: const <Tag>[_tag],
);

/// 第 0 篇标题为 [first]，其余为 “[first] i”。
List<DiaryWithTags> _diaries(String first, int count) => <DiaryWithTags>[
  for (var i = 0; i < count; i++)
    _diary('$first-$i', i == 0 ? first : '$first $i'),
];

/// 无筛选时立即返回旧列表（[oldCount] 篇）；带标签筛选时模拟数据库延迟
/// [filteredDelay]，返回 [freshCount] 篇。
Future<void> _pumpPage(
  WidgetTester tester, {
  required Duration filteredDelay,
  int oldCount = 1,
  int freshCount = 1,
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = const Size(390, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (reduceMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final settings = await SettingsService.create();
  final theme = expressiveTestTheme(Brightness.light);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // 顶栏草稿角标：不打开真实数据库。
        diaryDraftCountProvider.overrideWith((ref) => Stream.value(0)),
        // 书架：没有日记本（不打开真实数据库）。
        notebooksProvider.overrideWith(
          (ref) => Stream.value(const <NotebookView>[]),
        ),
        settingsServiceProvider.overrideWith((ref) async => settings),
        tagListProvider.overrideWith((ref) => Stream.value(const <Tag>[_tag])),
        pagedDiariesProvider.overrideWith((ref, query) {
          PagedDiariesResult page(List<DiaryWithTags> items) =>
              PagedDiariesResult(
                items: items.take(query.limit).toList(),
                limit: query.limit,
                hasMore: false,
              );
          if (query.requiredTagIds.isEmpty) {
            return Stream.value(page(_diaries('Old', oldCount)));
          }
          return Stream.fromFuture(
            Future<PagedDiariesResult>.delayed(
              filteredDelay,
              () => page(_diaries('Fresh', freshCount)),
            ),
          );
        }),
      ],
      child: MaterialApp(
        theme: theme,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DiariesPage(pageBackgroundColor: theme.colorScheme.surface),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('Old'), findsOneWidget);
}

/// 标题为 [title] 的那一篇外面的切换包装。
Finder _revealOf(String title) => find
    .ancestor(
      of: find.text(title),
      matching: find.byType(DiaryListSwitchReveal),
    )
    .first;

/// [reveal] 此刻的不透明度（实色卡片：包装里最外层的 Opacity）。
double _opacityOf(WidgetTester tester, Finder reveal) => tester
    .widget<Opacity>(
      find.descendant(of: reveal, matching: find.byType(Opacity)).first,
    )
    .opacity;

/// [reveal] 此刻的位移。
Offset _offsetOf(WidgetTester tester, Finder reveal) {
  final translation = tester
      .widget<Transform>(
        find.descendant(of: reveal, matching: find.byType(Transform)).first,
      )
      .transform
      .getTranslation();
  return Offset(translation.x, translation.y);
}

/// 列表第一项此刻的不透明度（屏上没有列表项时为 0）。
double _listOpacity(WidgetTester tester) {
  final reveals = find.byType(DiaryListSwitchReveal);
  if (reveals.evaluate().isEmpty) {
    return 0;
  }
  return _opacityOf(tester, reveals.first);
}

final Finder _tagChip = find.descendant(
  of: find.byType(DiaryTagFilterBar),
  matching: find.text('Travel'),
);

Set<int> _selectedTagIds(WidgetTester tester) => tester
    .widget<DiaryTagFilterBar>(find.byType(DiaryTagFilterBar))
    .selectedTagFilterIds;

/// 逐帧推进 [frames] 帧，记录标题为 [title] 的那一篇出现时的位移。
Future<List<Offset>> _trackOffsets(
  WidgetTester tester,
  String title, {
  int frames = 50,
}) async {
  final offsets = <Offset>[];
  for (var frame = 0; frame < frames; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (find.text(title).evaluate().isNotEmpty) {
      offsets.add(_offsetOf(tester, _revealOf(title)));
    }
  }
  return offsets;
}

void main() {
  testWidgets('tag chip reflects its selection on the next frame', (
    tester,
  ) async {
    await _pumpPage(tester, filteredDelay: const Duration(milliseconds: 20));

    await tester.tap(_tagChip);
    await tester.pump(const Duration(milliseconds: 16));

    expect(_selectedTagIds(tester), contains(_tag.id));
    await tester.pumpAndSettle();
  });

  testWidgets('slow filter query never reveals the stale list again', (
    tester,
  ) async {
    await _pumpPage(tester, filteredDelay: const Duration(milliseconds: 400));

    await tester.tap(_tagChip);
    var exited = false;
    for (var frame = 0; frame < 60; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final opacity = _listOpacity(tester);
      if (opacity < 0.05) {
        exited = true;
      }
      if (exited && opacity > 0.05) {
        // 退场之后再次可见的必须是新筛选结果，而不是旧列表。
        expect(find.text('Old'), findsNothing, reason: 'frame $frame');
      }
    }
    await tester.pumpAndSettle();

    expect(exited, isTrue);
    expect(find.text('Fresh'), findsOneWidget);
    expect(_listOpacity(tester), 1);
  });

  testWidgets('rapid toggles settle on the latest filter result', (
    tester,
  ) async {
    await _pumpPage(tester, filteredDelay: const Duration(milliseconds: 200));

    await tester.tap(_tagChip);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(_tagChip);
    await tester.pump(const Duration(milliseconds: 16));
    expect(_selectedTagIds(tester), isEmpty);

    await tester.pumpAndSettle();
    expect(find.text('Old'), findsOneWidget);
    expect(find.text('Fresh'), findsNothing);
    expect(_listOpacity(tester), 1);
    expect(_offsetOf(tester, _revealOf('Old')), Offset.zero);
  });

  testWidgets('a tag to the right slides the old list left and the new one '
      'in from the right', (tester) async {
    await _pumpPage(tester, filteredDelay: const Duration(milliseconds: 20));

    await tester.tap(_tagChip);
    // 退场：旧列表往左走，不上下动。
    final exit = await _trackOffsets(tester, 'Old', frames: 8);
    expect(exit.any((offset) => offset.dx < -1), isTrue);
    expect(exit.every((offset) => offset.dx <= 0 && offset.dy == 0), isTrue);

    // 入场：新列表从右边进来，落定在原位。
    final enter = await _trackOffsets(tester, 'Fresh');
    expect(enter.first.dx, greaterThan(10));
    expect(enter.every((offset) => offset.dy == 0), isTrue);
    await tester.pumpAndSettle();
    expect(_offsetOf(tester, _revealOf('Fresh')), Offset.zero);
    expect(_opacityOf(tester, _revealOf('Fresh')), 1);
  });

  testWidgets('deselecting the tag brings the list in from the left', (
    tester,
  ) async {
    await _pumpPage(tester, filteredDelay: const Duration(milliseconds: 20));
    await tester.tap(_tagChip);
    await tester.pumpAndSettle();
    expect(find.text('Fresh'), findsOneWidget);

    // 单选模式下再点一次选中的标签：回到最左端的“全部”。
    await tester.tap(_tagChip);
    final enter = await _trackOffsets(tester, 'Old');
    expect(enter.first.dx, lessThan(-10));
    await tester.pumpAndSettle();
    expect(_offsetOf(tester, _revealOf('Old')), Offset.zero);
  });

  testWidgets('long-press multi-select rises the list vertically', (
    tester,
  ) async {
    await _pumpPage(tester, filteredDelay: const Duration(milliseconds: 20));

    await tester.longPress(_tagChip);
    final enter = await _trackOffsets(tester, 'Fresh');
    expect(enter.first.dy, greaterThan(5));
    expect(enter.every((offset) => offset.dx == 0), isTrue);
    await tester.pumpAndSettle();
    expect(_offsetOf(tester, _revealOf('Fresh')), Offset.zero);
  });

  testWidgets('new cards cascade in from top to bottom', (tester) async {
    await _pumpPage(
      tester,
      filteredDelay: const Duration(milliseconds: 20),
      freshCount: 3,
    );

    await tester.tap(_tagChip);
    var sawStagger = false;
    for (var frame = 0; frame < 50; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('Fresh 1').evaluate().isEmpty) {
        continue;
      }
      final first = _opacityOf(tester, _revealOf('Fresh'));
      final second = _opacityOf(tester, _revealOf('Fresh 1'));
      // 后一张从不先于前一张显现。
      expect(second, lessThanOrEqualTo(first), reason: 'frame $frame');
      if (first > 0 && first < 1 && second < first) {
        sawStagger = true;
      }
    }
    expect(sawStagger, isTrue);
    await tester.pumpAndSettle();
    expect(_opacityOf(tester, _revealOf('Fresh 2')), 1);
  });

  testWidgets('reduce motion swaps the list in place without moving it', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      filteredDelay: const Duration(milliseconds: 20),
      reduceMotion: true,
    );

    await tester.tap(_tagChip);
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final title = find.text('Fresh').evaluate().isNotEmpty ? 'Fresh' : 'Old';
      expect(_offsetOf(tester, _revealOf(title)), Offset.zero);
      expect(_opacityOf(tester, _revealOf(title)), 1);
    }
    await tester.pumpAndSettle();
    expect(find.text('Fresh'), findsOneWidget);
  });

  for (final peekMasthead in <bool>[false, true]) {
    testWidgets('switching tags deep in the list lands at the new list start '
        'without moving the tag bar (masthead peeking: $peekMasthead)', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        filteredDelay: const Duration(milliseconds: 20),
        oldCount: 20,
        freshCount: 20,
      );
      final scrollable = find.byType(Scrollable).first;
      // 往下滚很远：浮动刊头收起。
      await tester.drag(scrollable, const Offset(0, -1500));
      await tester.pumpAndSettle();
      if (peekMasthead) {
        // 再往上拉一点：刊头露出一截，且“上一次开始滚动”的方向是向上——
        // 直接向上大跳会把刊头整个拉出来。
        await tester.drag(scrollable, const Offset(0, 24));
        await tester.pumpAndSettle();
      }
      final barTop = tester.getTopLeft(find.byType(DiaryTagFilterBar)).dy;
      final barBottom = tester.getBottomLeft(find.byType(DiaryTagFilterBar)).dy;

      await tester.tap(_tagChip);
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.byType(DiaryTagFilterBar)).dy, barTop);
      // 新列表的第一张卡片就在标签栏下方。
      final firstCard = tester.getTopLeft(_revealOf('Fresh')).dy;
      expect(firstCard, greaterThanOrEqualTo(barBottom - 0.5));
      expect(firstCard, lessThan(barBottom + 24));
    });
  }

  testWidgets('the multi-select clear button is announced as a button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpPage(tester, filteredDelay: const Duration(milliseconds: 20));
    // ✕ 只在多选模式出现：长按进入。
    await tester.longPress(_tagChip);
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.bySemanticsLabel('Clear tag filters')),
      isSemantics(isButton: true, hasTapAction: true),
    );
    semantics.dispose();
  });

  testWidgets('switching layout exits before the grid replaces the list', (
    tester,
  ) async {
    await _pumpPage(tester, filteredDelay: const Duration(milliseconds: 20));
    final l10n = tester.element(find.byType(DiariesPage)).l10n;

    await tester.tap(find.byTooltip(l10n.autoT0125));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.autoT0145));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.autoT0147));

    var sawListExiting = false;
    var gridAppeared = false;
    for (var frame = 0; frame < 40 && !gridAppeared; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final grid = find.byType(SliverMasonryGrid).evaluate().isNotEmpty;
      final opacity = _listOpacity(tester);
      if (!grid && opacity < 1) {
        sawListExiting = true;
      }
      if (grid) {
        gridAppeared = true;
        // 布局只在旧列表退场到底之后才切换，而不是先硬切再补退场。
        expect(opacity, lessThan(0.05), reason: 'frame $frame');
      }
    }
    expect(sawListExiting, isTrue);
    expect(gridAppeared, isTrue);
    await tester.pumpAndSettle();
    expect(_listOpacity(tester), 1);
    expect(find.text('Old'), findsOneWidget);
  });

  testWidgets(
    'the more menu and its submenu appear in place under reduce motion',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _pumpPage(tester, filteredDelay: const Duration(milliseconds: 20));
      final l10n = tester.element(find.byType(DiariesPage)).l10n;

      await tester.tap(find.byTooltip(l10n.autoT0125));
      await tester.pump();
      await tester.pump();
      final settledTop = tester.getTopLeft(find.text(l10n.autoT0141)).dy;
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getTopLeft(find.text(l10n.autoT0141)).dy, settledTop);

      // 下钻到“显示布局”：新一页不横移、面板尺寸不过渡。
      await tester.tap(find.text(l10n.autoT0145));
      // MenuItemButton 在帧尾才执行 onPressed，换页在下一帧。
      await tester.pump();
      await tester.pump();
      final listItem = find.text(l10n.autoT0146);
      final settledItem = tester.getTopLeft(listItem);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getTopLeft(listItem), settledItem);
      await tester.pumpAndSettle();
    },
  );
}

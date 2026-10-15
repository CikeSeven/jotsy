import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 卡片 id/标题带上排序模式名：能直接看出列表换成了哪次查询的结果，也避免
/// 卡片派生数据的 LRU 缓存在不同模式之间串用。
DiaryWithTags _diary(DiarySortMode mode, int index) => DiaryWithTags(
  diary: Diary(
    id: mode.index * 100 + index,
    diaryId: '${mode.name}-$index',
    title: '${mode.name} $index',
    content: '[{"insert":"Content\\n"}]',
    contentText: 'Content',
    metadata: '{}',
    createdAt: DateTime(2026, 10, 4),
    updatedAt: DateTime(2026, 10, 4),
    isArchived: false,
    isPinned: false,
    isDeleted: false,
  ),
  tags: const <Tag>[],
);

/// 挂载日记页：每次分页查询记录其排序模式，并返回 30 条足以滚动的结果。
Future<SettingsService> _pumpPage(
  WidgetTester tester, {
  required List<DiarySortMode> queriedSorts,
}) async {
  tester.view.physicalSize = const Size(390, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final settings = await SettingsService.create();
  final theme = expressiveTestTheme(Brightness.light);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsServiceProvider.overrideWith((ref) async => settings),
        tagListProvider.overrideWith((ref) => Stream.value(const <Tag>[])),
        pagedDiariesProvider.overrideWith((ref, query) {
          queriedSorts.add(query.sortMode);
          return Stream.value(
            PagedDiariesResult(
              items: List<DiaryWithTags>.generate(
                30,
                (int index) => _diary(query.sortMode, index + 1),
              ),
              limit: query.limit,
              hasMore: false,
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
  return settings;
}

double _listOffset(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position
    .pixels;

/// 往回拖动并逐步出帧。
///
/// 浮动顶栏只在布局时滚动方向为“向前”才展开；`tester.drag` 的移动与抬起
/// 之间不出帧，布局时方向已回到 idle，顶栏不会露出（真机拖动每帧都布局）。
Future<void> _dragBackWithFrames(WidgetTester tester) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(CustomScrollView)),
  );
  for (var step = 0; step < 4; step++) {
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  for (final reduceMotion in <bool>[false, true]) {
    testWidgets(
      'changing the sort restarts the list from the top and is remembered'
      '${reduceMotion ? ' (reduce motion)' : ''}',
      (tester) async {
        if (reduceMotion) {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
        }
        final queried = <DiarySortMode>[];
        final settings = await _pumpPage(tester, queriedSorts: queried);
        expect(queried.last, DiarySortMode.updatedDesc);
        final l10n = tester.element(find.byType(DiariesPage)).l10n;

        // 先滚到列表深处，再往回拖一点让浮动顶栏露出“更多”按钮。
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -2400),
        );
        await tester.pumpAndSettle();
        await _dragBackWithFrames(tester);
        expect(_listOffset(tester), greaterThan(1000));

        await tester.tap(find.byTooltip(l10n.autoT0125));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.diarySortFieldPublished));
        await tester.pumpAndSettle();

        expect(queried.last, DiarySortMode.createdDesc);
        expect(settings.diarySortModeRaw, 'createdDesc');
        // 新顺序从头展示，而不是停在旧位置对应的新顺序中段。
        expect(_listOffset(tester), 0);
        expect(find.text('createdDesc 1'), findsOneWidget);
        expect(find.text('updatedDesc 1'), findsNothing);

        // 面板保持打开，可以接着切换正/倒序。
        await tester.tap(find.text(l10n.diarySortAscending));
        await tester.pumpAndSettle();
        expect(queried.last, DiarySortMode.createdAsc);
        expect(settings.diarySortModeRaw, 'createdAsc');
        expect(find.text('createdAsc 1'), findsOneWidget);
      },
    );
  }
}

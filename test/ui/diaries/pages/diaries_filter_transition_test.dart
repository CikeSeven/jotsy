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

/// 无筛选时立即返回旧列表；带标签筛选时模拟数据库延迟 [filteredDelay]。
Future<void> _pumpPage(
  WidgetTester tester, {
  required Duration filteredDelay,
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
                items: items,
                limit: query.limit,
                hasMore: false,
              );
          if (query.requiredTagIds.isEmpty) {
            return Stream.value(page(<DiaryWithTags>[_diary('old', 'Old')]));
          }
          return Stream.fromFuture(
            Future<PagedDiariesResult>.delayed(
              filteredDelay,
              () => page(<DiaryWithTags>[_diary('new', 'Fresh')]),
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

double _listOpacity(WidgetTester tester) => tester
    .widget<SliverFadeTransition>(find.byType(SliverFadeTransition))
    .opacity
    .value;

final Finder _tagChip = find.descendant(
  of: find.byType(DiaryTagFilterBar),
  matching: find.text('Travel'),
);

Set<int> _selectedTagIds(WidgetTester tester) => tester
    .widget<DiaryTagFilterBar>(find.byType(DiaryTagFilterBar))
    .selectedTagFilterIds;

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

  testWidgets('slow filter query never fades the stale list back in', (
    tester,
  ) async {
    await _pumpPage(tester, filteredDelay: const Duration(milliseconds: 400));

    await tester.tap(_tagChip);
    var fadedOut = false;
    for (var frame = 0; frame < 60; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final opacity = _listOpacity(tester);
      if (opacity < 0.05) {
        fadedOut = true;
      }
      if (fadedOut && opacity > 0.05) {
        // 淡出之后再次可见的必须是新筛选结果，而不是旧列表。
        expect(find.text('Old'), findsNothing, reason: 'frame $frame');
      }
    }
    await tester.pumpAndSettle();

    expect(fadedOut, isTrue);
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
  });

  testWidgets('tag filter clear button is announced as a button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpPage(tester, filteredDelay: const Duration(milliseconds: 20));

    expect(
      tester.getSemantics(find.bySemanticsLabel('Clear tag filters')),
      isSemantics(isButton: true, hasTapAction: true),
    );
    semantics.dispose();
  });

  testWidgets('switching layout fades out before the grid replaces the list', (
    tester,
  ) async {
    await _pumpPage(tester, filteredDelay: const Duration(milliseconds: 20));
    final l10n = tester.element(find.byType(DiariesPage)).l10n;

    await tester.tap(find.byTooltip(l10n.autoT0125));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.autoT0147));

    var sawListFading = false;
    var gridAppeared = false;
    for (var frame = 0; frame < 40 && !gridAppeared; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final grid = find.byType(SliverMasonryGrid).evaluate().isNotEmpty;
      final opacity = _listOpacity(tester);
      if (!grid && opacity < 1) {
        sawListFading = true;
      }
      if (grid) {
        gridAppeared = true;
        // 布局只在旧列表淡到底之后才切换，而不是先硬切再补淡出。
        expect(opacity, lessThan(0.05), reason: 'frame $frame');
      }
    }
    expect(sawListFading, isTrue);
    expect(gridAppeared, isTrue);
    await tester.pumpAndSettle();
    expect(_listOpacity(tester), 1);
    expect(find.text('Old'), findsOneWidget);
  });

  testWidgets('the view sheet appears without sliding under reduce motion', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pumpPage(tester, filteredDelay: const Duration(milliseconds: 20));
    final l10n = tester.element(find.byType(DiariesPage)).l10n;

    await tester.tap(find.byTooltip(l10n.autoT0125));
    await tester.pump();
    await tester.pump();
    final settledTop = tester.getTopLeft(find.text(l10n.autoT0141)).dy;
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getTopLeft(find.text(l10n.autoT0141)).dy, settledTop);
    await tester.pumpAndSettle();
  });
}

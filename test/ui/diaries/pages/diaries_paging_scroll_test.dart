import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_draft_providers.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/diaries/providers/diary_timeline_provider.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';
import 'package:node_diary/ui/notebooks/providers/notebook_providers.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final layout in DiaryLayoutMode.values) {
      testWidgets(
        '${layout.name} pagination preserves a fast downward scroll in ${brightness.name} mode',
        (tester) async {
          final nextPage = Completer<void>();
          final queriedLimits = <int>[];
          await _pumpPage(
            tester,
            brightness: brightness,
            layout: layout,
            nextPage: nextPage.future,
            queriedLimits: queriedLimits,
          );
          final position = _position(tester);

          // 先快速滑到第一页末尾附近，让下一页在惯性滚动期间返回。
          await tester.fling(
            find.byType(CustomScrollView),
            Offset(0, -(position.maxScrollExtent - 200)),
            6000,
          );
          await tester.pump();
          expect(queriedLimits.last, greaterThan(diaryFirstPageSize));
          var previousOffset = position.pixels;
          expect(previousOffset, greaterThan(500));

          nextPage.complete();
          for (var frame = 0; frame < 8; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(
              position.pixels,
              greaterThanOrEqualTo(previousOffset - 1),
              reason: 'Appending a page must not scroll back (frame $frame)',
            );
            previousOffset = position.pixels;
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('a slow final waterfall page keeps the visible cards in place', (
    tester,
  ) async {
    final nextPage = Completer<void>();
    final queriedLimits = <int>[];
    await _pumpPage(
      tester,
      brightness: Brightness.light,
      layout: DiaryLayoutMode.waterfall,
      nextPage: nextPage.future,
      queriedLimits: queriedLimits,
      diaryCount: 25,
    );
    final position = _position(tester);
    position.jumpTo(position.maxScrollExtent - 200);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(queriedLimits.last, 40);
    expect(
      find.byType(ExpressiveLoadingIndicator, skipOffstage: false),
      findsOneWidget,
    );
    final offsetBefore = position.pixels;
    final anchor = find.text('Diary 15');
    expect(anchor, findsOneWidget);
    final anchorBefore = tester.getTopLeft(anchor);

    nextPage.complete();
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(offsetBefore, 1));
    expect(tester.getTopLeft(anchor), anchorBefore);
    expect(
      find.byType(ExpressiveLoadingIndicator, skipOffstage: false),
      findsNothing,
    );

    // 最后一页只有 5 篇，抵达末尾后不应继续发起分页或残留加载状态。
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.text('Diary 24'), findsOneWidget);
    expect(queriedLimits, <int>[20, 40]);
    expect(tester.takeException(), isNull);
  });
}

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

Future<void> _pumpPage(
  WidgetTester tester, {
  required Brightness brightness,
  required DiaryLayoutMode layout,
  required Future<void> nextPage,
  required List<int> queriedLimits,
  int diaryCount = 65,
}) async {
  tester.view.physicalSize = const Size(390, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final settings = await SettingsService.create();
  await settings.setDiaryLayoutModeRaw(layout.name);
  final all = List<DiaryWithTags>.generate(diaryCount, _diary);
  final theme = expressiveTestTheme(
    brightness,
  ).copyWith(platform: TargetPlatform.android);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        diaryDraftCountProvider.overrideWith((ref) => Stream.value(0)),
        notebooksProvider.overrideWith(
          (ref) => Stream.value(const <NotebookView>[]),
        ),
        settingsServiceProvider.overrideWith((ref) async => settings),
        tagListProvider.overrideWith((ref) => Stream.value(const <Tag>[])),
        // 快速滚动条的完整时间轴：不打开真实数据库。
        diaryTimelineProvider.overrideWith(
          (ref, query) => Stream.value(const <DiaryTimelineEntry>[]),
        ),
        pagedDiariesProvider.overrideWith((ref, query) {
          queriedLimits.add(query.limit);
          final page = PagedDiariesResult(
            items: all.take(query.limit).toList(),
            limit: query.limit,
            hasMore: all.length > query.limit,
          );
          return query.limit == diaryFirstPageSize
              ? Stream.value(page)
              : Stream.fromFuture(nextPage.then((_) => page));
        }),
      ],
      child: MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DiariesPage(pageBackgroundColor: theme.colorScheme.surface),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

DiaryWithTags _diary(int index) => DiaryWithTags(
  diary: Diary(
    id: index + 1,
    diaryId: 'diary-$index',
    title: 'Diary $index',
    content: '[{"insert":"Content\\n"}]',
    contentText: List.filled(index % 4 + 1, 'Diary content.').join(' '),
    metadata: '{}',
    createdAt: DateTime(2026, 10, 4),
    updatedAt: DateTime(2026, 10, 4),
    isArchived: false,
    isPinned: false,
    isDeleted: false,
  ),
  tags: const <Tag>[],
);

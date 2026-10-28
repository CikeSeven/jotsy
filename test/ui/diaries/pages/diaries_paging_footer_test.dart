import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/diaries/providers/diary_timeline_provider.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';
import 'package:node_diary/ui/diaries/providers/diary_draft_providers.dart';
import 'package:node_diary/ui/notebooks/providers/notebook_providers.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

DiaryWithTags _diary(int index) => DiaryWithTags(
  diary: Diary(
    id: index,
    diaryId: 'diary-$index',
    title: 'Diary $index',
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

void main() {
  testWidgets('idle footer stays still and clears once the last page arrives', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await SettingsService.create();
    final all = List<DiaryWithTags>.generate(25, (i) => _diary(i + 1));
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
          tagListProvider.overrideWith((ref) => Stream.value(const <Tag>[])),
          // 快速滚动条的完整时间轴：不打开真实数据库。
          diaryTimelineProvider.overrideWith(
            (ref, query) => Stream.value(const <DiaryTimelineEntry>[]),
          ),
          pagedDiariesProvider.overrideWith(
            (ref, query) => Stream.value(
              PagedDiariesResult(
                items: all.take(query.limit).toList(),
                limit: query.limit,
                hasMore: all.length > query.limit,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiariesPage(pageBackgroundColor: theme.colorScheme.surface),
        ),
      ),
    );
    // 第一页仍有更多数据，但下一页并未在加载：底部只保留固定高度的槽位，
    // 不再挂一个常驻循环的指示器，列表静止时不再持续出帧。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byType(ExpressiveLoadingIndicator, skipOffstage: false),
      findsNothing,
    );
    // 首屏入场动画收尾后不再排帧（此前常驻指示器让列表永远“动着”）。
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.hasScheduledFrame, isFalse);

    // 滚到底触发加载第二页（25 条，hasMore = false）。用瞬时 drag 而非
    // fling：fling 会按手势时长推进时钟，掩盖冷却期内的闪烁。
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    // 第二页已到达后再瞬时拖到最底，确保若有分页指示器必在视口内。
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Diary 25'), findsOneWidget);
    // 已无更多数据：底部不应残留分页加载指示器（此前冷却期还会闪 140ms）。
    expect(
      find.byType(ExpressiveLoadingIndicator, skipOffstage: false),
      findsNothing,
    );
    await tester.pump(const Duration(seconds: 1));
  });
}

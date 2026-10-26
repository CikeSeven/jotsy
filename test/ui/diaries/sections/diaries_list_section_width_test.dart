import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style.dart';
import 'package:node_diary/ui/diaries/sections/diaries_list_section.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';
import 'package:node_diary/ui/diaries/widgets/diary_card/diary_card.dart';

import '../../../support/expressive_test_theme.dart';

/// 每个用例用不同的 id 前缀：卡片派生数据按 (diaryId, updatedAt) 缓存。
List<DiaryWithTags> _diaries(String prefix) => List<DiaryWithTags>.generate(
  4,
  (int index) => DiaryWithTags(
    diary: Diary(
      id: index + 1,
      diaryId: '$prefix-$index',
      title: '$prefix $index',
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
  ),
);

/// 在 1280 宽的窗口里放一列 [width] 宽的列表。
Future<void> _pump(
  WidgetTester tester, {
  required String prefix,
  required DiaryLayoutMode layoutMode,
  required double width,
  double? availableWidth,
  int minWaterfallColumns = 0,
  DiaryCardStyle style = DiaryCardStyle.defaults,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: expressiveTestTheme(Brightness.light),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: CustomScrollView(
              slivers: <Widget>[
                DiariesListSection(
                  diaries: _diaries(prefix),
                  layoutMode: layoutMode,
                  selectedDiaryIds: const <String>{},
                  isSelectionMode: false,
                  maxVisibleTags: SettingsService.defaultDiaryCardTagLimit,
                  cardStyle: style,
                  onCreate: () {},
                  onOpenEditor: (_, _) {},
                  onToggleSelection: (_, _) {},
                  availableWidth: availableWidth,
                  minWaterfallColumns: minWaterfallColumns,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

DiaryCard _firstCard(WidgetTester tester) =>
    tester.widget<DiaryCard>(find.byType(DiaryCard).first);

void main() {
  testWidgets('card styles resolve from the width given to the list', (
    tester,
  ) async {
    // 三列瀑布流在 300 宽里放不下（单列不足 104），按可用宽度减为两列；
    // 只看窗口宽度时会误以为放得下三列。
    final threeColumns = DiaryCardStyle.defaults.copyWith(
      waterfall: DiaryCardStyle.defaults.waterfall.copyWith(columns: 3),
    );
    await _pump(
      tester,
      prefix: 'narrow-waterfall',
      layoutMode: DiaryLayoutMode.waterfall,
      width: 300,
      availableWidth: 300,
      style: threeColumns,
    );
    expect(_firstCard(tester).resolved.screenWidth, 300);
    expect(_firstCard(tester).resolved.columns, 2);

    // 列表侧边封面按可用宽度给文字列让位（按窗口宽度不会缩小）。
    await _pump(
      tester,
      prefix: 'narrow-list',
      layoutMode: DiaryLayoutMode.list,
      width: 280,
      availableWidth: 280,
    );
    expect(
      _firstCard(tester).resolved.sideCoverSize.width,
      lessThan(DiaryCardStyle.defaults.list.coverSide),
    );
  });

  testWidgets('without an explicit width the list falls back to the window', (
    tester,
  ) async {
    await _pump(
      tester,
      prefix: 'fallback',
      layoutMode: DiaryLayoutMode.list,
      width: 280,
    );
    expect(_firstCard(tester).resolved.screenWidth, 1280);
  });

  testWidgets('a wide waterfall adds columns up to the minimum asked for', (
    tester,
  ) async {
    await _pump(
      tester,
      prefix: 'wide-waterfall',
      layoutMode: DiaryLayoutMode.waterfall,
      width: 1200,
      availableWidth: 1200,
      minWaterfallColumns: 3,
    );
    expect(_firstCard(tester).resolved.columns, 3);
    final cards = find.byType(DiaryCard);
    final firstRow = <double>{
      for (var index = 0; index < 3; index++)
        tester.getTopLeft(cards.at(index)).dx,
    };
    expect(firstRow, hasLength(3));
  });
}

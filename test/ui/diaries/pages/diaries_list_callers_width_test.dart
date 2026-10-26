import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_cards_sliver.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style.dart';
import 'package:node_diary/ui/diaries/pages/archived_diaries_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_card/diary_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';
import 'diaries_wide_test_support.dart';

/// 复用日记列表的其他页面按自己那一列的实际宽度解析卡片样式。
double _resolvedWidth(WidgetTester tester) =>
    tester.widget<DiaryCard>(find.byType(DiaryCard).first).resolved.screenWidth;

Future<void> _pumpArchive(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(database.close);
  final settings = await SettingsService.create();
  final id = await database.createDiary(
    title: 'Archived ${size.width}',
    contentDocJson: '[{"insert":"body\\n"}]',
    contentText: 'body',
    metadataJson: '{}',
  );
  await database.archiveDiary(id);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ArchivedDiariesPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

void main() {
  final sideMargin = DiaryCardStyle.defaults.list.sideMargin;

  testWidgets('archived cards are styled from the centred column width', (
    tester,
  ) async {
    await _pumpArchive(tester, const Size(1280, 800));
    // 卡片可见边缘占满 720 的一列，加上卡片自带的左右边距。
    expect(_resolvedWidth(tester), 720 + sideMargin * 2);
    await _unmount(tester);
  });

  testWidgets('archived cards on a phone still use the full width', (
    tester,
  ) async {
    await _pumpArchive(tester, const Size(400, 860));
    expect(_resolvedWidth(tester), 400);
    await _unmount(tester);
  });

  testWidgets('calendar day cards are styled from their column width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final diaries = <DiaryWithTags>[
      for (var index = 0; index < 12; index++) wideDiary('calendar', index),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(
            slivers: <Widget>[
              // 像日历双栏的右栏：右侧留白后剩 780 宽。
              SliverPadding(
                padding: const EdgeInsets.only(right: 500),
                sliver: CalendarDayCardsSliver(
                  day: DateTime(2026, 10, 20),
                  diaries: diaries,
                  maxVisibleTags: SettingsService.defaultDiaryCardTagLimit,
                  onOpenDiary: (_, _) {},
                  onCreate: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(_resolvedWidth(tester), 780);

    // 滚动不改变宽度，也不重新解析。
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(_resolvedWidth(tester), 780);
  });
}

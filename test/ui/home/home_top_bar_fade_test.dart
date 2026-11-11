import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/node_diary_app.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_header.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';
import 'package:node_diary/ui/diaries/widgets/diary_tag_filter_bar.dart';
import 'package:node_diary/ui/explore/pages/explore_page.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_metrics.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_settings.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';
import 'package:node_diary/ui/home/pages/home_page.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_bottom_bar.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_top_bar_surface.dart';
import 'package:node_diary/ui/widgets/glass/glass_bottom_fade_painter.dart';
import 'package:node_diary/ui/widgets/page_header.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 首页各 Tab 的顶栏在真实页面里都接上了底缘渐隐：玻璃越往下越透明，到
/// 顶栏下缘消失。重点是日记页——顶栏由刊头与标签栏两片玻璃拼成，渐隐要
/// 跨过接缝连续，并跟着刊头收起。渐隐本身的像素见
/// test/ui/widgets/glass/glass_bottom_fade_test.dart。

const double _width = 480;
const double _height = 900;
const double _statusBar = 24;

Future<void> _pumpHome(WidgetTester tester, {String? barStyleRaw}) async {
  tester.view.physicalSize = const Size(_width, _height);
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = const FakeViewPadding(top: _statusBar);
  tester.view.padding = const FakeViewPadding(top: _statusBar);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{
    'app.settings.home_bar_style': ?barStyleRaw,
  });
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(database.close);
  final settings = await SettingsService.create();
  await tester.runAsync(() async {
    for (var i = 0; i < 12; i++) {
      await database.createDiary(
        title: 'Diary $i',
        contentDocJson: '[{"insert":"content $i\\n"}]',
        contentText: 'content $i',
        metadataJson: '{}',
      );
    }
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
      child: const NodeDiaryApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pumpAndSettle();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(HomeBottomBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

/// 包着 [content] 的那片顶栏玻璃。
Finder _surfaceOf(Finder content) =>
    find.ancestor(of: content, matching: find.byType(HomeTopBarSurface)).first;

/// [surface] 的渐隐画笔；不渐隐时为 null。
GlassBottomFadePainter? _fade(WidgetTester tester, Finder surface) {
  final paints = find.descendant(
    of: surface,
    matching: find.byType(CustomPaint),
  );
  for (final paint in tester.widgetList<CustomPaint>(paints)) {
    final painter = paint.painter;
    if (painter is GlassBottomFadePainter) return painter;
  }
  return null;
}

void main() {
  testWidgets('every tab fades its top bar over the same extent', (
    tester,
  ) async {
    await _pumpHome(tester);
    final l10n = tester.element(find.byType(HomePage)).l10n;

    final tagBar = _surfaceOf(find.byType(DiaryTagFilterBar));
    expect(_fade(tester, tagBar)?.extent, HomeBarMetrics.topBarFadeExtent);

    await _openTab(tester, l10n.navCalendar);
    final calendar = _surfaceOf(find.byType(CalendarMonthBar));
    expect(_fade(tester, calendar)?.extent, HomeBarMetrics.topBarFadeExtent);
    // 单片顶栏：渐隐按自己的下缘对齐，月份行收起时跟着页头的高度走。
    expect(_fade(tester, calendar)?.trailing, isNull);

    await _openTab(tester, l10n.navExplore);
    final explore = find.descendant(
      of: find.byType(ExplorePage),
      matching: find.byType(HomeTopBarSurface),
    );
    expect(
      find.descendant(
        of: find.byType(ExplorePage),
        matching: find.byType(PageHeader),
      ),
      findsOneWidget,
    );
    expect(_fade(tester, explore)?.extent, HomeBarMetrics.topBarFadeExtent);
    await _unmount(tester);
  });

  testWidgets('the diaries fade runs across the masthead and the tag bar', (
    tester,
  ) async {
    await _pumpHome(tester);
    final masthead = _surfaceOf(find.byType(DiaryHeadSection));
    final tagBar = _surfaceOf(find.byType(DiaryTagFilterBar));
    expect(tester.widget(masthead), isNot(same(tester.widget(tagBar))));

    // 没有标签时标签栏只剩上下留白，比渐隐区矮得多：渐隐必须接着画进刊头，
    // 否则会断在两片的接缝上。
    final tagBarHeight = tester.getSize(tagBar).height;
    expect(tagBarHeight, lessThan(HomeBarMetrics.topBarFadeExtent));
    final upper = _fade(tester, masthead)!;
    expect(upper.extent, HomeBarMetrics.topBarFadeExtent);
    expect(upper.trailing?.value, tagBarHeight);
    // 标签栏紧贴在刊头下面：两片的渐隐按同一条下缘对齐。
    expect(tester.getRect(tagBar).top, tester.getRect(masthead).bottom);
    expect(_fade(tester, tagBar)!.trailing, isNull);

    // 下滑：刊头收起到只剩状态栏那一条，渐隐仍贴着标签栏的下缘。
    await tester.drag(find.byType(DiariesPage), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getRect(masthead).bottom, _statusBar);
    expect(tester.getRect(tagBar).top, _statusBar);
    expect(_fade(tester, masthead)!.trailing?.value, tagBarHeight);
    expect(_fade(tester, tagBar), isNotNull);
    await _unmount(tester);
  });

  testWidgets('the top bar hairline keeps a crisp edge on every piece', (
    tester,
  ) async {
    final raw = const HomeBarSettings(
      current: HomeBarStyle(topBarHairline: true),
    ).encode();
    await _pumpHome(tester, barStyleRaw: raw);
    final masthead = _surfaceOf(find.byType(DiaryHeadSection));
    final tagBar = _surfaceOf(find.byType(DiaryTagFilterBar));
    expect(_fade(tester, masthead), isNull);
    expect(_fade(tester, tagBar), isNull);
    await _unmount(tester);
  });
}

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
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_settings.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';
import 'package:node_diary/ui/home/pages/home_page.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_bottom_bar.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_top_bar_surface.dart';
import 'package:node_diary/ui/widgets/glass/glass_bottom_fade_painter.dart';
import 'package:node_diary/ui/widgets/page_header.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 首页各 Tab 的顶栏在真实页面里都接上了自上而下的渐变：玻璃露出来的
/// 上半截完整、下半截淡到下缘消失。重点是日记页——顶栏由刊头与标签栏两片
/// 拼成，整条顶栏只有标签栏画的那一块玻璃，往上铺到刊头之后；刊头把自己
/// 此刻的高度报给它，渐变跟着刊头收起。渐变本身的像素见
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

/// 包着 [content] 的那片顶栏。
Finder _surfaceOf(Finder content) =>
    find.ancestor(of: content, matching: find.byType(HomeTopBarSurface)).first;

/// [surface] 的玻璃画笔；这一片不画玻璃时为 null。
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

/// [surface] 的玻璃实际铺开的范围。
Rect _glassOf(WidgetTester tester, Finder surface) => tester.getRect(
  find.descendant(of: surface, matching: find.byType(BackdropFilter)),
);

/// [surface] 自上而下渐变，渐变在它自己的下缘结束（不往外挂）。
void _expectFades(WidgetTester tester, Finder surface) {
  expect(_fade(tester, surface)?.fade, isTrue);
  expect(_glassOf(tester, surface).bottom, tester.getRect(surface).bottom);
}

void main() {
  testWidgets('every tab fades its top bar from top to bottom', (tester) async {
    await _pumpHome(tester);
    final l10n = tester.element(find.byType(HomePage)).l10n;

    _expectFades(tester, _surfaceOf(find.byType(DiaryTagFilterBar)));

    await _openTab(tester, l10n.navCalendar);
    final calendar = _surfaceOf(find.byType(CalendarMonthBar));
    _expectFades(tester, calendar);
    // 单片顶栏：玻璃就是它自己的范围，不往上多铺。
    expect(_glassOf(tester, calendar).top, tester.getRect(calendar).top);

    await _openTab(tester, l10n.navExplore);
    expect(
      find.descendant(
        of: find.byType(ExplorePage),
        matching: find.byType(PageHeader),
      ),
      findsOneWidget,
    );
    _expectFades(
      tester,
      find.descendant(
        of: find.byType(ExplorePage),
        matching: find.byType(HomeTopBarSurface),
      ),
    );
    await _unmount(tester);
  });

  testWidgets('the diaries glass reaches behind the masthead as it collapses', (
    tester,
  ) async {
    await _pumpHome(tester);
    final masthead = _surfaceOf(find.byType(DiaryHeadSection));
    final tagBar = _surfaceOf(find.byType(DiaryTagFilterBar));
    expect(tester.widget(masthead), isNot(same(tester.widget(tagBar))));
    // 刊头只画内容，玻璃由标签栏这一块从屏幕顶端铺下来；刊头把自己的高度
    // 报给它，渐变从刊头露出来的上缘起算。
    expect(_fade(tester, masthead), isNull);
    expect(tester.getRect(tagBar).top, tester.getRect(masthead).bottom);
    expect(_glassOf(tester, tagBar).top, lessThanOrEqualTo(0));
    _expectFades(tester, tagBar);
    final painter = _fade(tester, tagBar)!;
    expect(painter.visibleOverhang?.value, tester.getRect(masthead).height);

    // 下滑：刊头收起到只剩状态栏那一条，玻璃仍从屏幕顶端铺到标签栏下缘，
    // 渐变按此刻露出的高度（状态栏 + 标签栏）铺。
    await tester.drag(find.byType(DiariesPage), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getRect(masthead).bottom, _statusBar);
    expect(tester.getRect(tagBar).top, _statusBar);
    expect(_glassOf(tester, tagBar).top, lessThanOrEqualTo(0));
    _expectFades(tester, tagBar);
    expect(_fade(tester, tagBar)!.visibleOverhang?.value, _statusBar);
    await _unmount(tester);
  });

  testWidgets('the top bar hairline keeps a crisp edge', (tester) async {
    final raw = const HomeBarSettings(
      current: HomeBarStyle(topBarHairline: true),
    ).encode();
    await _pumpHome(tester, barStyleRaw: raw);
    final tagBar = _surfaceOf(find.byType(DiaryTagFilterBar));
    expect(_fade(tester, tagBar)?.fade, isFalse);
    expect(_fade(tester, _surfaceOf(find.byType(DiaryHeadSection))), isNull);
    await _unmount(tester);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/theme.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/app_surface/models/app_glass_style.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_scope.dart';
import 'package:node_diary/ui/diaries/models/diary_mood_palette.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_style.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_preview_resolved_style.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_host.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_top_bar.dart';
import 'package:node_diary/ui/widgets/floating_top_bar/floating_action_island.dart';
import 'package:node_diary/ui/widgets/floating_top_bar/floating_island.dart';
import 'package:node_diary/ui/widgets/floating_top_bar/floating_top_bar.dart';
import 'package:node_diary/ui/widgets/glass/glass_surface.dart';

const Color _paper = Color(0xFFFFF8E1);
const Color _appSeed = Color(0xFF3B6CB7);
const double _statusBar = 24;

Diary _diary({String title = '雨后的小巷'}) {
  final at = DateTime(2026, 5, 3, 9);
  return Diary(
    id: 1,
    diaryId: 'd1',
    title: title,
    content: '',
    contentText: '',
    metadata: '{}',
    createdAt: at,
    updatedAt: at,
    isPinned: false,
    isArchived: false,
    isDeleted: false,
  );
}

/// 一篇预览的滚动结构：顶端留出状态栏与浮岛，页头 200 高（末尾是锚点），
/// 下面是长正文。
Widget _page({
  AppGlassStyle style = const AppGlassStyle(),
  DiaryPreviewPageStyle page = const DiaryPreviewPageStyle(),
  String title = '雨后的小巷',
  bool embedded = false,
}) {
  final theme = buildSeededAppTheme(_appSeed, Brightness.light);
  final resolved = DiaryPreviewResolvedStyle.resolve(
    style: DiaryPreviewStyle.defaults.copyWith(page: page),
    appTheme: theme,
    appSeed: _appSeed,
    screenSize: const Size(800, 600),
    reduceMotion: false,
    moodPalette: DiaryMoodPalette.defaults,
  );
  final anchor = GlobalKey();
  final scroll = ScrollController();
  void ignore() {}
  final host = DiaryPreviewTopBarHost(
    entry: DiaryPreviewChromeEntry(
      chrome: DiaryPreviewChrome.of(
        lookupAppLocalizations(const Locale('zh')),
        diary: _diary(title: title),
        style: page,
        actions: DiaryPreviewActions(onEdit: ignore, onShare: ignore),
        titleAnchor: anchor,
      ),
      resolved: resolved,
      barColor: _paper,
      scrollController: scroll,
    ),
    child: CustomScrollView(
      controller: scroll,
      slivers: <Widget>[
        const SliverToBoxAdapter(
          child: SizedBox(height: _statusBar + 56 + 200),
        ),
        SliverToBoxAdapter(child: SizedBox(key: anchor)),
        const SliverToBoxAdapter(child: SizedBox(height: 3000)),
      ],
    ),
  );
  return MaterialApp(
    theme: theme,
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (BuildContext context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(top: _statusBar),
          viewPadding: const EdgeInsets.only(top: _statusBar),
        ),
        child: AppGlassScope(
          style: style,
          child: Scaffold(
            backgroundColor: _paper,
            body: embedded ? DiaryPreviewHostScope(child: host) : host,
          ),
        ),
      ),
    ),
  );
}

FloatingTitleChip _chip(WidgetTester tester) =>
    tester.widget<FloatingTitleChip>(find.byType(FloatingTitleChip));

/// 岛里的玻璃（不含状态栏渐隐带）。
Finder get _islandGlass => find.descendant(
  of: find.byType(FloatingTopBar),
  matching: find.byType(GlassSurface),
);

Future<void> _scroll(WidgetTester tester, double dy) async {
  await tester.drag(find.byType(CustomScrollView), Offset(0, -dy));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('经典材质：左返回岛、右侧分享 / 编辑 / 更多，状态栏底条为纸色', (WidgetTester tester) async {
    await tester.pumpWidget(_page());
    expect(_islandGlass, findsNothing);
    expect(find.byType(FloatingBackIsland), findsOneWidget);
    expect(find.byTooltip('分享'), findsOneWidget);
    expect(find.byTooltip('编辑'), findsOneWidget);
    expect(find.byTooltip('更多'), findsOneWidget);
    final strip = tester.widget<GlassSurface>(
      find.descendant(
        of: find.byType(FloatingTopBarStatusStrip),
        matching: find.byType(GlassSurface),
      ),
    );
    expect(strip.fill, _paper);
    expect(strip.fadeToBottom, isTrue);
  });

  testWidgets('顶栏为玻璃时渐隐带与岛都不模糊，且不在 Opacity / FadeTransition 之下', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _page(style: const AppGlassStyle(mode: AppGlassMode.glass)),
    );
    final glass = find.byType(GlassSurface);
    expect(glass, findsWidgets);
    // 渐隐带只是不透明底色的透明度过渡。
    final strip = tester.widget<BackdropFilter>(
      find.descendant(
        of: find.byType(FloatingTopBarStatusStrip),
        matching: find.byType(BackdropFilter),
      ),
    );
    expect(strip.enabled, isFalse);
    // 岛压在渐隐带上：与它一样不模糊。
    for (final island in <Type>[FloatingBackIsland, FloatingActionIsland]) {
      final filter = tester.widget<BackdropFilter>(
        find.descendant(
          of: find.byType(island),
          matching: find.byType(BackdropFilter),
        ),
      );
      expect(filter.enabled, isFalse, reason: '$island');
    }
    for (final type in <Type>[Opacity, FadeTransition]) {
      expect(
        find.ancestor(
          of: glass,
          matching: find.descendant(
            of: find.byType(Scaffold),
            matching: find.byType(type),
          ),
        ),
        findsNothing,
        reason: '$type',
      );
    }
  });

  testWidgets('只把顶栏设为经典时浮岛也保持经典', (WidgetTester tester) async {
    await tester.pumpWidget(
      _page(
        style: const AppGlassStyle(
          mode: AppGlassMode.glass,
          overrides: <AppGlassComponent, AppGlassOverride>{
            AppGlassComponent.topBars: AppGlassOverride.classic,
          },
        ),
      ),
    );
    expect(_islandGlass, findsNothing);
  });

  testWidgets('自定义深色玻璃底色上按钮换成看得清的前景', (WidgetTester tester) async {
    await tester.pumpWidget(
      _page(
        style: const AppGlassStyle(
          mode: AppGlassMode.glass,
          tint: AppGlassTint.custom,
          tintColor: 0xFF101010,
          tintOpacity: 0.95,
        ),
      ),
    );
    final theme = Theme.of(tester.element(find.byTooltip('分享')));
    // 浅色主题的 onSurface 是深色，叠在近黑的玻璃上看不清，应换成浅色。
    expect(theme.colorScheme.onSurface.computeLuminance(), greaterThan(0.5));
  });

  testWidgets('默认（随滚动隐藏）：下滑收起浮岛，回到顶端浮出', (WidgetTester tester) async {
    await tester.pumpWidget(_page());
    final rest = tester.getRect(find.byType(FloatingBackIsland)).top;
    await _scroll(tester, 400);
    expect(
      tester.getRect(find.byType(FloatingBackIsland)).bottom,
      lessThanOrEqualTo(0),
    );
    await _scroll(tester, -2000);
    expect(tester.getRect(find.byType(FloatingBackIsland)).top, rest);
  });

  testWidgets('固定时浮岛一直在', (WidgetTester tester) async {
    await tester.pumpWidget(
      _page(
        page: const DiaryPreviewPageStyle(
          topBar: DiaryPreviewTopBarMode.pinned,
        ),
      ),
    );
    final rest = tester.getRect(find.byType(FloatingBackIsland)).top;
    await _scroll(tester, 400);
    expect(tester.getRect(find.byType(FloatingBackIsland)).top, rest);
  });

  testWidgets('标题模式：页头滚过后才浮出这篇的标题', (WidgetTester tester) async {
    await tester.pumpWidget(
      _page(
        page: const DiaryPreviewPageStyle(
          topBar: DiaryPreviewTopBarMode.pinned,
        ),
      ),
    );
    expect(_chip(tester).title, '雨后的小巷');
    expect(_chip(tester).visible, isFalse);
    await _scroll(tester, 250);
    expect(_chip(tester).visible, isTrue);
  });

  testWidgets('没写标题时标题胶囊显示日期', (WidgetTester tester) async {
    await tester.pumpWidget(_page(title: ''));
    expect(_chip(tester).title, contains('5'));
    expect(_chip(tester).title, contains('3'));
  });

  testWidgets('日期模式一直显示，不显示模式没有标题胶囊', (WidgetTester tester) async {
    await tester.pumpWidget(
      _page(
        page: const DiaryPreviewPageStyle(
          topBarTitle: DiaryPreviewTopBarTitle.date,
        ),
      ),
    );
    expect(_chip(tester).visible, isTrue);

    await tester.pumpWidget(
      _page(
        page: const DiaryPreviewPageStyle(
          topBarTitle: DiaryPreviewTopBarTitle.none,
        ),
      ),
    );
    expect(find.byType(FloatingTitleChip), findsNothing);
  });

  testWidgets('嵌在宽窗口右栏时只有右侧动作岛，不画状态栏底条与标题', (WidgetTester tester) async {
    await tester.pumpWidget(_page(embedded: true));
    expect(find.byType(FloatingBackIsland), findsNothing);
    expect(find.byType(FloatingTopBarStatusStrip), findsNothing);
    expect(find.byType(FloatingTitleChip), findsNothing);
    expect(find.byType(FloatingActionIsland), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/app_surface/models/app_glass_style.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_scope.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_style.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_top_bar.dart';
import 'package:node_diary/ui/widgets/glass/glass_surface.dart';

import '../../../support/expressive_test_theme.dart';

const AppGlassStyle _glass = AppGlassStyle(mode: AppGlassMode.glass);
const Color _paper = Color(0xFFFFF8E1);

/// 预览页的滚动结构：顶栏 + 一段长正文；[style] 为 null 时不挂材质 scope。
Widget _page({
  AppGlassStyle? style,
  DiaryPreviewTopBarMode mode = DiaryPreviewTopBarMode.pinned,
}) {
  return MaterialApp(
    theme: expressiveTestTheme(Brightness.light),
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (BuildContext context) {
        final page = MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(padding: const EdgeInsets.only(top: 24)),
          child: Scaffold(
            backgroundColor: _paper,
            body: CustomScrollView(
              slivers: <Widget>[
                DiaryPreviewTopBar(
                  style: DiaryPreviewStyle.defaults.page.copyWith(topBar: mode),
                  title: '日记',
                  background: _paper,
                  pageColor: _paper,
                  onOpenTypography: () {},
                  onEdit: () {},
                  onShare: () {},
                  onMore: () {},
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 2000)),
              ],
            ),
          ),
        );
        return style == null ? page : AppGlassScope(style: style, child: page);
      },
    ),
  );
}

void main() {
  testWidgets('经典材质时顶栏仍是纸色实色栏，没有玻璃', (WidgetTester tester) async {
    await tester.pumpWidget(_page(style: const AppGlassStyle()));
    expect(find.byType(GlassSurface), findsNothing);
    final bar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
    expect(bar.backgroundColor, _paper);
    expect(bar.flexibleSpace, isNull);
  });

  testWidgets('顶栏为玻璃时整条栏是一片总在模糊的玻璃，栏本身透明', (WidgetTester tester) async {
    await tester.pumpWidget(_page(style: _glass));
    final glassFinder = find.byType(GlassSurface);
    expect(glassFinder, findsOneWidget);
    expect(
      tester.widget<SliverAppBar>(find.byType(SliverAppBar)).backgroundColor,
      Colors.transparent,
    );
    // 铺满整条栏（含状态栏区域）。
    final glassRect = tester.getRect(glassFinder);
    expect(glassRect.top, 0);
    expect(glassRect.width, tester.getSize(find.byType(Scaffold)).width);
    expect(glassRect.height, kToolbarHeight + 24);
    final glass = tester.widget<GlassSurface>(glassFinder);
    expect(glass.border, isNull);
    expect(glass.bottomHairline, isNotNull);
    // 正文从栏下滑过：没有背景图也要模糊。
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isTrue,
    );
    // 玻璃不能放在 Opacity / FadeTransition 之下（只看页面之内）。
    for (final type in <Type>[Opacity, FadeTransition]) {
      expect(
        find.ancestor(
          of: glassFinder,
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

  testWidgets('随滚动隐藏的顶栏同样换成玻璃，滚走后随栏一起收起', (WidgetTester tester) async {
    await tester.pumpWidget(
      _page(style: _glass, mode: DiaryPreviewTopBarMode.floating),
    );
    expect(find.byType(GlassSurface), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.byType(GlassSurface), findsNothing);
  });

  testWidgets('只把顶栏设为经典时预览页顶栏也保持经典', (WidgetTester tester) async {
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
    expect(find.byType(GlassSurface), findsNothing);
    expect(
      tester.widget<SliverAppBar>(find.byType(SliverAppBar)).backgroundColor,
      _paper,
    );
  });

  testWidgets('自定义深色玻璃底色上标题与按钮换成看得清的前景', (WidgetTester tester) async {
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
    final appBarContext = tester.element(find.byType(AppBar));
    final theme = Theme.of(appBarContext);
    // 浅色主题的 onSurface 是深色，叠在近黑的玻璃上看不清，应换成浅色。
    expect(theme.colorScheme.onSurface.computeLuminance(), greaterThan(0.5));
    final bar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
    expect(bar.foregroundColor, theme.colorScheme.onSurface);
  });
}

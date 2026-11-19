import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/app_surface/models/app_glass_style.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_scope.dart';
import 'package:node_diary/ui/widgets/floating_top_bar/floating_action_island.dart';
import 'package:node_diary/ui/widgets/floating_top_bar/floating_island.dart';
import 'package:node_diary/ui/widgets/floating_top_bar/floating_top_bar.dart';
import 'package:node_diary/ui/widgets/floating_top_bar/floating_top_bar_host.dart';
import 'package:node_diary/ui/widgets/glass/glass_surface.dart';

import '../../support/expressive_test_theme.dart';

const double _statusBar = 24;
const Color _paper = Color(0xFFFFF8E1);
final GlobalKey _anchor = GlobalKey();

/// 一页长内容：顶端留出状态栏、页头 300 高（锚点在页头末尾），下面是长正文。
Widget _page({
  AppGlassStyle style = const AppGlassStyle(),
  bool hideOnScroll = true,
  String? title = '雨后的小巷',
  GlobalKey? anchor,
  double? contentMaxWidth,
  Size size = const Size(400, 800),
  VoidCallback? onTitleTap,
  Widget? trailing,
}) {
  return MaterialApp(
    theme: expressiveTestTheme(Brightness.light),
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        padding: const EdgeInsets.only(top: _statusBar),
        viewPadding: const EdgeInsets.only(top: _statusBar),
      ),
      child: AppGlassScope(
        style: style,
        child: Scaffold(
          backgroundColor: _paper,
          body: FloatingTopBarHost(
            hideOnScroll: hideOnScroll,
            statusBarColor: _paper,
            title: title,
            titleAnchor: anchor,
            onTitleTap: onTitleTap,
            contentMaxWidth: contentMaxWidth,
            leading: const FloatingBackIsland(),
            trailing:
                trailing ??
                FloatingActionIsland(
                  children: <Widget>[
                    IconButton(onPressed: () {}, icon: const Icon(Icons.share)),
                  ],
                ),
            child: ListView(
              padding: const EdgeInsets.only(top: _statusBar),
              children: <Widget>[
                SizedBox(height: 300, child: SizedBox(key: anchor)),
                const SizedBox(height: 3000),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Finder get _back => find.byType(FloatingBackIsland);

void main() {
  testWidgets('岛在状态栏下方 4，高 48，状态栏下方一共占 56', (WidgetTester tester) async {
    await tester.pumpWidget(_page());
    final rect = tester.getRect(_back);
    expect(rect.top, _statusBar + FloatingTopBar.islandGap);
    expect(rect.height, FloatingIsland.height);
    expect(rect.left, 12);
    expect(FloatingTopBar.extent, 56);
  });

  testWidgets('经典材质的岛是实色胶囊，没有玻璃', (WidgetTester tester) async {
    await tester.pumpWidget(_page());
    expect(find.byType(GlassSurface), findsNothing);
    final material = tester.widget<Material>(
      find.descendant(of: _back, matching: find.byType(Material)).first,
    );
    expect(material.shape, isA<StadiumBorder>());
  });

  testWidgets('顶栏为玻璃时每颗岛与状态栏底条都是玻璃', (WidgetTester tester) async {
    await tester.pumpWidget(
      _page(style: const AppGlassStyle(mode: AppGlassMode.glass)),
    );
    // 返回岛、动作岛、标题胶囊、状态栏底条。
    expect(find.byType(GlassSurface), findsNWidgets(4));
    final strip = find.descendant(
      of: find.byType(FloatingTopBarStatusStrip),
      matching: find.byType(GlassSurface),
    );
    expect(tester.getRect(strip).height, _statusBar);
  });

  testWidgets('状态栏样式按页面主题给出', (WidgetTester tester) async {
    await tester.pumpWidget(_page());
    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.descendant(
        of: find.byType(FloatingTopBarStatusStrip),
        matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      ),
    );
    expect(region.value.statusBarIconBrightness, Brightness.dark);
  });

  testWidgets('往下滚收起浮岛，往回滚浮出', (WidgetTester tester) async {
    await tester.pumpWidget(_page());
    final restTop = tester.getRect(_back).top;

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.getRect(_back).bottom, lessThanOrEqualTo(0));
    expect(
      tester.hitTestOnBinding(tester.getCenter(find.byType(ListView))),
      isNotNull,
    );

    await tester.drag(find.byType(ListView), const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(tester.getRect(_back).top, restTop);
  });

  testWidgets('关掉随滚动隐藏时浮岛一直在', (WidgetTester tester) async {
    await tester.pumpWidget(_page(hideOnScroll: false));
    final restTop = tester.getRect(_back).top;
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.getRect(_back).top, restTop);
  });

  testWidgets('标题胶囊在页头滚进浮岛那一行后才浮出，点按回调', (WidgetTester tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      _page(hideOnScroll: false, anchor: _anchor, onTitleTap: () => tapped++),
    );
    FloatingTitleChip chip() =>
        tester.widget<FloatingTitleChip>(find.byType(FloatingTitleChip));
    expect(chip().visible, isFalse);

    // 页头末尾在 24 + 300 处，滚 200 后仍在浮岛下方。
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(chip().visible, isFalse);

    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(chip().visible, isTrue);
    await tester.tap(find.text('雨后的小巷'));
    expect(tapped, 1);
  });

  testWidgets('没有锚点时标题胶囊一直显示', (WidgetTester tester) async {
    await tester.pumpWidget(_page(title: '3 / 20'));
    expect(
      tester.widget<FloatingTitleChip>(find.byType(FloatingTitleChip)).visible,
      isTrue,
    );
  });

  testWidgets('宽窗口时岛与居中的正文列对齐', (WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1200, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _page(size: const Size(1200, 800), contentMaxWidth: 720),
    );
    // 正文列从 (1200 − 720) / 2 = 240 开始，岛比它再往外 4。
    expect(tester.getRect(_back).left, 236);
  });

  testWidgets('动作胶囊换一套动作时宽度补间到新的宽度', (WidgetTester tester) async {
    Widget island(Object key, int count) => FloatingActionIsland(
      layoutKey: key,
      children: <Widget>[
        for (var i = 0; i < count; i++)
          IconButton(onPressed: () {}, icon: const Icon(Icons.share)),
      ],
    );
    await tester.pumpWidget(_page(trailing: island('reading', 1)));
    final finder = find.byType(FloatingActionIsland);
    expect(tester.getSize(finder).width, 48);

    await tester.pumpWidget(_page(trailing: island('editing', 3)));
    await tester.pump(const Duration(milliseconds: 60));
    final midway = tester.getSize(finder).width;
    // spatial 曲线带一点过冲，只要求已经在长、还没停下。
    expect(midway, greaterThan(48));
    expect(midway, isNot(144));
    await tester.pumpAndSettle();
    expect(tester.getSize(finder).width, 144);
  });
}

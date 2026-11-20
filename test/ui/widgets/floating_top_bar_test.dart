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
  bool reduceMotion = false,
  bool highContrast = false,
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
        disableAnimations: reduceMotion,
        highContrast: highContrast,
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

Finder get _stripGlass => find.descendant(
  of: find.byType(FloatingTopBarStatusStrip),
  matching: find.byType(GlassSurface),
);

/// 岛里的玻璃（不含状态栏底条）。
Finder get _islandGlass => find.descendant(
  of: find.byType(FloatingTopBar),
  matching: find.byType(GlassSurface),
);

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
    expect(_islandGlass, findsNothing);
    final material = tester.widget<Material>(
      find.descendant(of: _back, matching: find.byType(Material)).first,
    );
    expect(material.shape, isA<StadiumBorder>());
  });

  testWidgets('状态栏底条往下铺过浮岛那一行后渐隐，浮岛画在它之上', (WidgetTester tester) async {
    await tester.pumpWidget(_page());
    final strip = tester.widget<GlassSurface>(_stripGlass);
    // 经典：纸色、不模糊，自上而下渐隐（与首页顶栏同一种渐隐）。
    expect(strip.fill, _paper);
    expect(strip.blur, isFalse);
    expect(strip.fadeToBottom, isTrue);
    final band = tester.getRect(_stripGlass);
    expect(band.top, 0);
    expect(band.height, _statusBar + FloatingTopBar.extent);
    // 岛那一行整个落在渐隐带里。
    expect(
      tester.getRect(_back).bottom,
      lessThan(tester.getRect(_stripGlass).bottom),
    );
    // 叠放次序：内容 → 渐隐带 → 浮岛。
    final stack = tester.widget<Stack>(
      find
          .descendant(
            of: find.byType(FloatingTopBarHost),
            matching: find.byType(Stack),
          )
          .first,
    );
    final layers = stack.children
        .whereType<Positioned>()
        .map((Positioned layer) => layer.child.runtimeType)
        .toList();
    expect(layers, <Type>[FloatingTopBarStatusStrip, FloatingIslandBand]);
  });

  testWidgets('高对比度时底条只垫状态栏、不渐隐', (WidgetTester tester) async {
    await tester.pumpWidget(_page(highContrast: true));
    expect(tester.getRect(_stripGlass).height, _statusBar);
    expect(tester.widget<GlassSurface>(_stripGlass).fadeToBottom, isFalse);
  });

  testWidgets('顶栏为玻璃时渐隐带与岛都是不透明的玻璃色、不模糊', (WidgetTester tester) async {
    await tester.pumpWidget(
      _page(style: const AppGlassStyle(mode: AppGlassMode.glass)),
    );
    // 返回岛、动作岛、标题胶囊、状态栏底条。
    expect(find.byType(GlassSurface), findsNWidgets(4));
    final strip = tester.widget<GlassSurface>(_stripGlass);
    // 只是一次透明度过渡：上半截不透明，不模糊（重模糊会把底下的彩色
    // 标签糊成色块透上来）。
    expect(strip.blur, isFalse);
    expect(strip.fill.a, 1);
    expect(strip.fadeToBottom, isTrue);
    expect(
      tester.getRect(_stripGlass).height,
      _statusBar + FloatingTopBar.extent,
    );
    for (final island in tester.widgetList<GlassSurface>(_islandGlass)) {
      expect(island.blur, isFalse);
      // 渐隐带下半截淡到透明，岛用不透明的等效色，免得底下的文字透上来。
      expect(island.fill.a, 1);
      expect(island.shadowColor, isNotNull);
    }
  });

  testWidgets('不画状态栏底条时玻璃岛自己模糊', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppGlassScope(
          style: const AppGlassStyle(mode: AppGlassMode.glass),
          child: Scaffold(
            body: FloatingTopBarHost(
              trailing: FloatingActionIsland(
                children: <Widget>[
                  IconButton(onPressed: () {}, icon: const Icon(Icons.share)),
                ],
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(FloatingTopBarStatusStrip), findsNothing);
    expect(tester.widget<GlassSurface>(_islandGlass).blur, isTrue);
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
    // 岛收起后那一行仍被渐隐带罩着，光标避让与查找跳转照样让开它。
    expect(
      FloatingTopBarCover.coveredBottomOf(
        tester.element(find.byType(ListView)),
      ),
      _statusBar + FloatingTopBar.extent,
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

  testWidgets('动作胶囊里的一格出现时横向展开，收起后不挂载', (WidgetTester tester) async {
    Widget island({required bool editing}) => FloatingActionIsland(
      children: <Widget>[
        FloatingIslandSlot(
          visible: !editing,
          child: IconButton(
            tooltip: 'share',
            onPressed: () {},
            icon: const Icon(Icons.share),
          ),
        ),
        IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
        FloatingIslandSlot(
          visible: editing,
          child: FloatingIslandPill(label: '完成', onPressed: () {}),
        ),
      ],
    );
    await tester.pumpWidget(_page(trailing: island(editing: false)));
    final finder = find.byType(FloatingActionIsland);
    expect(tester.getSize(finder).width, 96);
    expect(find.text('完成'), findsNothing);

    await tester.pumpWidget(_page(trailing: island(editing: true)));
    await tester.pump(const Duration(milliseconds: 60));
    // 分享在收起、完成在展开：途中两格都在。
    expect(find.byTooltip('share'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byTooltip('share'), findsNothing);
    expect(find.text('完成'), findsOneWidget);
    expect(tester.getSize(finder).width, greaterThan(48 + 56));
  });

  testWidgets('减少动画时一格直接出现', (WidgetTester tester) async {
    Widget island({required bool visible}) => FloatingActionIsland(
      children: <Widget>[
        FloatingIslandSlot(
          visible: visible,
          child: FloatingIslandPill(label: '完成', onPressed: () {}),
        ),
      ],
    );
    await tester.pumpWidget(
      _page(trailing: island(visible: false), reduceMotion: true),
    );
    await tester.pumpWidget(
      _page(trailing: island(visible: true), reduceMotion: true),
    );
    await tester.pump();
    expect(find.text('完成'), findsOneWidget);
    // 已停在完全展开：不再套淡入用的 Opacity。
    expect(
      find.ancestor(
        of: find.text('完成'),
        matching: find.descendant(
          of: find.byType(FloatingIslandSlot),
          matching: find.byType(Opacity),
        ),
      ),
      findsNothing,
    );
  });
}

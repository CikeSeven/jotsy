import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/app_scroll_behavior.dart';
import 'package:node_diary/ui/app_surface/widgets/app_page_backdrop.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_resolved_style.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_chrome_scope.dart';
import 'package:node_diary/ui/widgets/glass_safe_stretch_indicator.dart';

import '../../support/expressive_test_theme.dart';

const _listKey = ValueKey<String>('list');

AppPageBackdrop _backdrop({required bool image}) {
  final scheme = expressiveTestTheme(Brightness.light).colorScheme;
  return AppPageBackdrop(
    area: null,
    hasBackground: image,
    hasImage: image,
    pageColor: image ? Colors.transparent : scheme.surface,
    solidBarColor: scheme.surface,
    estimatedColor: scheme.surface,
  );
}

HomeBarResolvedStyle _glassTopBars() => HomeBarResolvedStyle.resolve(
  const HomeBarStyle(material: HomeBarMaterial.glass, glassTopBars: true),
  expressiveTestTheme(Brightness.light).colorScheme,
  highContrast: false,
);

/// 列表项：带一块玻璃（BackdropFilter），并记录自己的 State 是否被重建。
class _GlassItem extends StatefulWidget {
  const _GlassItem(this.index);

  final int index;

  static final Set<State<_GlassItem>> mounted = <State<_GlassItem>>{};

  @override
  State<_GlassItem> createState() => _GlassItemState();
}

class _GlassItemState extends State<_GlassItem> {
  @override
  void initState() {
    super.initState();
    _GlassItem.mounted.add(this);
  }

  @override
  void dispose() {
    _GlassItem.mounted.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Center(child: Text('item ${widget.index}')),
        ),
      ),
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  ScrollBehavior behavior = const AppScrollBehavior(),
  AppPageBackdrop? backdrop,
  HomeBarResolvedStyle? homeStyle,
  bool highContrast = false,
  bool wrapWithCopy = false,
}) {
  Widget list = ListView.builder(
    key: _listKey,
    itemCount: 30,
    itemBuilder: (_, int index) => _GlassItem(index),
  );
  if (wrapWithCopy) {
    final inner = list;
    list = Builder(
      builder: (BuildContext context) => ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: inner,
      ),
    );
  }
  if (backdrop != null) {
    list = AppPageBackdropScope(backdrop: backdrop, child: list);
  }
  if (homeStyle != null) {
    list = HomeChromeScope(style: homeStyle, child: list);
  }
  return tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      scrollBehavior: behavior,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(highContrast: highContrast),
        child: child!,
      ),
      home: Scaffold(body: list),
    ),
  );
}

Finder get _indicator => find.byType(GlassSafeStretchingOverscrollIndicator);

/// 指示器里外层的 Transform（我们的缩放拉伸）。
Matrix4 _outerTransform(WidgetTester tester) => tester
    .widget<Transform>(
      find.descendant(of: _indicator, matching: find.byType(Transform)).first,
    )
    .transform;

double _stretchStrength(WidgetTester tester) =>
    tester.widget<StretchEffect>(find.byType(StretchEffect)).stretchStrength;

bool _hasImageFilterLayer(WidgetTester tester) =>
    tester.layers.whereType<ImageFilterLayer>().isNotEmpty;

/// 第一个列表项里玻璃（BackdropFilter）到根之间的图层：有没有会开离屏的
/// 图层（ImageFilterLayer、半透明的 OpacityLayer；alpha 255 的 OpacityLayer
/// 来自路由转场，引擎按普通偏移层处理），以及拉伸用的缩放 TransformLayer
/// 是否就在链上。
({bool offscreen, bool scaled}) _backdropAncestry(WidgetTester tester) {
  final render = tester.renderObject(find.byType(BackdropFilter).first);
  final layer = render.debugLayer;
  expect(layer, isA<BackdropFilterLayer>());
  var offscreen = false;
  var scaled = false;
  for (ContainerLayer? l = layer!.parent; l != null; l = l.parent) {
    if (l is ImageFilterLayer) offscreen = true;
    if (l is OpacityLayer && (l.alpha ?? 255) < 255) offscreen = true;
    if (l is TransformLayer && (l.transform?.storage[5] ?? 1) > 1) {
      scaled = true;
    }
  }
  return (offscreen: offscreen, scaled: scaled);
}

/// 在列表顶部向下拉，越界一段距离后停在按住状态。
Future<TestGesture> _pullAtTop(WidgetTester tester) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byKey(_listKey)),
  );
  for (var i = 0; i < 6; i++) {
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
  }
  return gesture;
}

final _android = TargetPlatformVariant.only(TargetPlatform.android);

void main() {
  testWidgets(
    'without a background image the SDK stretch paints the overscroll',
    (tester) async {
      await _pump(tester, backdrop: _backdrop(image: false));
      expect(_indicator, findsOneWidget);
      expect(find.byType(StretchingOverscrollIndicator), findsNothing);

      final gesture = await _pullAtTop(tester);
      // 越界量交给 SDK 的 StretchEffect，我们的外层 Transform 保持单位矩阵。
      expect(_stretchStrength(tester), isNot(0));
      expect(_outerTransform(tester), Matrix4.identity());
      // SDK 两种分支（着色器 / 带 filterQuality 的矩阵）都推离屏的
      // ImageFilterLayer——这正是玻璃失去模糊的原因，默认路径保持原样。
      expect(_hasImageFilterLayer(tester), isTrue);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(_stretchStrength(tester), 0);
      expect(_hasImageFilterLayer(tester), isFalse);
    },
    variant: _android,
  );

  testWidgets('the default path animates exactly like the SDK indicator', (
    tester,
  ) async {
    Future<List<double>> record(ScrollBehavior behavior) async {
      await _pump(tester, behavior: behavior);
      await tester.pumpAndSettle();
      final values = <double>[];
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_listKey)),
      );
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();
        values.add(_stretchStrength(tester));
      }
      await gesture.up();
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        values.add(_stretchStrength(tester));
      }
      // 换下一种行为前卸掉整棵树，免得 State 被复用。
      await tester.pumpWidget(const SizedBox.shrink());
      return values;
    }

    final sdk = await record(const MaterialScrollBehavior());
    final ours = await record(const AppScrollBehavior());
    expect(sdk.any((double v) => v != 0), isTrue);
    expect(ours, sdk);
  }, variant: _android);

  testWidgets(
    'with a background image the stretch scales without an offscreen layer',
    (tester) async {
      await _pump(tester, backdrop: _backdrop(image: true));

      final gesture = await _pullAtTop(tester);
      // 测试环境不一定支持着色器滤镜（SDK 可能已走矩阵分支），所以不依赖
      // SDK 的分支：断言 SDK 的拉伸收到 0、子树里没有启用的 ImageFiltered，
      // 拉伸完全由我们的外层 Transform 完成。
      expect(_stretchStrength(tester), 0);
      expect(
        find.byWidgetPredicate((w) => w is ImageFiltered && w.enabled),
        findsNothing,
      );
      final stretched = _outerTransform(tester);
      // 顶部被拉：沿纵轴放大，横轴不变。
      expect(stretched.storage[5], greaterThan(1.0));
      expect(stretched.storage[0], 1.0);
      expect(_hasImageFilterLayer(tester), isFalse);
      expect(_backdropAncestry(tester), (offscreen: false, scaled: true));
      expect(
        find.ancestor(
          of: find.byType(BackdropFilter).first,
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );

      await gesture.up();
      await tester.pumpAndSettle();
      expect(_outerTransform(tester), Matrix4.identity());
    },
    variant: _android,
  );

  testWidgets('glass home top bars use the layer-free stretch', (tester) async {
    await _pump(tester, homeStyle: _glassTopBars());
    final gesture = await _pullAtTop(tester);
    expect(_outerTransform(tester).storage[5], greaterThan(1.0));
    expect(_hasImageFilterLayer(tester), isFalse);
    expect(_backdropAncestry(tester), (offscreen: false, scaled: true));
    await gesture.up();
    await tester.pumpAndSettle();
  }, variant: _android);

  testWidgets('high contrast keeps the SDK stretch (no glass blurs)', (
    tester,
  ) async {
    await _pump(
      tester,
      backdrop: _backdrop(image: true),
      homeStyle: _glassTopBars(),
      highContrast: true,
    );
    final gesture = await _pullAtTop(tester);
    expect(_outerTransform(tester), Matrix4.identity());
    expect(_stretchStrength(tester), isNot(0));
    await gesture.up();
    await tester.pumpAndSettle();
  }, variant: _android);

  testWidgets('ScrollConfiguration.copyWith keeps the app overscroll', (
    tester,
  ) async {
    await _pump(tester, backdrop: _backdrop(image: true), wrapWithCopy: true);
    expect(_indicator, findsOneWidget);
    final gesture = await _pullAtTop(tester);
    expect(_outerTransform(tester).storage[5], greaterThan(1.0));
    expect(_hasImageFilterLayer(tester), isFalse);
    await gesture.up();
    await tester.pumpAndSettle();
  }, variant: _android);

  testWidgets('switching modes keeps the list items mounted', (tester) async {
    await _pump(tester, backdrop: _backdrop(image: false));
    final before = Set<State<_GlassItem>>.of(_GlassItem.mounted);
    expect(before, isNotEmpty);
    // 背景图解码完成：判定翻转，列表项的 State 不能被卸载重建。
    await _pump(tester, backdrop: _backdrop(image: true));
    expect(_GlassItem.mounted, before);
  }, variant: _android);

  testWidgets(
    'other platforms keep the parent behaviour',
    (tester) async {
      await _pump(tester, backdrop: _backdrop(image: true));
      expect(_indicator, findsNothing);
      expect(find.byType(StretchingOverscrollIndicator), findsNothing);
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.iOS,
      TargetPlatform.linux,
      TargetPlatform.windows,
    }),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/widgets/diaries_header_sliver.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_presets.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_resolved_style.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_chrome_scope.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_top_bar_surface.dart';
import 'package:node_diary/ui/widgets/glass/glass_surface.dart';

class _Probe extends StatefulWidget {
  const _Probe({required this.label});

  final String label;

  static int created = 0;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    _Probe.created++;
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}

Widget _host(ScrollController controller, {required bool pinned}) {
  return MaterialApp(
    home: Scaffold(
      body: CustomScrollView(
        controller: controller,
        slivers: <Widget>[
          DiariesHeaderSliver(
            pinned: pinned,
            height: 68,
            backgroundColor: const Color(0xFFEEEEEE),
            child: SizedBox(
              height: 68,
              child: _Probe(label: pinned ? 'selecting' : 'normal'),
            ),
          ),
          const PinnedHeaderSliver(
            child: SizedBox(height: 40, child: Text('tags')),
          ),
          SliverList.builder(
            itemCount: 100,
            itemBuilder: (context, index) =>
                SizedBox(height: 60, child: Text('item $index')),
          ),
        ],
      ),
    ),
  );
}

double _tagsTop(WidgetTester tester) => tester.getTopLeft(find.text('tags')).dy;

const double _statusBar = 24;
const double _glassHeight = 68;

/// 与日记页玻璃顶栏相同的组合：玻璃预设的 [HomeChromeScope]、页面不让出
/// 状态栏、刊头并进状态栏高度，标签栏是最下面一片玻璃，两片共用一个
/// [BackdropGroup]。
Widget _glassHost(ScrollController controller, {required bool pinned}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => HomeChromeScope(
        style: HomeBarResolvedStyle.resolve(
          HomeBarPreset.glass.style,
          Theme.of(context).colorScheme,
        ),
        child: Scaffold(
          body: BackdropGroup(
            child: CustomScrollView(
              controller: controller,
              slivers: <Widget>[
                DiariesHeaderSliver(
                  pinned: pinned,
                  height: _glassHeight,
                  glass: true,
                  topInset: _statusBar,
                  backgroundColor: const Color(0xFFEEEEEE),
                  child: const SizedBox(
                    height: _glassHeight,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text('masthead'),
                    ),
                  ),
                ),
                const PinnedHeaderSliver(
                  child: HomeTopBarSurface(
                    solidColor: Color(0xFFEEEEEE),
                    grouped: true,
                    child: SizedBox(height: 40, child: Text('tags')),
                  ),
                ),
                SliverList.builder(
                  itemCount: 100,
                  itemBuilder: (context, index) =>
                      SizedBox(height: 60, child: Text('item $index')),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Finder get _mastheadGlass => find
    .descendant(
      of: find.byType(DiariesHeaderSliver),
      matching: find.byType(GlassSurface),
    )
    .first;

Finder get _tagsGlass => find
    .ancestor(of: find.text('tags'), matching: find.byType(GlassSurface))
    .first;

Future<void> _dragBackWithFrames(WidgetTester tester) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(CustomScrollView)),
  );
  for (var step = 0; step < 4; step++) {
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => _Probe.created = 0);

  testWidgets('selection header slides in and out together with the tag bar', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller, pinned: false));
    controller.jumpTo(600);
    await tester.pump();
    // 浮动顶栏已滚出，标签栏固定在最顶部。
    expect(_tagsTop(tester), 0);
    final itemTop = tester.getTopLeft(find.text('item 12')).dy;

    await tester.pumpWidget(_host(controller, pinned: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    // 顶栏从顶部滑下，标签栏随之同步下移，而不是瞬移一整个顶栏高度。
    expect(_tagsTop(tester), inExclusiveRange(0, 68));
    // 列表本身不随过渡移动。
    expect(tester.getTopLeft(find.text('item 12')).dy, itemTop);
    await tester.pumpAndSettle();
    expect(_tagsTop(tester), 68);

    await tester.pumpWidget(_host(controller, pinned: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(_tagsTop(tester), inExclusiveRange(0, 68));
    await tester.pumpAndSettle();
    expect(_tagsTop(tester), 0);
    expect(tester.getTopLeft(find.text('item 12')).dy, itemTop);

    // 切换形态时顶栏内容整体迁移，内部状态（如交叉淡入）不重建。
    expect(_Probe.created, 1);
  });

  testWidgets('header already visible at the top switches without motion', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller, pinned: false));
    expect(_tagsTop(tester), 68);

    await tester.pumpWidget(_host(controller, pinned: true));
    expect(_tagsTop(tester), 68);
    await tester.pumpWidget(_host(controller, pinned: false));
    expect(_tagsTop(tester), 68);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('selection header appears at once under reduce motion', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller, pinned: false));
    controller.jumpTo(600);
    await tester.pump();

    await tester.pumpWidget(_host(controller, pinned: true));
    expect(_tagsTop(tester), 68);
    await tester.pumpWidget(_host(controller, pinned: false));
    expect(_tagsTop(tester), 0);
  });

  group('glass top bars', () {
    testWidgets('the masthead covers the status bar and the tag bar follows', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_glassHost(controller, pinned: false));
      final masthead = tester.getRect(_mastheadGlass);
      expect(masthead.top, 0);
      expect(masthead.height, _statusBar + _glassHeight);
      // 内容从状态栏线以下开始。
      expect(tester.getTopLeft(find.text('masthead')).dy, _statusBar);
      expect(_tagsTop(tester), _statusBar + _glassHeight);
    });

    testWidgets('scrolling down leaves the status strip and pins the tags', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_glassHost(controller, pinned: false));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();
      // 刊头收起到只剩状态栏那一条，标签栏紧贴在它下面。
      expect(tester.getRect(_mastheadGlass).height, _statusBar);
      expect(tester.getRect(_mastheadGlass).top, 0);
      expect(_tagsTop(tester), _statusBar);
      // 收起的内容在状态栏线处被裁掉，不会清晰地压在状态栏上。
      final clip = tester.renderObject<RenderClipRect>(
        find
            .descendant(
              of: find.byType(DiariesHeaderSliver),
              matching: find.byType(ClipRect),
            )
            .first,
      );
      expect(clip.size.height, 0);

      // 上滑即现，与实色时的浮动顶栏一致。
      await _dragBackWithFrames(tester);
      expect(controller.offset, greaterThan(300));
      expect(tester.getRect(_mastheadGlass).height, _statusBar + _glassHeight);
      expect(_tagsTop(tester), _statusBar + _glassHeight);
    });

    testWidgets('selection mode keeps the whole masthead visible', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_glassHost(controller, pinned: false));
      controller.jumpTo(600);
      await tester.pump();
      expect(_tagsTop(tester), _statusBar);

      await tester.pumpWidget(_glassHost(controller, pinned: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      // 露出过渡只作用于可收起的部分，状态栏那一条始终在。
      expect(
        _tagsTop(tester),
        inExclusiveRange(_statusBar, _statusBar + _glassHeight),
      );
      await tester.pumpAndSettle();
      expect(_tagsTop(tester), _statusBar + _glassHeight);
      controller.jumpTo(1200);
      await tester.pump();
      expect(_tagsTop(tester), _statusBar + _glassHeight);

      await tester.pumpWidget(_glassHost(controller, pinned: false));
      await tester.pumpAndSettle();
      expect(_tagsTop(tester), _statusBar);
    });

    testWidgets('both slices share one backdrop and only the tags get a line', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_glassHost(controller, pinned: false));
      final filters = tester
          .renderObjectList<RenderBackdropFilter>(find.byType(BackdropFilter))
          .toList();
      expect(filters, hasLength(2));
      expect(filters.every((filter) => filter.enabled), isTrue);
      final key = filters.first.backdropKey;
      expect(key, isNotNull);
      expect(filters.last.backdropKey, same(key));
      expect(
        tester.widget<GlassSurface>(_mastheadGlass).bottomHairline,
        isNull,
      );
      expect(tester.widget<GlassSurface>(_tagsGlass).bottomHairline, isNotNull);
    });
  });
}

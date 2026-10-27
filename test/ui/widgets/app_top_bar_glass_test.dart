import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/app_breakpoints.dart';
import 'package:node_diary/ui/app_surface/models/app_glass_style.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_scope.dart';
import 'package:node_diary/ui/app_surface/widgets/app_page_backdrop.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';
import 'package:node_diary/ui/widgets/glass/glass_surface.dart';

const AppGlassStyle _glass = AppGlassStyle(mode: AppGlassMode.glass);

/// 一个带顶栏的页面；[style] 为 null 时不挂材质 scope。
Widget _page({
  AppGlassStyle? style,
  required PreferredSizeWidget appBar,
  Size size = const Size(400, 300),
}) {
  return MaterialApp(
    home: Builder(
      builder: (BuildContext context) {
        final page = MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(size: size, padding: const EdgeInsets.only(top: 24)),
          child: Scaffold(appBar: appBar, body: const SizedBox.expand()),
        );
        return style == null ? page : AppGlassScope(style: style, child: page);
      },
    ),
  );
}

Future<List<int>> _capture(WidgetTester tester, Widget app) async {
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(key: key, child: app));
  await tester.pump();
  final render =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await render.toImage();
    final data = await image.toByteData();
    image.dispose();
    return data!.buffer.asUint8List().toList();
  });
  return bytes!;
}

void main() {
  group('AppTopBar 经典', () {
    testWidgets('与改动前逐像素一致（含 contentMaxWidth 两侧留白）', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final maxWidth in <double?>[null, AppContentWidth.form]) {
        final current = await _capture(
          tester,
          _page(
            size: const Size(1200, 400),
            appBar: AppTopBar(
              title: const Text('标题'),
              actions: const <Widget>[Icon(Icons.add)],
              contentMaxWidth: maxWidth,
            ),
          ),
        );
        final legacy = await _capture(
          tester,
          _page(
            size: const Size(1200, 400),
            appBar: LegacyAppTopBar(
              title: const Text('标题'),
              actions: const <Widget>[Icon(Icons.add)],
              contentMaxWidth: maxWidth,
            ),
          ),
        );
        expect(current.any((int b) => b != 0), isTrue);
        expect(current, legacy, reason: 'contentMaxWidth: $maxWidth');
      }
    });

    testWidgets('材质为经典时不出现玻璃', (WidgetTester tester) async {
      await tester.pumpWidget(
        _page(
          style: const AppGlassStyle(),
          appBar: const AppTopBar(title: Text('标题')),
        ),
      );
      expect(find.byType(GlassSurface), findsNothing);
    });
  });

  group('AppTopBar 玻璃', () {
    testWidgets('整条栏是一片玻璃，AppBar 透明，不在 Opacity / FadeTransition 之下', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _page(
          style: _glass,
          appBar: const AppTopBar(title: Text('标题')),
        ),
      );
      final glassFinder = find.byType(GlassSurface);
      expect(glassFinder, findsOneWidget);
      // 只看页面之内（路由自己的转场动画在页面之外，与顶栏无关）。
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
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, Colors.transparent);
      // 玻璃覆盖整条栏（含状态栏区域）：与 Scaffold 交给顶栏的区域一样大。
      final glassRect = tester.getRect(glassFinder);
      expect(glassRect.top, 0);
      expect(glassRect.height, 64 + 24);
      final glass = tester.widget<GlassSurface>(glassFinder);
      expect(glass.bottomHairline, isNotNull);
      expect(glass.border, isNull);
      // 顶栏下面只有页面背景：没有背景图时不模糊。
      expect(
        tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
        isFalse,
      );
    });

    testWidgets('有图片背景时模糊；描边关闭时没有底缘细线', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppGlassScope(
            style: _glass.copyWith(border: false),
            child: Builder(
              builder: (BuildContext context) {
                final scheme = Theme.of(context).colorScheme;
                return AppPageBackdropScope(
                  backdrop: AppPageBackdrop(
                    area: AppBackgroundArea.other,
                    hasBackground: true,
                    hasImage: true,
                    pageColor: Colors.transparent,
                    solidBarColor: scheme.surface,
                    estimatedColor: scheme.surface,
                  ),
                  child: const Scaffold(appBar: AppTopBar(title: Text('标题'))),
                );
              },
            ),
          ),
        ),
      );
      expect(
        tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
        isTrue,
      );
      expect(
        tester.widget<GlassSurface>(find.byType(GlassSurface)).bottomHairline,
        isNull,
      );
    });

    testWidgets('带 contentMaxWidth 时玻璃铺满整栏宽度，工具栏内缩', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _page(
          style: _glass,
          size: const Size(1200, 400),
          appBar: const AppTopBar(
            title: Text('标题'),
            contentMaxWidth: AppContentWidth.form,
          ),
        ),
      );
      final glassRect = tester.getRect(find.byType(GlassSurface));
      expect(glassRect.left, 0);
      expect(glassRect.width, 1200);
      final barRect = tester.getRect(find.byType(AppBar));
      expect(barRect.left, greaterThan(0));
      expect(barRect.right, lessThan(1200));
      // 留白处不再补实色。
      expect(
        find.descendant(
          of: find.byType(AppTopBar),
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
      );
    });

    testWidgets('调用方指定底色时保持经典', (WidgetTester tester) async {
      await tester.pumpWidget(
        _page(
          style: _glass,
          appBar: const AppTopBar(
            title: Text('标题'),
            backgroundColor: Color(0xFFFFF8E1),
          ),
        ),
      );
      expect(find.byType(GlassSurface), findsNothing);
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        const Color(0xFFFFF8E1),
      );
    });
  });
}

/// 改动前 `AppTopBar` 的原样副本（只改了类名），用于逐像素对比经典分支。
class LegacyAppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const LegacyAppTopBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle,
    this.automaticallyImplyLeading = true,
    this.foregroundColor,
    this.backgroundColor,
    this.toolbarHeight,
    this.bottom,
    this.systemOverlayStyle,
    this.contentMaxWidth,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool? centerTitle;
  final bool automaticallyImplyLeading;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final double? toolbarHeight;
  final PreferredSizeWidget? bottom;
  final SystemUiOverlayStyle? systemOverlayStyle;

  /// 页面内容列的最大宽度（如 `AppContentWidth.form`）。给出且标题栏宽于
  /// `contentMaxWidth + 32` 时，工具栏两侧各缩进 `gutter − 16`，返回键与标题
  /// 对齐居中的内容列、动作贴内容列右缘；底色仍铺满整栏。为 null（默认）
  /// 或标题栏不够宽时与原来完全一致。
  final double? contentMaxWidth;

  @override
  Size get preferredSize {
    final resolvedToolbarHeight = toolbarHeight ?? 64;
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(resolvedToolbarHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = colorScheme.brightness == Brightness.light;
    final resolvedForeground = foregroundColor ?? colorScheme.onSurface;
    // 未指定底色时取所在页面背景的实色栏底色：没有背景（或页面尚未接入
    // 背景）时就是 surface，与原来一致；纯色背景时与页面同色，图片背景时
    // 保持不透明的 surface。
    final resolvedBackground =
        backgroundColor ?? AppPageBackdrop.solidBarColorOf(context);
    final resolvedOverlay =
        systemOverlayStyle ??
        theme.appBarTheme.systemOverlayStyle ??
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
          statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: isLight
              ? Brightness.dark
              : Brightness.light,
        );

    final appBar = AppBar(
      title: title,
      leading:
          leading ??
          (automaticallyImplyLeading && Navigator.of(context).canPop()
              ? IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
                )
              : null),
      actions: actions,
      centerTitle: centerTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
      foregroundColor: resolvedForeground,
      backgroundColor: resolvedBackground,
      systemOverlayStyle: resolvedOverlay,
      toolbarHeight: toolbarHeight ?? 64,
      bottom: bottom,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
    );
    final maxWidth = contentMaxWidth;
    if (maxWidth == null) {
      return appBar;
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!constraints.hasBoundedWidth) {
          return appBar;
        }
        final inset =
            AppContentWidth.gutter(constraints.maxWidth, maxWidth) - 16;
        if (inset <= 0) {
          return appBar;
        }
        // 两侧留白用同一底色补齐，看起来仍是一整条标题栏。
        return ColoredBox(
          color: resolvedBackground,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: inset),
            child: appBar,
          ),
        );
      },
    );
  }
}

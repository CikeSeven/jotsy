import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_settings.dart';
import 'package:node_diary/ui/app_surface/services/app_background_image_cache.dart';
import 'package:node_diary/ui/app_surface/widgets/app_page_background.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_style.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_pager_effects.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_pager_view.dart';

import '../../../support/expressive_test_theme.dart';
import '../../app_surface/app_surface_test_images.dart';

const Color _color = Color(0xFF336699);

const AppBackground _colorBackground = AppBackground(
  kind: AppBackgroundKind.color,
  colorLight: 0xFF336699,
);

const AppBackground _imageBackground = AppBackground(
  kind: AppBackgroundKind.image,
  image: 'bg.png',
  alignX: 0.4,
  alignY: -0.2,
);

/// 透明的一页（与纸张跟随主题时的预览页一样不画底），记录 initState 次数。
class _Page extends StatefulWidget {
  const _Page({super.key, required this.index});

  final int index;
  static int created = 0;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  @override
  void initState() {
    super.initState();
    _Page.created++;
  }

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: <Widget>[Text('第 ${widget.index} 页')],
  );
}

/// 预览区域背景（[background]）之下的翻页器，转场为 [transition]。
Widget _app({
  required AppBackgroundImageCache cache,
  required AppBackground background,
  required DiaryPreviewPageTransition transition,
  AppBackgroundArea area = AppBackgroundArea.preview,
}) {
  return ProviderScope(
    overrides: [appBackgroundImageCacheProvider.overrideWithValue(cache)],
    child: MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AppPageBackground.preview(
        area: area,
        background: background,
        child: DiaryPagerView(
          itemCount: 3,
          navigation: DiaryPreviewNavigationStyle(transition: transition),
          itemBuilder: (BuildContext context, DiaryPagerPosition position) =>
              _Page(key: ValueKey<int>(position.index), index: position.index),
        ),
      ),
    ),
  );
}

Finder get _copies => find.byType(AppPageBackgroundCopy, skipOffstage: false);

/// 每篇的过渡层里各有一份背景（随页面一起变换）。预先构建的相邻页在视口
/// 之外，查找时不跳过屏外节点。
Finder _copyIn(int index) => find.descendant(
  of: find.ancestor(
    of: find.byKey(ValueKey<int>(index), skipOffstage: false),
    matching: find.byType(DiaryPagerTransition, skipOffstage: false),
  ),
  matching: find.byType(AppPageBackgroundCopy, skipOffstage: false),
  skipOffstage: false,
);

void main() {
  late FakeBackgroundLoader loader;
  late AppBackgroundImageCache cache;

  setUp(() {
    loader = FakeBackgroundLoader();
    cache = AppBackgroundImageCache(loader: loader.call);
    _Page.created = 0;
  });

  tearDown(() => cache.dispose());

  Future<void> pump(
    WidgetTester tester, {
    AppBackground background = _colorBackground,
    DiaryPreviewPageTransition transition = DiaryPreviewPageTransition.stack,
    AppBackgroundArea area = AppBackgroundArea.preview,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        cache: cache,
        background: background,
        transition: transition,
        area: area,
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final transition in <DiaryPreviewPageTransition>[
    DiaryPreviewPageTransition.stack,
    DiaryPreviewPageTransition.fade,
  ]) {
    testWidgets('${transition.name} gives every page its own opaque '
        'background', (tester) async {
      await pump(tester, transition: transition);
      // 当前页与预先构建的下一页各一份，都在各自的过渡层里。
      expect(_copyIn(0), findsOneWidget);
      expect(_copyIn(1), findsOneWidget);
      // 画的是同一块区域背景：同样的纯色。
      final colors = tester
          .widgetList<ColoredBox>(
            find.descendant(
              of: _copyIn(1),
              matching: find.byType(ColoredBox, skipOffstage: false),
              skipOffstage: false,
            ),
          )
          .map((box) => box.color);
      expect(colors, contains(_color));
      // 每份背景与页面一样大（与页面背景重合，静止时看起来不变）。
      expect(
        tester.getRect(_copyIn(0)),
        const Offset(0, 0) & const Size(400, 800),
      );

      // 拖到一半：下一篇盖在当前篇上，它自己的背景挡住下面那篇。
      final gesture = await tester.startGesture(const Offset(300, 600));
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(-8, 0));
        await tester.pump(const Duration(milliseconds: 8));
      }
      // 两篇都露在视口里、叠在一起，各自的背景都在。
      expect(find.byType(AppPageBackgroundCopy), findsNWidgets(2));
      for (var i = 0; i < 40; i++) {
        await gesture.moveBy(const Offset(-8, 0));
        await tester.pump(const Duration(milliseconds: 8));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('第 1 页'), findsOneWidget);
    });
  }

  testWidgets('slide keeps pages transparent over the still background', (
    tester,
  ) async {
    await pump(tester, transition: DiaryPreviewPageTransition.slide);
    expect(_copies, findsNothing);
  });

  testWidgets('no copy without a preview background', (tester) async {
    await pump(tester, background: AppBackground.defaults);
    expect(_copies, findsNothing);
    // 其他区域（设置页的实时预览）照旧铺“桌面”，不垫背景。
    await pump(tester, area: AppBackgroundArea.settings);
    expect(_copies, findsNothing);
  });

  testWidgets('switching the transition keeps the pages mounted', (
    tester,
  ) async {
    await pump(tester, transition: DiaryPreviewPageTransition.slide);
    final created = _Page.created;
    await pump(tester, transition: DiaryPreviewPageTransition.stack);
    expect(_copies, findsWidgets);
    await pump(tester, transition: DiaryPreviewPageTransition.slide);
    expect(_copies, findsNothing);
    expect(_Page.created, created);
  });

  testWidgets('an image background is copied with the same image and focus', (
    tester,
  ) async {
    await pump(tester, background: _imageBackground);
    // 等假加载器在真实异步里产出图片。
    for (var i = 0; i < 40 && find.byType(RawImage).evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    final images = tester
        .widgetList<RawImage>(find.byType(RawImage, skipOffstage: false))
        .toList();
    // 页面背景一份 + 两篇各一份。
    expect(images, hasLength(3));
    for (final image in images.skip(1)) {
      expect(image.image!.isCloneOf(images.first.image!), isTrue);
      expect(image.fit, BoxFit.cover);
      expect(image.alignment, images.first.alignment);
    }
    expect(images.first.alignment, const Alignment(0.4, -0.2));
    expect(
      find.descendant(of: _copyIn(0), matching: find.byType(RawImage)),
      findsOneWidget,
    );
  });
}

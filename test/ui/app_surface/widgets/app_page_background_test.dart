import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_settings.dart';
import 'package:node_diary/ui/app_surface/providers/app_surface_settings_provider.dart';
import 'package:node_diary/ui/app_surface/services/app_background_image_cache.dart';
import 'package:node_diary/ui/app_surface/widgets/app_background_layers_view.dart';
import 'package:node_diary/ui/app_surface/widgets/app_page_background.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_card_colors.dart';

import '../app_surface_test_images.dart';

const Color _colorA = Color(0xFF336699);
const Color _colorB = Color(0xFF996633);
const Size _view = Size(400, 800);

/// 固定返回给定设置、可在测试中改写的设置 notifier。
class _FakeSurface extends AppSurfaceSettingsNotifier {
  _FakeSurface(this.initial);

  final AppSurfaceSettings initial;

  @override
  AppSurfaceSettings build() => initial;

  void set(AppSurfaceSettings value) => state = value;
}

AppSurfaceSettings _settings(AppBackground background) =>
    AppSurfaceSettings.defaults.withArea(
      AppBackgroundArea.settings,
      AppAreaBackground(mode: AppAreaBackgroundMode.custom, custom: background),
    );

AppSurfaceSettings _color(Color color) => _settings(
  AppBackground(kind: AppBackgroundKind.color, colorLight: color.toARGB32()),
);

const AppBackground _image = AppBackground(
  kind: AppBackgroundKind.image,
  image: 'bg.png',
  alignX: 0.5,
  scrimLight: 0.3,
);

AppBackgroundImageKey get _imageKey => AppBackgroundImageKey.forDisplay(
  fileName: 'bg.png',
  blur: 0,
  logicalSize: _view,
  devicePixelRatio: 1,
);

/// 页面内一个有状态的小部件：记录 initState 次数，验证结构切换不重建。
class _Probe extends StatefulWidget {
  const _Probe();

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
  Widget build(BuildContext context) => const SizedBox.expand();
}

class _Harness {
  _Harness(this.surface, this.loader);

  final _FakeSurface surface;
  final FakeBackgroundLoader loader;
  late AppPageBackdrop backdrop;
  late ColorScheme scheme;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  required AppSurfaceSettings settings,
  Brightness brightness = Brightness.light,
  bool reduceMotion = false,
  FakeBackgroundLoader? loader,
  bool warmImage = false,
  bool deferScrim = false,
}) async {
  tester.view.physicalSize = _view;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness = _Harness(
    _FakeSurface(settings),
    loader ?? FakeBackgroundLoader(),
  );
  final cache = AppBackgroundImageCache(loader: harness.loader.call);
  addTearDown(cache.dispose);
  if (warmImage) {
    await tester.runAsync(() async => (await cache.load(_imageKey))?.dispose());
  }
  final theme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: brightness,
    ),
  );
  harness.scheme = theme.colorScheme;
  _Probe.created = 0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSurfaceSettingsProvider.overrideWith(() => harness.surface),
        appBackgroundImageCacheProvider.overrideWithValue(cache),
      ],
      child: MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: AppPageBackground(
          area: AppBackgroundArea.settings,
          deferScrim: deferScrim,
          child: Builder(
            builder: (BuildContext context) {
              harness.backdrop = AppPageBackdrop.of(context);
              return Scaffold(
                backgroundColor: AppPageBackdrop.pageColorOf(context),
                body: const _Probe(),
              );
            },
          ),
        ),
      ),
    ),
  );
  return harness;
}

/// 背景层里各层的 FadeTransition（自下而上）。
List<FadeTransition> _layers(WidgetTester tester) => tester
    .widgetList<FadeTransition>(
      find.descendant(
        of: find.byType(AppBackgroundLayersView),
        matching: find.byType(FadeTransition),
      ),
    )
    .toList();

/// 背景层里铺满的纯色（自下而上）。
List<Color> _layerColors(WidgetTester tester) => tester
    .widgetList<ColoredBox>(
      find.descendant(
        of: find.byType(AppBackgroundLayersView),
        matching: find.byType(ColoredBox),
      ),
    )
    .map((box) => box.color)
    .toList();

Color _scaffoldColor(WidgetTester tester) =>
    tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor!;

/// 等真实异步（图片解码）完成并推进帧。
Future<void> _settleAsync(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 40 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

void main() {
  testWidgets('no background keeps the page color and adds no layers', (
    tester,
  ) async {
    final harness = await _pump(tester, settings: AppSurfaceSettings.defaults);
    final surface = harness.scheme.surface;

    expect(harness.backdrop.hasBackground, isFalse);
    expect(harness.backdrop.area, AppBackgroundArea.settings);
    expect(harness.backdrop.pageColor, surface);
    expect(harness.backdrop.solidBarColor, surface);
    expect(harness.backdrop.estimatedColor, surface);
    expect(harness.backdrop.contentBackdropKey, isNotNull);
    expect(_scaffoldColor(tester), surface);
    // 页面与背景组件之间只有不绘制的节点（InheritedWidget、KeyedSubtree）
    // 和测试自己的 Builder。
    expect(find.byType(AppBackgroundLayersView), findsNothing);
    final between = <Type>[];
    tester.element(find.byType(Scaffold)).visitAncestorElements((element) {
      if (element.widget is AppPageBackground) return false;
      between.add(element.widget.runtimeType);
      return true;
    });
    expect(between, <Type>[Builder, KeyedSubtree, AppPageBackdropScope]);
  });

  testWidgets('of() without an ancestor falls back to the plain theme values', (
    tester,
  ) async {
    late AppPageBackdrop backdrop;
    late ColorScheme scheme;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            backdrop = AppPageBackdrop.of(context);
            scheme = Theme.of(context).colorScheme;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(backdrop.area, isNull);
    expect(backdrop.hasBackground, isFalse);
    expect(backdrop.pageColor, scheme.surface);
    expect(backdrop.solidBarColor, scheme.surface);
    expect(backdrop.estimatedColor, scheme.surface);
    expect(backdrop.contentBackdropKey, isNull);
  });

  testWidgets('a color background makes the page transparent over it', (
    tester,
  ) async {
    final harness = await _pump(tester, settings: _color(_colorA));

    expect(harness.backdrop.hasBackground, isTrue);
    expect(harness.backdrop.hasImage, isFalse);
    expect(harness.backdrop.pageColor, Colors.transparent);
    expect(harness.backdrop.solidBarColor, _colorA);
    expect(harness.backdrop.estimatedColor, _colorA);
    expect(_scaffoldColor(tester), Colors.transparent);
    // 首帧直接显示，不淡入。
    expect(_layerColors(tester), <Color>[_colorA]);
    expect(_layers(tester).single.opacity.value, 1);
  });

  testWidgets('dark theme derives the dark color when only light is set', (
    tester,
  ) async {
    final harness = await _pump(
      tester,
      settings: _color(_colorA),
      brightness: Brightness.dark,
    );
    final dark = DiaryCardColors.deriveDark(
      _colorA,
      DiaryCardColorRole.surface,
    );
    expect(_layerColors(tester), <Color>[dark]);
    expect(harness.backdrop.solidBarColor, dark);
  });

  testWidgets('changing the color cross-fades over the opaque old layer', (
    tester,
  ) async {
    final harness = await _pump(tester, settings: _color(_colorA));
    harness.surface.set(_color(_colorB));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(_layerColors(tester), <Color>[_colorA, _colorB]);
    final layers = _layers(tester);
    expect(layers.first.opacity.value, 1);
    expect(layers.last.opacity.value, inExclusiveRange(0, 1));
    expect(harness.backdrop.solidBarColor, _colorB);

    await tester.pumpAndSettle();
    expect(_layerColors(tester), <Color>[_colorB]);
    expect(_layers(tester).single.opacity.value, 1);
  });

  testWidgets('removing the background fades to the page color, then nothing', (
    tester,
  ) async {
    final harness = await _pump(tester, settings: _color(_colorA));
    harness.surface.set(AppSurfaceSettings.defaults);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 淡出期间页面仍透明，淡入的是主题页面底色。
    expect(_scaffoldColor(tester), Colors.transparent);
    expect(_layerColors(tester), <Color>[_colorA, harness.scheme.surface]);

    await tester.pumpAndSettle();
    expect(find.byType(AppBackgroundLayersView), findsNothing);
    expect(_scaffoldColor(tester), harness.scheme.surface);
    expect(harness.backdrop.hasBackground, isFalse);
  });

  testWidgets('reduce motion switches backgrounds at once', (tester) async {
    final harness = await _pump(
      tester,
      settings: _color(_colorA),
      reduceMotion: true,
    );
    harness.surface.set(_color(_colorB));
    await tester.pump();
    expect(_layerColors(tester), <Color>[_colorB]);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('switching structure keeps the page state', (tester) async {
    final harness = await _pump(tester, settings: AppSurfaceSettings.defaults);
    expect(_Probe.created, 1);
    harness.surface.set(_color(_colorA));
    await tester.pumpAndSettle();
    expect(find.byType(AppBackgroundLayersView), findsOneWidget);
    harness.surface.set(AppSurfaceSettings.defaults);
    await tester.pumpAndSettle();
    expect(find.byType(AppBackgroundLayersView), findsNothing);
    expect(_Probe.created, 1);
  });

  testWidgets('a cached image shows at once with scrim and estimated color', (
    tester,
  ) async {
    final harness = await _pump(
      tester,
      settings: _settings(_image),
      warmImage: true,
    );
    final scheme = harness.scheme;
    final raw = tester.widget<RawImage>(find.byType(RawImage));
    expect(raw.fit, BoxFit.cover);
    expect(raw.alignment, const Alignment(0.5, 0));
    final scrim = scheme.surface.withValues(alpha: 0.3);
    expect(_layerColors(tester), contains(scrim));
    expect(harness.backdrop.hasImage, isTrue);
    expect(harness.backdrop.pageColor, Colors.transparent);
    // 图片背景上的实色栏保持不透明的 surface。
    expect(harness.backdrop.solidBarColor, scheme.surface);
    expect(
      harness.backdrop.estimatedColor,
      Color.alphaBlend(
        scrim,
        Color.alphaBlend(harness.loader.color, scheme.surface),
      ),
    );
    expect(harness.loader.requests, hasLength(1));
  });

  testWidgets('deferScrim hands the image scrim to the page', (tester) async {
    final harness = await _pump(
      tester,
      settings: _settings(_image),
      warmImage: true,
      deferScrim: true,
    );
    final scrim = harness.scheme.surface.withValues(alpha: 0.3);
    // 背景层只画图，不画遮罩；遮罩经 backdrop 交给页面，页面底色就是它。
    expect(find.byType(RawImage), findsOneWidget);
    expect(_layerColors(tester), isNot(contains(scrim)));
    expect(harness.backdrop.deferredScrim, scrim);
    expect(harness.backdrop.pageColor, scrim);
    expect(_scaffoldColor(tester), scrim);
    // 估计色照常含遮罩：页面总会画上它。
    expect(
      harness.backdrop.estimatedColor,
      Color.alphaBlend(
        scrim,
        Color.alphaBlend(harness.loader.color, harness.scheme.surface),
      ),
    );
  });

  testWidgets('deferScrim leaves color backgrounds as they were', (
    tester,
  ) async {
    final harness = await _pump(
      tester,
      settings: _color(_colorA),
      deferScrim: true,
    );
    expect(harness.backdrop.deferredScrim, isNull);
    expect(harness.backdrop.pageColor, Colors.transparent);
  });

  testWidgets('an image still decoding keeps the page plain, then fades in', (
    tester,
  ) async {
    final harness = await _pump(tester, settings: _settings(_image));
    expect(find.byType(RawImage), findsNothing);
    expect(_scaffoldColor(tester), harness.scheme.surface);

    await _settleAsync(
      tester,
      () => find.byType(RawImage).evaluate().isNotEmpty,
    );
    expect(find.byType(RawImage), findsOneWidget);
    // 淡入时下面垫着不透明的页面底色。
    expect(_layers(tester), hasLength(2));
    expect(_scaffoldColor(tester), Colors.transparent);

    await tester.pumpAndSettle();
    expect(_layers(tester), hasLength(1));
    expect(harness.backdrop.hasImage, isTrue);
  });

  testWidgets('a missing image renders as no background', (tester) async {
    final loader = FakeBackgroundLoader()..missing.add('bg.png');
    final harness = await _pump(
      tester,
      settings: _settings(_image),
      loader: loader,
    );
    await _settleAsync(tester, () => loader.requests.isNotEmpty);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RawImage), findsNothing);
    expect(_scaffoldColor(tester), harness.scheme.surface);
    expect(harness.backdrop.hasBackground, isFalse);
  });

  testWidgets('moving the focus of the same image updates in place', (
    tester,
  ) async {
    final harness = await _pump(
      tester,
      settings: _settings(_image),
      warmImage: true,
    );
    harness.surface.set(
      _settings(_image.copyWith(alignX: -1, scrimLight: 0.6)),
    );
    await tester.pump();
    // 不交叉淡入：仍只有一层，焦点与遮罩已更新。
    expect(_layers(tester), hasLength(1));
    expect(
      tester.widget<RawImage>(find.byType(RawImage)).alignment,
      const Alignment(-1, 0),
    );
    expect(
      _layerColors(tester),
      contains(harness.scheme.surface.withValues(alpha: 0.6)),
    );
    expect(harness.loader.requests, hasLength(1));
  });
}

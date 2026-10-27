import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/app_effects.dart';
import 'package:node_diary/app/theme/app_radii.dart';
import 'package:node_diary/app/theme/expressive_surfaces.dart';
import 'package:node_diary/ui/app_surface/models/app_glass_style.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_card_surface.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_scope.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_surface.dart';
import 'package:node_diary/ui/app_surface/widgets/app_page_backdrop.dart';
import 'package:node_diary/ui/settings/widgets/settings_card_group.dart';
import 'package:node_diary/ui/widgets/glass/glass_surface.dart';

const AppGlassStyle _glass = AppGlassStyle(mode: AppGlassMode.glass);

/// 挂上（或不挂）材质 scope 与页面背景信息的测试外壳。
Widget _host({
  AppGlassStyle? style,
  AppPageBackdrop Function(ColorScheme scheme)? backdrop,
  bool highContrast = false,
  ThemeData? theme,
  required Widget child,
}) {
  Widget body = Center(child: SizedBox(width: 300, child: child));
  return MaterialApp(
    theme: theme,
    home: Builder(
      builder: (BuildContext context) {
        Widget content = body;
        final makeBackdrop = backdrop;
        if (makeBackdrop != null) {
          content = AppPageBackdropScope(
            backdrop: makeBackdrop(Theme.of(context).colorScheme),
            child: content,
          );
        }
        if (style != null) {
          content = AppGlassScope(style: style, child: content);
        }
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(highContrast: highContrast),
          child: Scaffold(body: content),
        );
      },
    ),
  );
}

AppPageBackdrop _imageBackdrop(ColorScheme scheme, BackdropKey key) =>
    AppPageBackdrop(
      area: AppBackgroundArea.settings,
      hasBackground: true,
      hasImage: true,
      pageColor: Colors.transparent,
      solidBarColor: scheme.surface,
      estimatedColor: scheme.surface,
      contentBackdropKey: key,
    );

BackdropFilter _onlyFilter(WidgetTester tester) =>
    tester.widget<BackdropFilter>(find.byType(BackdropFilter));

void main() {
  group('AppGlass.of', () {
    testWidgets('没有 scope 时按默认：全部经典', (WidgetTester tester) async {
      late AppGlassResolved resolved;
      await tester.pumpWidget(
        _host(
          child: Builder(
            builder: (BuildContext context) {
              resolved = AppGlass.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      for (final component in AppGlassComponent.values) {
        expect(resolved.isGlass(component), isFalse, reason: '$component');
      }
    });

    testWidgets('挂 scope 后 follow / classic / glass 覆盖生效', (
      WidgetTester tester,
    ) async {
      final style = _glass
          .withOverride(AppGlassComponent.cards, AppGlassOverride.classic)
          .withOverride(AppGlassComponent.dialogs, AppGlassOverride.follow);
      final classicWithGlassBars = const AppGlassStyle().withOverride(
        AppGlassComponent.topBars,
        AppGlassOverride.glass,
      );
      late AppGlassResolved a;
      late AppGlassResolved b;
      await tester.pumpWidget(
        _host(
          child: Column(
            children: <Widget>[
              AppGlassScope(
                style: style,
                child: Builder(
                  builder: (BuildContext context) {
                    a = AppGlass.of(context);
                    return const SizedBox();
                  },
                ),
              ),
              AppGlassScope(
                style: classicWithGlassBars,
                child: Builder(
                  builder: (BuildContext context) {
                    b = AppGlass.of(context);
                    return const SizedBox();
                  },
                ),
              ),
            ],
          ),
        ),
      );
      expect(a.isGlass(AppGlassComponent.cards), isFalse);
      expect(a.isGlass(AppGlassComponent.dialogs), isTrue);
      expect(a.isGlass(AppGlassComponent.topBars), isTrue);
      expect(b.isGlass(AppGlassComponent.topBars), isTrue);
      expect(b.isGlass(AppGlassComponent.cards), isFalse);
    });

    testWidgets('按所在位置的主题明暗解析', (WidgetTester tester) async {
      late AppGlassResolved resolved;
      final dark = ThemeData(brightness: Brightness.dark);
      await tester.pumpWidget(
        _host(
          style: _glass,
          child: Theme(
            data: dark,
            child: Builder(
              builder: (BuildContext context) {
                resolved = AppGlass.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(
        resolved.tint,
        dark.colorScheme.surfaceContainerHigh.withValues(alpha: 0.72),
      );
    });
  });

  group('AppGlassSurface', () {
    testWidgets('卡片默认取页面的 contentBackdropKey；无背景图时不模糊', (
      WidgetTester tester,
    ) async {
      final key = BackdropKey();
      await tester.pumpWidget(
        _host(
          style: _glass,
          backdrop: (ColorScheme scheme) =>
              AppPageBackdrop.plain(scheme, contentBackdropKey: key),
          child: const AppGlassSurface(
            component: AppGlassComponent.cards,
            child: SizedBox(height: 40),
          ),
        ),
      );
      final filter = _onlyFilter(tester);
      expect(filter.backdropGroupKey, same(key));
      expect(filter.enabled, isFalse);
    });

    testWidgets('页面背景是图片时 auto 开模糊；none 始终不模糊', (WidgetTester tester) async {
      final key = BackdropKey();
      await tester.pumpWidget(
        _host(
          style: _glass,
          backdrop: (ColorScheme scheme) => _imageBackdrop(scheme, key),
          child: const Column(
            children: <Widget>[
              AppGlassSurface(
                component: AppGlassComponent.cards,
                child: SizedBox(height: 40),
              ),
              AppGlassSurface(
                component: AppGlassComponent.cards,
                blur: AppGlassBlur.none,
                child: SizedBox(height: 40),
              ),
            ],
          ),
        ),
      );
      final filters = tester
          .widgetList<BackdropFilter>(find.byType(BackdropFilter))
          .toList();
      expect(filters, hasLength(2));
      expect(filters[0].enabled, isTrue);
      expect(filters[0].backdropGroupKey, same(key));
      expect(filters[1].enabled, isFalse);
    });

    testWidgets('非卡片组件不分组；always 在无背景时也模糊', (WidgetTester tester) async {
      final key = BackdropKey();
      await tester.pumpWidget(
        _host(
          style: _glass,
          backdrop: (ColorScheme scheme) =>
              AppPageBackdrop.plain(scheme, contentBackdropKey: key),
          child: const AppGlassSurface(
            component: AppGlassComponent.toolbar,
            blur: AppGlassBlur.always,
            child: SizedBox(height: 40),
          ),
        ),
      );
      final filter = _onlyFilter(tester);
      expect(filter.backdropGroupKey, isNull);
      expect(filter.enabled, isTrue);
    });

    testWidgets('高对比度：不透明底色、不模糊', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          style: _glass,
          highContrast: true,
          child: const AppGlassSurface(
            component: AppGlassComponent.toolbar,
            blur: AppGlassBlur.always,
            child: SizedBox(height: 40),
          ),
        ),
      );
      expect(_onlyFilter(tester).enabled, isFalse);
      final glass = tester.widget<GlassSurface>(find.byType(GlassSurface));
      expect(glass.fill.a, 1.0);
    });

    testWidgets('自定义深色底色时子树前景换成可读色；够看时结构相同、颜色不变', (WidgetTester tester) async {
      Color? onSurface;
      Widget probe() => Builder(
        builder: (BuildContext context) {
          onSurface = Theme.of(context).colorScheme.onSurface;
          return const SizedBox(height: 40);
        },
      );
      const darkTint = AppGlassStyle(
        mode: AppGlassMode.glass,
        tint: AppGlassTint.custom,
        tintColor: 0xFF101010,
        tintOpacity: 0.95,
      );
      await tester.pumpWidget(
        _host(
          style: darkTint,
          child: AppGlassSurface(
            component: AppGlassComponent.cards,
            child: probe(),
          ),
        ),
      );
      final theme = Theme.of(tester.element(find.byType(Scaffold)));
      expect(onSurface, isNot(theme.colorScheme.onSurface));
      expect(find.byType(AppGlassForegroundTheme), findsOneWidget);

      const lightTint = AppGlassStyle(
        mode: AppGlassMode.glass,
        tint: AppGlassTint.custom,
        tintColor: 0xFFFAFAFA,
      );
      await tester.pumpWidget(
        _host(
          style: lightTint,
          child: AppGlassSurface(
            component: AppGlassComponent.cards,
            child: probe(),
          ),
        ),
      );
      expect(onSurface, theme.colorScheme.onSurface);
      expect(find.byType(AppGlassForegroundTheme), findsOneWidget);
    });

    testWidgets('非自定义底色不插入前景主题节点', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          style: _glass,
          child: const AppGlassSurface(
            component: AppGlassComponent.cards,
            child: SizedBox(height: 40),
          ),
        ),
      );
      expect(find.byType(AppGlassForegroundTheme), findsNothing);
    });
  });

  group('AppCardSurface / SettingsCardGroup', () {
    testWidgets('经典分支与原来的 Container + Material 写法结构一致', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(child: const AppCardSurface(child: SizedBox(height: 40))),
      );
      final scheme = Theme.of(
        tester.element(find.byType(AppCardSurface)),
      ).colorScheme;
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppCardSurface),
          matching: find.byType(Container),
        ),
      );
      expect(
        container.decoration,
        BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: ExpressiveSurfaces.cardBorderColor(scheme),
            width: 0.8,
          ),
          boxShadow: AppEffects.restingCardShadow(scheme),
        ),
      );
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(Container),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, ExpressiveSurfaces.cardColor(scheme));
      expect(material.borderRadius, BorderRadius.circular(AppRadii.card));
      expect(material.clipBehavior, Clip.antiAlias);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('SettingsCardGroup 经典时与改动前逐像素一致', (WidgetTester tester) async {
      final boundary = GlobalKey();
      Future<List<int>> capture(Widget card) async {
        await tester.pumpWidget(
          _host(
            child: RepaintBoundary(key: boundary, child: card),
          ),
        );
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final bytes = await tester.runAsync(() async {
          final image = await render.toImage();
          final data = await image.toByteData();
          image.dispose();
          return data!.buffer.asUint8List().toList();
        });
        return bytes!;
      }

      const rows = <Widget>[
        ListTile(title: Text('a')),
        ListTile(title: Text('b')),
      ];
      final current = await capture(
        const SettingsCardGroup(title: 'T', footer: 'F', children: rows),
      );
      final legacy = await capture(
        const _LegacySettingsCardGroup(title: 'T', footer: 'F', children: rows),
      );
      // 确认真的画出了东西，免得两张空图相等。
      expect(current.any((int b) => b != 0), isTrue);
      expect(current, legacy);
    });

    testWidgets('玻璃时共用页面的 contentBackdropKey，无图不模糊、有图模糊', (
      WidgetTester tester,
    ) async {
      final key = BackdropKey();
      const group = SettingsCardGroup(
        children: <Widget>[ListTile(title: Text('a'))],
      );
      await tester.pumpWidget(
        _host(
          style: _glass,
          backdrop: (ColorScheme scheme) =>
              AppPageBackdrop.plain(scheme, contentBackdropKey: key),
          child: group,
        ),
      );
      expect(find.byType(GlassSurface), findsOneWidget);
      expect(_onlyFilter(tester).backdropGroupKey, same(key));
      expect(_onlyFilter(tester).enabled, isFalse);

      await tester.pumpWidget(
        _host(
          style: _glass,
          backdrop: (ColorScheme scheme) => _imageBackdrop(scheme, key),
          child: group,
        ),
      );
      expect(_onlyFilter(tester).backdropGroupKey, same(key));
      expect(_onlyFilter(tester).enabled, isTrue);
    });

    testWidgets('玻璃卡片里的 InkWell 水波纹画在玻璃的 Material 上', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          style: _glass,
          child: AppCardSurface(
            child: InkWell(onTap: () {}, child: const SizedBox(height: 40)),
          ),
        ),
      );
      await tester.tap(find.byType(InkWell));
      await tester.pump(const Duration(milliseconds: 50));
      final inkMaterial = Material.of(tester.element(find.byType(InkWell)));
      final glassMaterial = tester.widget<Material>(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(Material),
        ),
      );
      expect(glassMaterial.type, MaterialType.canvas);
      expect(inkMaterial, isNotNull);
      expect(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(InkWell),
        ),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
    });
  });
}

/// 改动前 `SettingsCardGroup` 的原样副本，只用于逐像素对比。
class _LegacySettingsCardGroup extends StatelessWidget {
  const _LegacySettingsCardGroup({
    this.title,
    this.footer,
    required this.children,
  });

  final String? title;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 8),
              child: Text(
                title!,
                style: textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(
                color: ExpressiveSurfaces.cardBorderColor(colorScheme),
                width: 0.8,
              ),
              boxShadow: AppEffects.restingCardShadow(colorScheme),
            ),
            child: Material(
              color: ExpressiveSurfaces.cardColor(colorScheme),
              borderRadius: BorderRadius.circular(AppRadii.card),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (var i = 0; i < children.length; i++) ...[
                    children[i],
                    if (i < children.length - 1)
                      const SettingsCardGroupDivider(),
                  ],
                ],
              ),
            ),
          ),
          if (footer != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 6),
              child: Text(
                footer!,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

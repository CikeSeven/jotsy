import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/app_surface/models/app_glass_style.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_fab.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_scope.dart';
import 'package:node_diary/ui/app_surface/widgets/app_page_backdrop.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_card_colors.dart';
import 'package:node_diary/ui/settings/widgets/settings_card_group.dart';

import '../../../support/expressive_test_theme.dart';

/// 有背景图时的页面背景信息（估计色由测试指定）。
AppPageBackdrop _imageBackdrop(ColorScheme scheme, Color estimated) =>
    AppPageBackdrop(
      area: AppBackgroundArea.settings,
      hasBackground: true,
      hasImage: true,
      pageColor: Colors.transparent,
      solidBarColor: scheme.surface,
      estimatedColor: estimated,
    );

/// 纯色背景时的页面背景信息。
AppPageBackdrop _colorBackdrop(ColorScheme scheme, Color color) =>
    AppPageBackdrop(
      area: AppBackgroundArea.settings,
      hasBackground: true,
      hasImage: false,
      pageColor: Colors.transparent,
      solidBarColor: color,
      estimatedColor: color,
    );

/// 主题 + 可选材质 + 可选页面背景的外壳；[child] 在两者之下构建。
Widget _host({
  Brightness brightness = Brightness.light,
  AppGlassStyle? glass,
  AppPageBackdrop Function(ColorScheme scheme)? backdrop,
  required Widget child,
}) {
  final theme = expressiveTestTheme(brightness);
  Widget body = child;
  if (backdrop != null) {
    body = AppPageBackdropScope(
      backdrop: backdrop(theme.colorScheme),
      child: body,
    );
  }
  return MaterialApp(
    theme: theme,
    builder: (BuildContext context, Widget? child) =>
        glass == null ? child! : AppGlassScope(style: glass, child: child!),
    home: Scaffold(body: body),
  );
}

/// 在外壳里取得一个 context 交给 [probe]。
Future<void> _withContext(
  WidgetTester tester,
  void Function(BuildContext context) probe, {
  Brightness brightness = Brightness.light,
  AppPageBackdrop Function(ColorScheme scheme)? backdrop,
}) async {
  await tester.pumpWidget(
    _host(
      brightness: brightness,
      backdrop: backdrop,
      child: Builder(
        builder: (BuildContext context) {
          probe(context);
          return const SizedBox();
        },
      ),
    ),
  );
}

void main() {
  group('AppPageBackdrop.onBackgroundTextStyle', () {
    const style = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);

    testWidgets('returns the same style without a background image', (
      tester,
    ) async {
      // 没有页面背景、纯色背景：原样返回（同一个对象），null 仍是 null。
      for (final backdrop in <AppPageBackdrop Function(ColorScheme)?>[
        null,
        (scheme) => _colorBackdrop(scheme, const Color(0xFF203040)),
      ]) {
        await _withContext(tester, backdrop: backdrop, (context) {
          final primary = style.copyWith(
            color: Theme.of(context).colorScheme.primary,
          );
          expect(
            AppPageBackdrop.onBackgroundTextStyle(context, primary),
            same(primary),
          );
          expect(AppPageBackdrop.onBackgroundTextStyle(context, null), isNull);
        });
      }
    });

    for (final brightness in Brightness.values) {
      testWidgets('adds a surface halo and keeps a readable color '
          '(${brightness.name})', (tester) async {
        await _withContext(
          tester,
          brightness: brightness,
          // 估计色就是 surface：主题文字色本来就看得清。
          backdrop: (scheme) => _imageBackdrop(scheme, scheme.surface),
          (context) {
            final scheme = Theme.of(context).colorScheme;
            final input = style.copyWith(color: scheme.onSurface);
            final result = AppPageBackdrop.onBackgroundTextStyle(
              context,
              input,
            )!;
            expect(result.color, scheme.onSurface);
            // 只改颜色与光晕，字号、字重不变。
            expect(result.fontSize, input.fontSize);
            expect(result.fontWeight, input.fontWeight);
            expect(result.shadows, hasLength(2));
            for (final shadow in result.shadows!) {
              expect(shadow.color.withValues(alpha: 1), scheme.surface);
              expect(shadow.color.a, greaterThan(0.5));
              expect(shadow.blurRadius, greaterThan(0));
            }
            expect(
              result.shadows!
                  .map((s) => s.blurRadius)
                  .reduce((a, b) => a > b ? a : b),
              inInclusiveRange(6, 10),
            );
          },
        );
      });

      testWidgets('swaps a low-contrast color for a readable one '
          '(${brightness.name})', (tester) async {
        await _withContext(
          tester,
          brightness: brightness,
          // 估计色与 primary 几乎相同：primary 文字看不清。
          backdrop: (scheme) => _imageBackdrop(scheme, scheme.primary),
          (context) {
            final scheme = Theme.of(context).colorScheme;
            final result = AppPageBackdrop.onBackgroundTextStyle(
              context,
              style.copyWith(color: scheme.primary),
            )!;
            expect(result.color, isNot(scheme.primary));
            // 换成 onSurface / surface 中对比度更高的一个。
            expect(
              result.color,
              DiaryCardColors.bestContrast(<Color>[
                scheme.onSurface,
                scheme.surface,
              ], scheme.primary),
            );
            expect(
              DiaryCardColors.contrastRatio(result.color!, scheme.primary),
              greaterThan(3),
            );
            // 光晕与文字反差最大：文字换成 surface 色时光晕用 onSurface。
            final halo = result.shadows!.first.color.withValues(alpha: 1);
            expect(halo, isNot(result.color));
            expect(halo, anyOf(scheme.onSurface, scheme.surface));
          },
        );
      });
    }

    testWidgets('a null style falls back to the default text color', (
      tester,
    ) async {
      await _withContext(
        tester,
        backdrop: (scheme) => _imageBackdrop(scheme, scheme.surface),
        (context) {
          final result = AppPageBackdrop.onBackgroundTextStyle(context, null)!;
          expect(result.color, DefaultTextStyle.of(context).style.color);
          expect(result.shadows, isNotEmpty);
        },
      );
    });

    testWidgets('keeps shadows the style already had', (tester) async {
      await _withContext(
        tester,
        backdrop: (scheme) => _imageBackdrop(scheme, scheme.surface),
        (context) {
          const own = Shadow(color: Color(0x80FF0000), blurRadius: 1);
          final result = AppPageBackdrop.onBackgroundTextStyle(
            context,
            style.copyWith(shadows: const <Shadow>[own]),
          )!;
          expect(result.shadows!.first, own);
          expect(result.shadows, hasLength(3));
        },
      );
    });
  });

  group('SettingsCardGroup on the page background', () {
    Widget group() => const SettingsCardGroup(
      title: '主题',
      footer: '附注',
      children: <Widget>[ListTile(title: Text('项'))],
    );

    TextStyle styleOf(WidgetTester tester, String text) =>
        tester.widget<Text>(find.text(text)).style!;

    testWidgets('title and footer styles are unchanged without an image', (
      tester,
    ) async {
      await tester.pumpWidget(_host(child: group()));
      final theme = Theme.of(tester.element(find.text('主题')));
      expect(
        styleOf(tester, '主题'),
        theme.textTheme.titleMedium?.copyWith(
          fontSize: 16,
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      );
      expect(
        styleOf(tester, '附注'),
        theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    });

    testWidgets('title and footer get the halo over an image', (tester) async {
      await tester.pumpWidget(
        _host(
          backdrop: (scheme) => _imageBackdrop(scheme, scheme.surface),
          child: group(),
        ),
      );
      expect(styleOf(tester, '主题').shadows, isNotEmpty);
      expect(styleOf(tester, '附注').shadows, isNotEmpty);
      // 卡片里的文字不受影响。
      expect(tester.widget<Text>(find.text('项')).style?.shadows, isNull);
    });
  });

  group('AppGlassFab foreground', () {
    const glass = AppGlassStyle(mode: AppGlassMode.glass);

    /// FAB 里图标实际拿到的前景色。
    Color foreground(WidgetTester tester) =>
        IconTheme.of(tester.element(find.byType(FaIcon))).color!;

    Future<void> pumpFab(
      WidgetTester tester, {
      required Brightness brightness,
      Color? estimated,
      AppGlassStyle style = glass,
    }) {
      return tester.pumpWidget(
        _host(
          brightness: brightness,
          glass: style,
          backdrop: estimated == null
              ? null
              : (scheme) => _imageBackdrop(scheme, estimated),
          child: Center(
            child: AppGlassFab(
              child: FloatingActionButton(
                heroTag: null,
                onPressed: () {},
                child: const FaIcon(FontAwesomeIcons.plus),
              ),
            ),
          ),
        ),
      );
    }

    for (final brightness in Brightness.values) {
      testWidgets('is readable over the glass fill (${brightness.name})', (
        tester,
      ) async {
        var swapped = 0;
        for (final estimated in <Color?>[
          null,
          Colors.white,
          Colors.black,
          const Color(0xFF808080),
        ]) {
          await pumpFab(tester, brightness: brightness, estimated: estimated);
          final context = tester.element(find.byType(FaIcon));
          final scheme = Theme.of(context).colorScheme;
          final resolved = AppGlass.of(context);
          final under = Color.alphaBlend(
            estimated ?? scheme.surface,
            scheme.surface,
          );
          final effective = Color.alphaBlend(
            AppGlassFab.fillOf(resolved, scheme),
            under,
          );
          final preferred = scheme.onPrimaryContainer;
          final actual = foreground(tester);
          if (DiaryCardColors.contrastRatio(preferred, effective) >= 4.5) {
            // 主题前景看得清时原样沿用。
            expect(actual, preferred, reason: '$estimated');
          } else {
            swapped++;
            expect(actual, anyOf(scheme.onSurface, scheme.surface));
            expect(
              DiaryCardColors.contrastRatio(actual, effective),
              greaterThan(DiaryCardColors.contrastRatio(preferred, effective)),
              reason: '$estimated',
            );
          }
        }
        // 白 / 黑两种极端里至少有一种让主色容器前景看不清，兜底确实生效。
        expect(swapped, greaterThan(0));
      });
    }

    testWidgets('high contrast keeps onPrimaryContainer on the solid fill', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(highContrast: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      for (final brightness in Brightness.values) {
        await pumpFab(tester, brightness: brightness, estimated: Colors.white);
        final scheme = Theme.of(
          tester.element(find.byType(FaIcon)),
        ).colorScheme;
        expect(foreground(tester), scheme.onPrimaryContainer);
      }
    });
  });
}

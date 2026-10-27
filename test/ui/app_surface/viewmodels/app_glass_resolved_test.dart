import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/app_surface/models/app_glass_style.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/viewmodels/app_glass_resolved.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_card_colors.dart';

final ColorScheme _light = ColorScheme.fromSeed(seedColor: Colors.teal);
final ColorScheme _dark = ColorScheme.fromSeed(
  seedColor: Colors.teal,
  brightness: Brightness.dark,
);

AppGlassResolved _resolve(
  AppGlassStyle style, {
  ColorScheme? scheme,
  bool highContrast = false,
}) => AppGlassResolved.resolve(
  style,
  scheme ?? _light,
  highContrast: highContrast,
);

void main() {
  group('AppGlassResolved 底色', () {
    test(
      '中性底色：亮色 surfaceContainerLowest、暗色 surfaceContainerHigh，透明度取 tintOpacity',
      () {
        const style = AppGlassStyle(tintOpacity: 0.6);
        expect(
          _resolve(style).tint,
          _light.surfaceContainerLowest.withValues(alpha: 0.6),
        );
        expect(
          _resolve(style, scheme: _dark).tint,
          _dark.surfaceContainerHigh.withValues(alpha: 0.6),
        );
      },
    );

    test('主题色底色向 primaryContainer 插值（亮 0.35 / 暗 0.30）', () {
      const style = AppGlassStyle(tint: AppGlassTint.theme);
      expect(
        _resolve(style).tint,
        Color.lerp(
          _light.surfaceContainerLowest,
          _light.primaryContainer,
          0.35,
        )!.withValues(alpha: 0.72),
      );
      expect(
        _resolve(style, scheme: _dark).tint,
        Color.lerp(
          _dark.surfaceContainerHigh,
          _dark.primaryContainer,
          0.30,
        )!.withValues(alpha: 0.72),
      );
    });

    test('自定义底色：浅色原样（去掉透明度），深色优先用户值、否则推导', () {
      const style = AppGlassStyle(
        tint: AppGlassTint.custom,
        tintColor: 0x80FFCC00,
      );
      expect(
        _resolve(style).tint,
        const Color(0xFFFFCC00).withValues(alpha: 0.72),
      );
      expect(
        _resolve(style, scheme: _dark).tint,
        DiaryCardColors.deriveDark(
          const Color(0xFFFFCC00),
          DiaryCardColorRole.surface,
        ).withValues(alpha: 0.72),
      );
      final withDark = style.copyWith(tintColorDark: () => 0xFF112233);
      expect(
        _resolve(withDark, scheme: _dark).tint,
        const Color(0xFF112233).withValues(alpha: 0.72),
      );
    });

    test('自定义却没选颜色时按中性色解读，且不做前景兜底', () {
      const style = AppGlassStyle(tint: AppGlassTint.custom);
      final resolved = _resolve(style);
      expect(
        resolved.tint,
        _light.surfaceContainerLowest.withValues(alpha: 0.72),
      );
      expect(resolved.customTint, isFalse);
    });

    test('越界的透明度与模糊在渲染层夹紧', () {
      const style = AppGlassStyle(tintOpacity: 0.01, blurSigma: 99);
      final resolved = _resolve(style);
      expect(resolved.tint.a, closeTo(0.20, 1e-6));
      expect(resolved.blurSigma, 40);
    });
  });

  group('AppGlassResolved 高对比度与描边', () {
    test('平时半透明、可模糊；fill 为 tint', () {
      final resolved = _resolve(AppGlassStyle.defaults);
      expect(resolved.translucent, isTrue);
      expect(resolved.canBlur, isTrue);
      expect(resolved.fill, resolved.tint);
      expect(
        resolved.solidFill,
        Color.alphaBlend(resolved.tint, _light.surface),
      );
    });

    test('高对比度：不透明 solidFill、不模糊，但 isGlass 仍按设置', () {
      const style = AppGlassStyle(mode: AppGlassMode.glass);
      final resolved = _resolve(style, highContrast: true);
      expect(resolved.translucent, isFalse);
      expect(resolved.canBlur, isFalse);
      expect(resolved.fill, resolved.solidFill);
      expect(resolved.fill.a, 1.0);
      expect(resolved.isGlass(AppGlassComponent.cards), isTrue);
    });

    test('模糊半径为 0 时不模糊', () {
      final resolved = _resolve(const AppGlassStyle(blurSigma: 0));
      expect(resolved.canBlur, isFalse);
    });

    test('描边与顶栏细线随 border 开关；颜色与菜单同口径', () {
      final on = _resolve(AppGlassStyle.defaults);
      expect(
        on.border,
        BorderSide(color: _light.outlineVariant.withValues(alpha: 0.6)),
      );
      expect(on.hairline, _light.outlineVariant.withValues(alpha: 0.35));
      expect(on.shadowColor, _light.shadow.withValues(alpha: 0.12));
      final dark = _resolve(AppGlassStyle.defaults, scheme: _dark);
      expect(dark.border!.color, _dark.outlineVariant.withValues(alpha: 0.5));
      expect(dark.shadowColor, _dark.shadow.withValues(alpha: 0.32));

      final off = _resolve(const AppGlassStyle(border: false));
      expect(off.border, isNull);
      expect(off.hairline, isNull);
    });

    test('按值相等', () {
      expect(
        _resolve(AppGlassStyle.defaults),
        _resolve(AppGlassStyle.defaults),
      );
      expect(
        _resolve(AppGlassStyle.defaults),
        isNot(_resolve(AppGlassStyle.defaults, highContrast: true)),
      );
    });
  });

  group('AppGlassResolved 前景兜底', () {
    test('主题前景看得清时返回 null', () {
      const style = AppGlassStyle(
        tint: AppGlassTint.custom,
        tintColor: 0xFFF5F5F5,
      );
      expect(_resolve(style).foregroundFor(_light.surface), isNull);
    });

    test('很深的自定义底色在亮色主题下把前景换成可读色', () {
      const style = AppGlassStyle(
        tint: AppGlassTint.custom,
        tintColor: 0xFF101010,
        tintOpacity: 0.9,
      );
      final resolved = _resolve(style);
      final fg = resolved.foregroundFor(const Color(0xFF000000));
      expect(fg, isNotNull);
      final effective = Color.alphaBlend(
        resolved.fill,
        const Color(0xFF000000),
      );
      expect(
        DiaryCardColors.contrastRatio(fg!.onSurface, effective),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        DiaryCardColors.contrastRatio(fg.onSurfaceVariant, effective),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('兜底按玻璃下方的实际颜色估算', () {
      const style = AppGlassStyle(
        tint: AppGlassTint.custom,
        tintColor: 0xFF808080,
        tintOpacity: 0.2,
      );
      final resolved = _resolve(style);
      // 浅色背景上主题深色前景看得清；同一底色叠在黑色背景上就看不清了。
      expect(resolved.foregroundFor(const Color(0xFFFFFFFF)), isNull);
      expect(resolved.foregroundFor(const Color(0xFF000000)), isNotNull);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_settings.dart';
import 'package:node_diary/ui/app_surface/viewmodels/app_resolved_background.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_card_colors.dart';

final ColorScheme _light = ColorScheme.fromSeed(seedColor: Colors.teal);
final ColorScheme _dark = ColorScheme.fromSeed(
  seedColor: Colors.teal,
  brightness: Brightness.dark,
);

void main() {
  test('kind none resolves to none in both brightnesses', () {
    expect(
      AppResolvedBackground.resolve(AppBackground.defaults, _light),
      AppResolvedBackground.none,
    );
    expect(
      AppResolvedBackground.resolve(AppBackground.defaults, _dark).isNone,
      isTrue,
    );
  });

  group('color', () {
    const background = AppBackground(
      kind: AppBackgroundKind.color,
      colorLight: 0xFF3366CC,
    );

    test('light theme uses the light value as is', () {
      final resolved = AppResolvedBackground.resolve(background, _light);
      expect(resolved.isColor, isTrue);
      expect(resolved.color, const Color(0xFF3366CC));
    });

    test('dark theme derives a surface-role dark color when none is set', () {
      final resolved = AppResolvedBackground.resolve(background, _dark);
      expect(
        resolved.color,
        DiaryCardColors.deriveDark(
          const Color(0xFF3366CC),
          DiaryCardColorRole.surface,
        ),
      );
      expect(resolved.color!.computeLuminance(), lessThan(0.05));
    });

    test('dark theme prefers the explicit dark value', () {
      final resolved = AppResolvedBackground.resolve(
        background.copyWith(colorDark: () => 0xFF112233),
        _dark,
      );
      expect(resolved.color, const Color(0xFF112233));
    });

    test('a color background without a color falls back to none', () {
      expect(
        AppResolvedBackground.resolve(
          const AppBackground(kind: AppBackgroundKind.color),
          _light,
        ),
        AppResolvedBackground.none,
      );
    });
  });

  group('image', () {
    const background = AppBackground(
      kind: AppBackgroundKind.image,
      image: 'bg_1.png',
      alignX: -0.5,
      alignY: 1,
      blur: 12,
      scrimLight: 0.2,
      scrimDark: 0.6,
    );

    test('carries file, focus, blur and a brightness-specific scrim', () {
      final light = AppResolvedBackground.resolve(background, _light);
      expect(light.isImage, isTrue);
      expect(light.image, 'bg_1.png');
      expect(light.alignment, const Alignment(-0.5, 1));
      expect(light.blur, 12);
      expect(light.scrimColor, _light.surface.withValues(alpha: 0.2));

      final dark = AppResolvedBackground.resolve(background, _dark);
      expect(dark.scrimColor, _dark.surface.withValues(alpha: 0.6));
      expect(dark == light, isFalse);
    });

    test('an image background without a file falls back to none', () {
      expect(
        AppResolvedBackground.resolve(
          const AppBackground(kind: AppBackgroundKind.image),
          _light,
        ),
        AppResolvedBackground.none,
      );
    });

    test('kept fields of other kinds do not leak into the result', () {
      // 从纯色切到图片时，模型里的颜色仍保留；解析结果只看当前种类。
      final resolved = AppResolvedBackground.resolve(
        background.copyWith(colorLight: () => 0xFF000000),
        _light,
      );
      expect(resolved.color, isNull);
    });
  });

  test('equality follows every rendered field', () {
    const a = AppResolvedBackground.color(Color(0xFF123456));
    const b = AppResolvedBackground.color(Color(0xFF123456));
    const c = AppResolvedBackground.color(Color(0xFF654321));
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == c, isFalse);
  });
}

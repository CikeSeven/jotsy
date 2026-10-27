import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_settings.dart';

void main() {
  const image = AppBackground(
    kind: AppBackgroundKind.image,
    image: 'bg_1.jpg',
    alignX: -0.5,
    alignY: 1,
    blur: 12,
    scrimLight: 0.4,
    scrimDark: 0.7,
  );
  const color = AppBackground(
    kind: AppBackgroundKind.color,
    colorLight: 0xFF112233,
    colorDark: 0xFF445566,
  );

  group('AppSurfaceSettings encoding', () {
    test('defaults encode to null and decode back to defaults', () {
      expect(AppSurfaceSettings.defaults.encode(), isNull);
      expect(AppSurfaceSettings.defaults.isDefault, isTrue);
      for (final raw in [null, '', '   ', '{"v":1}']) {
        expect(AppSurfaceSettings.decode(raw), AppSurfaceSettings.defaults);
      }
    });

    test('round-trips every part', () {
      final settings = AppSurfaceSettings.defaults
          .withGlobal(image)
          .withArea(
            AppBackgroundArea.editor,
            const AppAreaBackground(
              mode: AppAreaBackgroundMode.custom,
              custom: color,
            ),
          )
          .withArea(
            AppBackgroundArea.settings,
            const AppAreaBackground(mode: AppAreaBackgroundMode.off),
          )
          .withGlass(
            const AppGlassStyle(
              mode: AppGlassMode.glass,
              blurSigma: 24,
              tintOpacity: 0.5,
              tint: AppGlassTint.custom,
              tintColor: 0xFFABCDEF,
              tintColorDark: 0xFF010203,
              border: false,
            ).withOverride(AppGlassComponent.toolbar, AppGlassOverride.classic),
          );

      final decoded = AppSurfaceSettings.decode(settings.encode());
      expect(decoded, settings);
      expect(decoded.hashCode, settings.hashCode);
      expect(decoded.encode(), settings.encode());
    });

    test('encodes sparsely', () {
      final settings = AppSurfaceSettings.defaults
          .withGlobal(const AppBackground(blur: 3))
          .withArea(
            AppBackgroundArea.editor,
            const AppAreaBackground(mode: AppAreaBackgroundMode.custom),
          )
          .withArea(AppBackgroundArea.calendar, AppAreaBackground.defaults)
          .withGlass(
            AppGlassStyle.defaults.withOverride(
              AppGlassComponent.cards,
              AppGlassOverride.glass,
            ),
          );
      expect(jsonDecode(settings.encode()!), {
        'v': 1,
        'global': {'blur': 3.0},
        'areas': {
          'editor': {'mode': 'custom'},
        },
        'glass': {
          'overrides': {'cards': 'glass'},
        },
      });
      expect(
        jsonDecode(
          AppSurfaceSettings.defaults
              .withGlass(AppGlassStyle.defaults.withMode(AppGlassMode.glass))
              .encode()!,
        ),
        {
          'v': 1,
          'glass': {'mode': 'glass'},
        },
      );
    });

    test('corrupt json falls back to defaults', () {
      for (final raw in ['{', '[]', '"text"', '3', 'null']) {
        expect(AppSurfaceSettings.decode(raw), AppSurfaceSettings.defaults);
      }
    });

    test('wrong types, out-of-range values and unknown names are tolerated '
        'field by field', () {
      final decoded = AppSurfaceSettings.decode(
        jsonEncode({
          'v': 1,
          'global': {
            'kind': 'video',
            'colorLight': 'not a color',
            'colorDark': '#80FF0000',
            'image': 42,
            'alignX': 5,
            'alignY': '0.3',
            'blur': 99,
            'scrimLight': -1,
            'scrimDark': 0.6,
          },
          'areas': {
            'kitchen': {'mode': 'custom'},
            'editor': {
              'mode': 'sometimes',
              'background': {'kind': 'image', 'image': '../escape.png'},
            },
            'preview': 'not a map',
            'calendar': {
              'mode': 'custom',
              'background': {'kind': 'color', 'colorLight': 0x00ABCDEF},
            },
          },
          'glass': {
            'mode': 'frosted',
            'overrides': {
              'toolbar': 'glass',
              'cards': 'maybe',
              'wallpaper': 'glass',
              'dialogs': 'follow',
            },
            'blurSigma': 100,
            'tintOpacity': 0.01,
            'tint': 'rainbow',
            'tintColor': 'zzz',
            'border': 'yes',
          },
        }),
      );

      expect(decoded.global.kind, AppBackgroundKind.none);
      expect(decoded.global.colorLight, isNull);
      // 颜色一律存为不透明色，透明度不进入背景色。
      expect(decoded.global.colorDark, 0xFFFF0000);
      expect(decoded.global.image, isNull);
      expect(decoded.global.alignX, 1);
      expect(decoded.global.alignY, 0);
      expect(decoded.global.blur, 30);
      expect(decoded.global.scrimLight, 0);
      expect(decoded.global.scrimDark, 0.6);

      final editor = decoded.areaOf(AppBackgroundArea.editor);
      expect(editor.mode, AppAreaBackgroundMode.follow);
      expect(editor.custom.kind, AppBackgroundKind.image);
      expect(editor.custom.image, isNull);
      expect(
        decoded.areaOf(AppBackgroundArea.preview),
        AppAreaBackground.defaults,
      );
      expect(
        decoded.areaOf(AppBackgroundArea.calendar).custom.colorLight,
        0xFFABCDEF,
      );

      expect(decoded.glass.mode, AppGlassMode.classic);
      expect(
        decoded.glass.overrideFor(AppGlassComponent.toolbar),
        AppGlassOverride.glass,
      );
      expect(
        decoded.glass.overrideFor(AppGlassComponent.cards),
        AppGlassOverride.follow,
      );
      expect(decoded.glass.overrides.keys, [AppGlassComponent.toolbar]);
      expect(decoded.glass.blurSigma, 40);
      expect(decoded.glass.tintOpacity, 0.2);
      expect(decoded.glass.tint, AppGlassTint.neutral);
      expect(decoded.glass.tintColor, isNull);
      expect(decoded.glass.border, isTrue);
    });

    test('non-map sections fall back to their defaults', () {
      final decoded = AppSurfaceSettings.decode(
        jsonEncode({'v': 1, 'global': 3, 'areas': [], 'glass': 'glass'}),
      );
      expect(decoded, AppSurfaceSettings.defaults);
    });
  });

  group('AppSurfaceSettings.backgroundFor', () {
    final settings = AppSurfaceSettings.defaults
        .withGlobal(image)
        .withArea(
          AppBackgroundArea.editor,
          const AppAreaBackground(
            mode: AppAreaBackgroundMode.custom,
            custom: color,
          ),
        )
        .withArea(
          AppBackgroundArea.settings,
          const AppAreaBackground(
            mode: AppAreaBackgroundMode.off,
            custom: color,
          ),
        );

    test('follow uses the global background', () {
      expect(settings.backgroundFor(AppBackgroundArea.diaries), image);
    });

    test('off draws nothing even with a kept custom background', () {
      final off = settings.backgroundFor(AppBackgroundArea.settings);
      expect(off, AppBackground.defaults);
      expect(off.isVisible, isFalse);
      expect(settings.areaOf(AppBackgroundArea.settings).custom, color);
    });

    test('custom uses the area background', () {
      expect(settings.backgroundFor(AppBackgroundArea.editor), color);
    });

    test('resetting an area to the default removes it', () {
      final reset = settings.withArea(
        AppBackgroundArea.editor,
        AppAreaBackground.defaults,
      );
      expect(reset.areas.containsKey(AppBackgroundArea.editor), isFalse);
      expect(reset.backgroundFor(AppBackgroundArea.editor), image);
    });
  });

  group('AppSurfaceSettings.referencedImages', () {
    test('includes the global image and every area image, active or not', () {
      final settings = AppSurfaceSettings.defaults
          // 当前是纯色，但之前选过的图片仍保留，算作引用。
          .withGlobal(color.copyWith(image: () => 'bg_global.jpg'))
          .withArea(
            AppBackgroundArea.editor,
            const AppAreaBackground(
              mode: AppAreaBackgroundMode.custom,
              custom: AppBackground(
                kind: AppBackgroundKind.image,
                image: 'bg_editor.jpg',
              ),
            ),
          )
          .withArea(
            AppBackgroundArea.preview,
            const AppAreaBackground(
              mode: AppAreaBackgroundMode.follow,
              custom: AppBackground(image: 'bg_preview.jpg'),
            ),
          )
          .withArea(
            AppBackgroundArea.other,
            const AppAreaBackground(mode: AppAreaBackgroundMode.off),
          );
      expect(settings.referencedImages, {
        'bg_global.jpg',
        'bg_editor.jpg',
        'bg_preview.jpg',
      });
      expect(AppSurfaceSettings.defaults.referencedImages, isEmpty);
    });
  });

  group('AppBackground', () {
    test('isVisible needs a color or an image for its kind', () {
      expect(AppBackground.defaults.isVisible, isFalse);
      expect(color.isVisible, isTrue);
      expect(
        const AppBackground(kind: AppBackgroundKind.color).isVisible,
        isFalse,
      );
      expect(image.isVisible, isTrue);
      expect(
        const AppBackground(kind: AppBackgroundKind.image).isVisible,
        isFalse,
      );
      expect(
        const AppBackground(colorLight: 0xFF000000, image: 'bg.jpg').isVisible,
        isFalse,
      );
    });

    test('copyWith distinguishes keeping from clearing nullable fields', () {
      expect(color.copyWith(blur: 4).colorDark, 0xFF445566);
      expect(color.copyWith(colorDark: () => null).colorDark, isNull);
      expect(image.copyWith(image: () => null).image, isNull);
    });
  });

  group('AppGlassStyle', () {
    test('isGlass follows the mode unless a component is overridden', () {
      final classic = AppGlassStyle.defaults
          .withOverride(AppGlassComponent.sheets, AppGlassOverride.glass)
          .withOverride(AppGlassComponent.toolbar, AppGlassOverride.classic);
      expect(classic.isGlass(AppGlassComponent.topBars), isFalse);
      expect(classic.isGlass(AppGlassComponent.sheets), isTrue);
      expect(classic.isGlass(AppGlassComponent.toolbar), isFalse);
      expect(classic.anyGlass, isTrue);

      final glass = classic.withMode(AppGlassMode.glass);
      expect(glass.isGlass(AppGlassComponent.topBars), isTrue);
      expect(glass.isGlass(AppGlassComponent.sheets), isTrue);
      expect(glass.isGlass(AppGlassComponent.toolbar), isFalse);
      expect(
        glass.overrideFor(AppGlassComponent.toolbar),
        AppGlassOverride.classic,
      );

      expect(AppGlassStyle.defaults.anyGlass, isFalse);
    });

    test('setting an override back to follow removes it', () {
      final style = AppGlassStyle.defaults
          .withOverride(AppGlassComponent.cards, AppGlassOverride.glass)
          .withOverride(AppGlassComponent.cards, AppGlassOverride.follow);
      expect(style.overrides, isEmpty);
      expect(style, AppGlassStyle.defaults);
    });

    test('explicit follow entries compare equal to missing ones', () {
      const explicit = AppGlassStyle(
        overrides: {AppGlassComponent.dialogs: AppGlassOverride.follow},
      );
      expect(explicit, AppGlassStyle.defaults);
      expect(explicit.hashCode, AppGlassStyle.defaults.hashCode);
      expect(explicit.toJson(), isEmpty);
    });
  });
}

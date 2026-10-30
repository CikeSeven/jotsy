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

  group('AppSurfaceSettings follow source', () {
    const own = AppBackground(
      kind: AppBackgroundKind.image,
      image: 'bg_own.jpg',
      alignX: 0.3,
      blur: 2,
      scrimLight: 0.1,
      scrimDark: 0.2,
    );
    const other = AppBackground(
      kind: AppBackgroundKind.image,
      image: 'bg_other.jpg',
      alignX: -1,
      alignY: -0.5,
      blur: 20,
      scrimLight: 0.6,
      scrimDark: 0.8,
    );
    const otherSource = AppBackgroundSource.area(AppBackgroundArea.other);

    AppAreaBackground custom(
      AppBackground background, {
      AppBackgroundSource source = AppBackgroundSource.global,
      bool image = false,
      bool params = false,
    }) => AppAreaBackground(
      mode: AppAreaBackgroundMode.custom,
      custom: background,
      source: source,
      followImage: image,
      followParams: params,
    );

    final base = AppSurfaceSettings.defaults
        .withGlobal(image)
        .withArea(AppBackgroundArea.other, custom(other));

    test('round-trips and encodes sparsely', () {
      final settings = base.withArea(
        AppBackgroundArea.editor,
        custom(own, source: otherSource, image: true),
      );
      final decoded = AppSurfaceSettings.decode(settings.encode());
      expect(decoded, settings);
      final areas = jsonDecode(settings.encode()!)['areas'] as Map;
      expect(areas['editor'], {
        'mode': 'custom',
        'background': own.toJson(),
        'source': 'other',
        'followImage': true,
      });
      // 来源为全局、两块都不跟随时不写这些键。
      expect(areas['other'], {'mode': 'custom', 'background': other.toJson()});
    });

    test('unknown or self sources decode as global', () {
      final decoded = AppSurfaceSettings.decode(
        jsonEncode({
          'areas': {
            'editor': {'mode': 'custom', 'source': 'editor'},
            'preview': {'mode': 'custom', 'source': 'nowhere'},
            'other': {'mode': 'custom', 'source': 3},
          },
        }),
      );
      for (final area in [
        AppBackgroundArea.editor,
        AppBackgroundArea.preview,
        AppBackgroundArea.other,
      ]) {
        expect(decoded.areaOf(area).source, AppBackgroundSource.global);
      }
    });

    test('image and parameters follow separately', () {
      final imageOnly = base.withArea(
        AppBackgroundArea.editor,
        custom(own, source: otherSource, image: true),
      );
      expect(
        imageOnly.backgroundFor(AppBackgroundArea.editor),
        own.copyWith(image: () => 'bg_other.jpg'),
      );

      final paramsOnly = base.withArea(
        AppBackgroundArea.editor,
        custom(own, source: otherSource, params: true),
      );
      expect(
        paramsOnly.backgroundFor(AppBackgroundArea.editor),
        other.copyWith(image: () => 'bg_own.jpg'),
      );

      final both = base.withArea(
        AppBackgroundArea.editor,
        custom(own, source: otherSource, image: true, params: true),
      );
      expect(both.backgroundFor(AppBackgroundArea.editor), other);
      // 自己的那一份原样保存，关掉跟随即回来。
      expect(both.areaOf(AppBackgroundArea.editor).custom, own);
    });

    test('a source is followed by what it currently shows', () {
      AppBackground followed(AppAreaBackground source) => base
          .withArea(AppBackgroundArea.other, source)
          .withArea(
            AppBackgroundArea.editor,
            custom(own, source: otherSource, image: true, params: true),
          )
          .backgroundFor(AppBackgroundArea.editor);

      // 来源跟随全局：取全局。
      expect(
        followed(
          const AppAreaBackground(
            mode: AppAreaBackgroundMode.follow,
            custom: other,
          ),
        ),
        image,
      );
      // 来源不显示背景：没有图片，参数为默认。
      final off = followed(
        const AppAreaBackground(mode: AppAreaBackgroundMode.off, custom: other),
      );
      expect(off.image, isNull);
      expect(off.scrimLight, AppBackground.defaults.scrimLight);
      expect(off.isVisible, isFalse);
      // 来源显示纯色：有保存的图片也不跟过来。
      expect(
        followed(custom(other.copyWith(kind: AppBackgroundKind.color))).image,
        isNull,
      );
    });

    test('global source and chains resolve through each step', () {
      final fromGlobal = base.withArea(
        AppBackgroundArea.editor,
        custom(own, image: true, params: true),
      );
      expect(fromGlobal.backgroundFor(AppBackgroundArea.editor), image);

      // 预览跟随编辑，编辑的图片又跟随“其他”：预览拿到的是“其他”的图片。
      final chained = base
          .withArea(
            AppBackgroundArea.editor,
            custom(own, source: otherSource, image: true),
          )
          .withArea(
            AppBackgroundArea.preview,
            custom(
              AppBackground.defaults.copyWith(kind: AppBackgroundKind.image),
              source: const AppBackgroundSource.area(AppBackgroundArea.editor),
              image: true,
            ),
          );
      expect(
        chained.backgroundFor(AppBackgroundArea.preview).image,
        'bg_other.jpg',
      );
    });

    test('a loop from a hand-edited backup falls back to own values', () {
      final looped = AppSurfaceSettings.decode(
        jsonEncode({
          'areas': {
            'editor': {
              'mode': 'custom',
              'background': own.toJson(),
              'source': 'preview',
              'followImage': true,
            },
            'preview': {
              'mode': 'custom',
              'background': other.toJson(),
              'source': 'editor',
              'followImage': true,
            },
          },
        }),
      );
      // 编辑跟随预览；预览再跟随编辑时回到了编辑，就用预览自己的图片。
      expect(
        looped.backgroundFor(AppBackgroundArea.editor).image,
        'bg_other.jpg',
      );
      expect(
        looped.backgroundFor(AppBackgroundArea.preview).image,
        'bg_own.jpg',
      );
    });

    test('canFollow rejects itself and sources that lead back', () {
      final settings = base
          .withArea(
            AppBackgroundArea.editor,
            // 来源已选、跟随还没打开，也算在来源链里。
            custom(own, source: otherSource),
          )
          .withArea(
            AppBackgroundArea.preview,
            const AppAreaBackground(
              source: AppBackgroundSource.area(AppBackgroundArea.editor),
            ),
          );
      expect(
        settings.canFollow(AppBackgroundArea.other, AppBackgroundSource.global),
        isTrue,
      );
      expect(settings.canFollow(AppBackgroundArea.other, otherSource), isFalse);
      // 预览 → 编辑 → 其他：其他不能再跟随预览或编辑。
      for (final area in [
        AppBackgroundArea.editor,
        AppBackgroundArea.preview,
      ]) {
        expect(
          settings.canFollow(
            AppBackgroundArea.other,
            AppBackgroundSource.area(area),
          ),
          isFalse,
        );
      }
      expect(
        settings.canFollow(
          AppBackgroundArea.diaries,
          const AppBackgroundSource.area(AppBackgroundArea.preview),
        ),
        isTrue,
      );
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

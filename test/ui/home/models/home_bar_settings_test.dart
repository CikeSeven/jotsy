import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/style_library/saved_style.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_behavior.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_presets.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_settings.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style_code.dart';

/// 一套与默认不同的样式（默认样式编码为空，测不出读写）。
const _custom = HomeBarStyle(blurSigma: 30);
const _behavior = HomeBarBehavior(hideOnScroll: true);

void main() {
  group('HomeBarSettings', () {
    test('decode returns defaults for null, blank, garbage and non-maps', () {
      for (final raw in <String?>[null, '', '   ', '{oops', '[1,2]', '"s"']) {
        expect(HomeBarSettings.decode(raw), HomeBarSettings.defaults);
      }
    });

    test('encode returns null for defaults and round-trips otherwise', () {
      expect(HomeBarSettings.defaults.encode(), isNull);

      final settings = HomeBarSettings.defaults
          .withCurrent(_custom)
          .addSaved('Mine', _custom, now: DateTime(2026))
          .withBehavior(_behavior);
      final raw = settings.encode()!;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      expect(json['v'], HomeBarSettings.schemaVersion);
      expect(json['v'], 2);
      expect(json['current'], <String, dynamic>{'blurSigma': 30.0});
      expect(json['behavior'], <String, dynamic>{'hideOnScroll': true});
      expect(HomeBarSettings.decode(raw), settings);
    });

    test('a bad part does not reset the others', () {
      final settings = HomeBarSettings.decode(
        jsonEncode(<String, Object?>{
          'v': 2,
          'current': 'broken',
          'saved': <Object?>[
            <String, Object?>{
              'id': 'a',
              'name': 'A',
              'style': <String, Object?>{'blurSigma': 30},
            },
            'junk',
          ],
          'behavior': <String, Object?>{'indicatorFollowsSwipe': true},
        }),
      );
      expect(settings.current, HomeBarStyle.defaults);
      expect(settings.saved.single.style, _custom);
      expect(settings.behavior.indicatorFollowsSwipe, isTrue);
    });

    test('reads settings written before the solid bar was removed', () {
      // v1：当前样式是旧的玻璃样式，“我的样式”里一套玻璃、一套实色。
      final settings = HomeBarSettings.decode(
        jsonEncode(<String, Object?>{
          'v': 1,
          'current': <String, Object?>{
            'material': 'glass',
            'indicator': 'block',
          },
          'saved': <Object?>[
            <String, Object?>{
              'id': 'a',
              'name': 'Glass',
              'style': <String, Object?>{'material': 'glass'},
            },
            <String, Object?>{
              'id': 'b',
              'name': 'Solid',
              'style': <String, Object?>{'labelMode': 'never'},
            },
          ],
          'behavior': <String, Object?>{'hideOnScroll': true},
        }),
      );
      // 玻璃样式按旧默认值补齐，外观不变。
      expect(settings.current.indicator, HomeBarIndicator.block);
      expect(settings.current.iconSize, 20);
      expect(settings.current.sideMargin, 16);
      expect(settings.saved.first.style.indicator, HomeBarIndicator.capsule);
      // 实色样式落到新的默认样式上，只保留写明的字段。
      expect(
        settings.saved.last.style,
        HomeBarStyle.defaults.copyWith(labelMode: HomeBarLabelMode.never),
      );
      expect(settings.behavior, _behavior);

      // 重新编码即新格式，再读回来不变。
      final raw = settings.encode()!;
      expect((jsonDecode(raw) as Map<String, dynamic>)['v'], 2);
      expect(HomeBarSettings.decode(raw), settings);
    });

    test('a version-less payload is read as the old format', () {
      final settings = HomeBarSettings.decode(
        jsonEncode(<String, Object?>{
          'current': <String, Object?>{'material': 'glass'},
        }),
      );
      expect(settings.current.indicator, HomeBarIndicator.capsule);
      expect(settings.current.labelGap, 4);
    });

    test('settings that were all defaults before stay default', () {
      // 从没改过外观的用户：键里只有行为，升级后直接得到新的默认悬浮栏。
      final settings = HomeBarSettings.decode(
        jsonEncode(<String, Object?>{
          'v': 1,
          'current': <String, Object?>{},
          'behavior': <String, Object?>{'hideOnScroll': true},
        }),
      );
      expect(settings.current, HomeBarStyle.defaults);
    });

    test('caps saved styles at twelve', () {
      var settings = HomeBarSettings.defaults;
      for (var i = 0; i < SavedStyles.maxItems + 3; i++) {
        settings = settings.addSaved(
          'S$i',
          _custom,
          now: DateTime(2026, 1, 1, 0, 0, i),
        );
      }
      expect(settings.saved, hasLength(SavedStyles.maxItems));
      expect(settings.canSaveMore, isFalse);
      expect(settings.addSaved('more', _custom), same(settings));
    });

    test('every library operation keeps the behavior', () {
      final base = HomeBarSettings.defaults.withBehavior(_behavior);
      final added = base.addSaved('A', _custom, now: DateTime(2026));
      final item = added.saved.single;
      final steps = <HomeBarSettings>[
        base.withCurrent(_custom),
        added,
        added.renameSaved(item.id, 'B'),
        added.removeSaved(item.id),
        added.removeSaved(item.id).restoreSaved(item, 0),
      ];
      for (final step in steps) {
        expect(step.behavior, _behavior);
      }
      expect(steps.last.saved.single, item);
      expect(added.renameSaved(item.id, 'B').saved.single.name, 'B');
    });
  });

  group('HomeBarPreset', () {
    test('glass is the default style', () {
      expect(HomeBarPreset.values.first, HomeBarPreset.glass);
      expect(HomeBarPreset.glass.style, HomeBarStyle.defaults);
    });

    test('each preset matches itself and presets are distinct', () {
      for (final preset in HomeBarPreset.values) {
        expect(HomeBarPreset.matching(preset.style), preset);
      }
      expect(
        HomeBarPreset.values.map((preset) => preset.style).toSet(),
        hasLength(HomeBarPreset.values.length),
      );
    });

    test('a customized style matches no preset', () {
      expect(
        HomeBarPreset.matching(
          HomeBarPreset.glass.style.copyWith(iconSize: 27),
        ),
        isNull,
      );
    });

    test('every preset keeps the default block indicator spacing', () {
      for (final preset in HomeBarPreset.values) {
        expect(preset.style.indicator, HomeBarIndicator.block);
        expect(preset.style.labelGap, HomeBarStyle.defaults.labelGap);
      }
    });
  });

  group('HomeBarStyleCode', () {
    test('round-trips a style with its name', () {
      final style = HomeBarPreset.compact.style;
      final code = HomeBarStyleCode.encode(style, name: 'Tiny');
      expect(code, startsWith('jotsy-bars:v2:'));

      final result = HomeBarStyleCode.decode('look: $code !');
      expect(result.status, StyleCodeStatus.ok);
      expect(result.style, style);
      expect(result.name, 'Tiny');
    });

    test(
      'still imports v1 codes exported before the solid bar was removed',
      () {
        String v1(Map<String, Object?> style) {
          final data = base64Url
              .encode(utf8.encode(jsonEncode({'v': 1, 'n': 'Old', 's': style})))
              .replaceAll('=', '');
          return 'jotsy-bars:v1:$data';
        }

        final glass = HomeBarStyleCode.decode(
          v1(<String, Object?>{'material': 'glass', 'tintOpacity': 0.5}),
        );
        expect(glass.status, StyleCodeStatus.ok);
        expect(glass.name, 'Old');
        expect(glass.style!.tintOpacity, 0.5);
        expect(glass.style!.indicator, HomeBarIndicator.capsule);
        expect(glass.style!.iconSize, 20);

        final solid = HomeBarStyleCode.decode(v1(<String, Object?>{}));
        expect(solid.status, StyleCodeStatus.ok);
        expect(solid.style, HomeBarStyle.defaults);
      },
    );

    test('rejects codes of another style scheme', () {
      final data = base64Url
          .encode(utf8.encode('{"v":1,"s":{}}'))
          .replaceAll('=', '');
      expect(
        HomeBarStyleCode.decode('jotsy-reader:v1:$data').status,
        StyleCodeStatus.invalid,
      );
      expect(
        HomeBarStyleCode.decode('jotsy-bars:v1:$data').status,
        StyleCodeStatus.ok,
      );
      expect(HomeBarStyleCode.decode('  ').status, StyleCodeStatus.empty);
    });
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/style_library/saved_style.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_behavior.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_presets.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_settings.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style_code.dart';

/// 一套与默认不同的样式（默认样式编码为空，测不出读写）。
const _custom = HomeBarStyle(tintOpacity: 0.35);
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
      expect(json['current'], <String, dynamic>{'tintOpacity': 0.35});
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
              'style': <String, Object?>{'tintOpacity': 0.35},
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

    test('reads settings written by older versions without a migration', () {
      // 旧版本的当前样式与“我的样式”带着已移除的字段（材质、指示器、
      // 尺寸……）：留下的字段照常读取，其余忽略，行为原样保留。
      final settings = HomeBarSettings.decode(
        jsonEncode(<String, Object?>{
          'v': 1,
          'current': <String, Object?>{
            'material': 'glass',
            'indicator': 'block',
            'barHeight': 80,
            'tint': 'theme',
          },
          'saved': <Object?>[
            <String, Object?>{
              'id': 'a',
              'name': 'Glass',
              'style': <String, Object?>{'material': 'glass', 'iconSize': 28},
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
      expect(settings.current, const HomeBarStyle(tint: HomeBarTint.theme));
      expect(settings.saved.first.name, 'Glass');
      expect(settings.saved.first.style, HomeBarStyle.defaults);
      expect(
        settings.saved.last.style,
        HomeBarStyle.defaults.copyWith(labelMode: HomeBarLabelMode.never),
      );
      expect(settings.behavior, _behavior);

      // 重新编码后不再带旧字段，再读回来不变。
      final raw = settings.encode()!;
      expect(raw, isNot(contains('barHeight')));
      expect(HomeBarSettings.decode(raw), settings);
    });

    test('a payload without a version reads the same way', () {
      final settings = HomeBarSettings.decode(
        jsonEncode(<String, Object?>{
          'current': <String, Object?>{'tintOpacity': 0.35},
        }),
      );
      expect(settings.current, _custom);
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
          HomeBarPreset.glass.style.copyWith(tintOpacity: 0.6),
        ),
        isNull,
      );
    });
  });

  group('HomeBarStyleCode', () {
    test('round-trips a style with its name', () {
      final style = HomeBarPreset.compact.style;
      final code = HomeBarStyleCode.encode(style, name: 'Tiny');
      expect(code, startsWith('jotsy-bars:v1:'));

      final result = HomeBarStyleCode.decode('look: $code !');
      expect(result.status, StyleCodeStatus.ok);
      expect(result.style, style);
      expect(result.name, 'Tiny');
    });

    test('imports codes exported by older versions', () {
      // 旧码里带着已移除的字段：照常导入，只取留下的字段。
      final data = base64Url
          .encode(
            utf8.encode(
              jsonEncode(<String, Object?>{
                'v': 1,
                'n': 'Old',
                's': <String, Object?>{
                  'material': 'glass',
                  'tintOpacity': 0.35,
                  'indicator': 'capsule',
                  'iconSize': 20,
                },
              }),
            ),
          )
          .replaceAll('=', '');
      final result = HomeBarStyleCode.decode('jotsy-bars:v1:$data');
      expect(result.status, StyleCodeStatus.ok);
      expect(result.name, 'Old');
      expect(result.style, _custom);
    });

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

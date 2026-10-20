import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/style_library/saved_style.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_behavior.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_presets.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_settings.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style_code.dart';

const _glass = HomeBarStyle(material: HomeBarMaterial.glass);
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
          .withCurrent(_glass)
          .addSaved('Mine', _glass, now: DateTime(2026))
          .withBehavior(_behavior);
      final raw = settings.encode()!;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      expect(json['v'], HomeBarSettings.schemaVersion);
      expect(json['current'], <String, dynamic>{'material': 'glass'});
      expect(json['behavior'], <String, dynamic>{'hideOnScroll': true});
      expect(HomeBarSettings.decode(raw), settings);
    });

    test('a bad part does not reset the others', () {
      final settings = HomeBarSettings.decode(
        jsonEncode(<String, Object?>{
          'v': 1,
          'current': 'broken',
          'saved': <Object?>[
            <String, Object?>{
              'id': 'a',
              'name': 'A',
              'style': <String, Object?>{'material': 'glass'},
            },
            'junk',
          ],
          'behavior': <String, Object?>{'indicatorFollowsSwipe': true},
        }),
      );
      expect(settings.current, HomeBarStyle.defaults);
      expect(settings.saved.single.style, _glass);
      expect(settings.behavior.indicatorFollowsSwipe, isTrue);
    });

    test('caps saved styles at twelve', () {
      var settings = HomeBarSettings.defaults;
      for (var i = 0; i < SavedStyles.maxItems + 3; i++) {
        settings = settings.addSaved(
          'S$i',
          _glass,
          now: DateTime(2026, 1, 1, 0, 0, i),
        );
      }
      expect(settings.saved, hasLength(SavedStyles.maxItems));
      expect(settings.canSaveMore, isFalse);
      expect(settings.addSaved('more', _glass), same(settings));
    });

    test('every library operation keeps the behavior', () {
      final base = HomeBarSettings.defaults.withBehavior(_behavior);
      final added = base.addSaved('A', _glass, now: DateTime(2026));
      final item = added.saved.single;
      final steps = <HomeBarSettings>[
        base.withCurrent(_glass),
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
    test('classic is the default style', () {
      expect(HomeBarPreset.classic.style, HomeBarStyle.defaults);
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

    test('glass-based presets use the glass material', () {
      for (final preset in HomeBarPreset.values.skip(1)) {
        expect(preset.style.material, HomeBarMaterial.glass);
      }
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

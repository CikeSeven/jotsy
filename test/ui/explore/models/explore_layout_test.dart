import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/ui/explore/models/explore_appearance.dart';
import 'package:node_diary/ui/explore/models/explore_layout.dart';
import 'package:node_diary/ui/explore/models/explore_layout_code.dart';
import 'package:node_diary/ui/explore/models/explore_module_config.dart';
import 'package:node_diary/ui/explore/models/explore_module_id.dart';
import 'package:node_diary/ui/explore/models/explore_module_options.dart';
import 'package:node_diary/ui/explore/models/explore_module_spec.dart';
import 'package:node_diary/ui/explore/models/explore_period.dart';
import 'package:node_diary/ui/explore/models/explore_presets.dart';
import 'package:node_diary/ui/explore/models/explore_settings.dart';

void main() {
  group('ExploreLayout', () {
    test(
      'every module is registered once and the defaults hold all of them',
      () {
        expect(
          ExploreModuleSpec.all.map((spec) => spec.id).toSet(),
          ExploreModuleId.values.toSet(),
        );
        expect(ExploreModuleSpec.all, hasLength(ExploreModuleId.values.length));
        expect(
          ExploreLayout.defaults.modules.map((config) => config.id),
          ExploreModuleSpec.all.map((spec) => spec.id),
        );
        for (final spec in ExploreModuleSpec.all) {
          final keys = spec.options.map((option) => option.key).toList();
          expect(keys.toSet(), hasLength(keys.length), reason: '${spec.id}');
        }
      },
    );

    test('round trips through json and keeps the default equal', () {
      final layout = ExploreLayout.defaults
          .withModule(
            ExploreLayout.defaults
                .module(ExploreModuleId.heatmap)
                .copyWith(visible: false, span: ExploreModuleSpan.half)
                .withOption(ExploreOptions.heatmapBasis, 'words'),
          )
          .moveModule(5, 0)
          .copyWith(
            showPeriodBar: false,
            appearance: const ExploreAppearance(
              density: ExploreDensity.compact,
              radius: 16,
            ),
          );
      final decoded = ExploreLayout.fromJson(
        jsonDecode(jsonEncode(layout.toJson())),
      );
      expect(decoded, layout);
      expect(decoded.isDefault, isFalse);
      expect(
        ExploreLayout.fromJson(
          jsonDecode(jsonEncode(ExploreLayout.defaults.toJson())),
        ),
        ExploreLayout.defaults,
      );
    });

    test('keeps unknown modules in place and appends missing known ones', () {
      final layout = ExploreLayout.fromJson(<String, dynamic>{
        'm': <Object>[
          <String, Object>{'id': 'tags', 'on': false},
          <String, Object>{'id': 'futureCard', 'on': true, 'x': 1},
          <String, Object>{'id': 'tags', 'on': true},
          'garbage',
          <String, Object>{'id': 'greeting'},
        ],
      });
      expect(layout.entries[0], isA<ExploreModuleConfig>());
      expect((layout.entries[0] as ExploreModuleConfig).visible, isFalse);
      expect(layout.entries[1], isA<ExploreUnknownModule>());
      expect(layout.entries[2], isA<ExploreModuleConfig>());
      expect(
        layout.modules.map((config) => config.id),
        hasLength(ExploreModuleId.values.length),
      );
      // 移动已知卡片时，认不出的卡片停在原位。
      final moved = layout.moveModule(0, 1);
      expect(moved.entries[1], isA<ExploreUnknownModule>());
      expect(
        (moved.entries[0] as ExploreModuleConfig).id,
        ExploreModuleId.greeting,
      );
      final encoded = jsonEncode(moved.toJson());
      expect(encoded, contains('"futureCard"'));
      expect(encoded, contains('"x":1'));
    });

    test('bad option values fall back alone and unknown keys survive', () {
      final layout = ExploreLayout.fromJson(<String, dynamic>{
        'm': <Object>[
          <String, Object>{
            'id': 'heatmap',
            'span': 'bogus',
            'o': <String, Object>{
              'basis': 'nonsense',
              'span': 'weeks52',
              'legend': 'yes',
              'futureKey': <int>[1, 2],
            },
          },
          <String, Object>{
            'id': 'overview',
            'o': <String, Object>{
              'metrics': <Object>['words', 'words', 'bogus', 3, 'entries'],
              'columns': 4,
            },
          },
        ],
      });
      final heatmap = layout.module(ExploreModuleId.heatmap);
      expect(heatmap.span, ExploreModuleSpan.auto);
      expect(
        heatmap.choice(ExploreOptions.heatmapBasis),
        ExploreHeatBasis.entries,
      );
      expect(
        heatmap.choice(ExploreOptions.heatmapSpan),
        ExploreHeatmapSpan.weeks52,
      );
      expect(heatmap.toggle(ExploreOptions.heatmapLegend), isTrue);
      expect(heatmap.options['futureKey'], <int>[1, 2]);
      final overview = layout.module(ExploreModuleId.overview);
      expect(overview.multi(ExploreOptions.overviewMetrics), <ExploreMetric>[
        ExploreMetric.words,
        ExploreMetric.entries,
      ]);
      expect(overview.count(ExploreOptions.overviewColumns), 0);
    });

    test('options equal to the default are not stored', () {
      final config = ExploreLayout.defaults
          .module(ExploreModuleId.tags)
          .withOption(ExploreOptions.tagsCount, 10);
      expect(config.options, <String, Object>{'count': 10});
      final back = config.withOption(ExploreOptions.tagsCount, 20);
      expect(back.options, isEmpty);
      expect(back.isInitial, isTrue);
      expect(config.withOption(ExploreOptions.tagsCount, 7), config);
    });

    test('feature-bound modules follow the feature switches', () {
      const off = AppFeatures(
        notebooks: false,
        anniversaries: true,
        timeCapsules: false,
      );
      expect(
        ExploreModuleSpec.of(ExploreModuleId.notebooks).isAvailable(off),
        isFalse,
      );
      expect(
        ExploreModuleSpec.of(ExploreModuleId.capsules).isAvailable(off),
        isFalse,
      );
      expect(
        ExploreModuleSpec.of(ExploreModuleId.anniversaries).isAvailable(off),
        isTrue,
      );
      expect(
        ExploreModuleSpec.of(
          ExploreModuleId.anniversaries,
        ).isAvailable(off.copyWith(calendar: false)),
        isFalse,
      );
    });
  });

  group('ExplorePreset', () {
    test('presets are valid, distinct and keep the appearance', () {
      const look = ExploreAppearance(radius: 12);
      final current = ExploreLayout.defaults.copyWith(appearance: look);
      final seen = <String>{};
      for (final preset in ExplorePreset.values) {
        final applied = preset.applyTo(current);
        expect(applied.appearance, look);
        expect(
          applied.modules.map((config) => config.id).toSet(),
          ExploreModuleId.values.toSet(),
        );
        expect(ExplorePreset.matching(applied), preset);
        expect(seen.add(jsonEncode(applied.toJson())), isTrue);
      }
      expect(
        ExplorePreset.matching(ExploreLayout.defaults),
        ExplorePreset.balanced,
      );
    });
  });

  group('ExploreSettings', () {
    test('defaults encode to null and saved layouts round trip', () async {
      expect(ExploreSettings.defaults.encode(), isNull);
      final settings = ExploreSettings.defaults
          .addSaved(
            'Mine',
            ExplorePreset.dataLover.applyTo(ExploreLayout.defaults),
          )
          .withBehavior(const ExploreBehavior(period: ExplorePeriod.week));
      final decoded = ExploreSettings.decode(settings.encode());
      expect(decoded, settings);
      expect(decoded.saved.single.name, 'Mine');
      expect(ExploreSettings.decode('{oops'), ExploreSettings.defaults);
      expect(ExploreSettings.decode('[]'), ExploreSettings.defaults);
    });

    test('layout codes round trip and reject other schemes', () {
      final layout = ExplorePreset.memories.applyTo(ExploreLayout.defaults);
      final code = ExploreLayoutCode.format.encode(layout, name: 'Memories');
      expect(code, startsWith('jotsy-explore:v1:'));
      final result = ExploreLayoutCode.format.decode('see $code !');
      expect(result.status, StyleCodeStatus.ok);
      expect(result.style, layout);
      expect(result.name, 'Memories');
      expect(
        ExploreLayoutCode.format.decode('jotsy-bars:v1:e30').status,
        StyleCodeStatus.invalid,
      );
    });
  });

  group('explorePeriodRange', () {
    final now = DateTime(2026, 10, 28, 15); // 周三

    test('weeks follow the first weekday', () {
      expect(
        explorePeriodRange(
          ExplorePeriod.week,
          now,
          firstWeekday: DateTime.monday,
        ),
        ExploreDateRange(DateTime(2026, 10, 26), DateTime(2026, 11, 2)),
      );
      expect(
        explorePeriodRange(
          ExplorePeriod.week,
          now,
          firstWeekday: DateTime.sunday,
        ),
        ExploreDateRange(DateTime(2026, 10, 25), DateTime(2026, 11, 1)),
      );
    });

    test('months, years and previous ranges', () {
      final month = explorePeriodRange(
        ExplorePeriod.month,
        now,
        firstWeekday: DateTime.monday,
      )!;
      expect(month, ExploreDateRange(DateTime(2026, 10), DateTime(2026, 11)));
      expect(
        explorePreviousRange(ExplorePeriod.month, month),
        ExploreDateRange(DateTime(2026, 9), DateTime(2026, 10)),
      );
      final year = explorePeriodRange(
        ExplorePeriod.year,
        now,
        firstWeekday: DateTime.monday,
      )!;
      expect(year, ExploreDateRange(DateTime(2026), DateTime(2027)));
      expect(
        explorePreviousRange(ExplorePeriod.year, year).start,
        DateTime(2025),
      );
      expect(
        explorePeriodRange(ExplorePeriod.all, now, firstWeekday: 1),
        isNull,
      );
      expect(month.contains(DateTime(2026, 10, 31, 23, 59)), isTrue);
      expect(month.contains(DateTime(2026, 11)), isFalse);
    });
  });
}

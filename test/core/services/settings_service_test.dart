import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('SettingsService mood options codec', () {
    test('normalizes to exactly ten mood slots', () {
      final options = SettingsService.normalizeMoodOptions(<String>[
        ' 😡 ',
        '',
        '😶',
      ]);

      expect(options.length, SettingsService.moodOptionCount);
      expect(options[0], '😡');
      expect(options[1], SettingsService.defaultMoodOptions[1]);
      expect(options[2], '😶');
      expect(options.last, SettingsService.defaultMoodOptions.last);
    });

    test('round-trips custom mood options and falls back on invalid json', () {
      final custom = <String>[
        '😡',
        '😣',
        '🙁',
        '😕',
        '😐',
        '🙂',
        '😌',
        '😁',
        '🥳',
        '✨',
      ];
      final encoded = SettingsService.encodeMoodOptions(custom);

      expect(SettingsService.decodeMoodOptions(encoded), custom);
      expect(
        SettingsService.decodeMoodOptions('not json'),
        SettingsService.defaultMoodOptions,
      );
    });

    test('maps both default and custom mood emojis to weights', () {
      final custom = <String>[
        '😡',
        '😣',
        '🙁',
        '😕',
        '😐',
        '🙂',
        '😌',
        '😁',
        '🥳',
        '✨',
      ];

      expect(SettingsService.moodWeight('😡', custom), 1);
      expect(SettingsService.moodWeight('✨', custom), 10);
      expect(SettingsService.moodWeight('😭', custom), 1);
      expect(SettingsService.moodForWeight(10, custom), '✨');
      expect(SettingsService.moodScore('✨', custom), 5);
    });
  });

  group('SettingsService tag filter memory', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('create leaves tag filter memory disabled', () async {
      final settings = await SettingsService.create();

      expect(settings.isTagFilterMemoryEnabled, isFalse);
    });

    test('persists remembered tag ids after memory is enabled', () async {
      final settings = await SettingsService.create();

      await settings.setTagFilterMemoryEnabled(true);
      await settings.setRememberedTagFilterIdsRaw(' 3,1,2 ');

      expect(settings.isTagFilterMemoryEnabled, isTrue);
      expect(settings.rememberedTagFilterIdsRaw, '3,1,2');

      final restored = await SettingsService.create();
      expect(restored.isTagFilterMemoryEnabled, isTrue);
      expect(restored.rememberedTagFilterIdsRaw, '3,1,2');
    });

    test('disabling tag filter memory clears remembered tag ids', () async {
      final settings = await SettingsService.create();

      await settings.setTagFilterMemoryEnabled(true);
      await settings.setRememberedTagFilterIdsRaw('4,8');
      await settings.setTagFilterMemoryEnabled(false);

      expect(settings.isTagFilterMemoryEnabled, isFalse);
      expect(settings.rememberedTagFilterIdsRaw, isNull);

      final restored = await SettingsService.create();
      expect(restored.isTagFilterMemoryEnabled, isFalse);
      expect(restored.rememberedTagFilterIdsRaw, isNull);
    });
  });
}

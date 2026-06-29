import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/settings_service.dart';

void main() {
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
}

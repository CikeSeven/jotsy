import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/backup_settings.dart';
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

  group('SettingsService diary card tag limit', () {
    const key = 'app.settings.diary_card_tag_limit';

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('defaults a missing diary card tag limit to two', () async {
      final settings = await SettingsService.create();
      final prefs = await SharedPreferences.getInstance();

      expect(settings.diaryCardTagLimit, 2);
      expect(prefs.get(key), 2);
    });

    test('restores a valid stored diary card tag limit unchanged', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{key: 7});

      final settings = await SettingsService.create();
      final prefs = await SharedPreferences.getInstance();

      expect(settings.diaryCardTagLimit, 7);
      expect(prefs.get(key), 7);
    });

    test(
      'setting zero notifies and persists the diary card tag limit',
      () async {
        final settings = await SettingsService.create();
        final notifiedValues = <int>[];
        settings.diaryCardTagLimitNotifier.addListener(() {
          notifiedValues.add(settings.diaryCardTagLimitNotifier.value);
        });

        await settings.setDiaryCardTagLimit(0);

        final prefs = await SharedPreferences.getInstance();
        expect(settings.diaryCardTagLimit, 0);
        expect(notifiedValues, <int>[0]);
        expect(prefs.get(key), 0);
      },
    );

    test(
      'setting above twenty clamps, notifies, and persists twenty',
      () async {
        final settings = await SettingsService.create();
        final notifiedValues = <int>[];
        settings.diaryCardTagLimitNotifier.addListener(() {
          notifiedValues.add(settings.diaryCardTagLimitNotifier.value);
        });

        await settings.setDiaryCardTagLimit(99);

        final prefs = await SharedPreferences.getInstance();
        expect(settings.diaryCardTagLimit, 20);
        expect(notifiedValues, <int>[20]);
        expect(prefs.get(key), 20);
      },
    );

    test('repairs a stored diary card tag limit below zero', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{key: -4});

      final settings = await SettingsService.create();
      final prefs = await SharedPreferences.getInstance();

      expect(settings.diaryCardTagLimit, 0);
      expect(prefs.get(key), 0);
    });

    test('repairs a stored diary card tag limit above twenty', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{key: 40});

      final settings = await SettingsService.create();
      final prefs = await SharedPreferences.getInstance();

      expect(settings.diaryCardTagLimit, 20);
      expect(prefs.get(key), 20);
    });

    test(
      'repairs a wrong-type diary card tag limit with the default',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          key: 'invalid',
        });

        final settings = await SettingsService.create();
        final prefs = await SharedPreferences.getInstance();

        expect(settings.diaryCardTagLimit, 2);
        expect(prefs.get(key), 2);
      },
    );
  });

  group('SettingsService calendar display options', () {
    const key = 'app.settings.calendar_display_options';

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('persists the raw json and clears it with null', () async {
      final settings = await SettingsService.create();
      expect(settings.calendarDisplayOptionsRaw, isNull);

      await settings.setCalendarDisplayOptionsRaw('{"cellStyle":"heat"}');
      expect(
        (await SettingsService.create()).calendarDisplayOptionsRaw,
        '{"cellStyle":"heat"}',
      );

      await settings.setCalendarDisplayOptionsRaw(null);
      final prefs = await SharedPreferences.getInstance();
      expect(settings.calendarDisplayOptionsRaw, isNull);
      expect(prefs.containsKey(key), isFalse);
    });

    test(
      'backups carry the options and older backups keep local ones',
      () async {
        final settings = await SettingsService.create();
        await settings.setCalendarDisplayOptionsRaw('{"cellStyle":"photo"}');

        final captured = BackupSettings.capture(settings);
        expect(captured['calendarDisplayOptionsRaw'], '{"cellStyle":"photo"}');

        await BackupSettings.restore(settings, <String, dynamic>{
          'themeMode': 'dark',
        });
        expect(settings.calendarDisplayOptionsRaw, '{"cellStyle":"photo"}');

        await BackupSettings.restore(settings, <String, dynamic>{
          'calendarDisplayOptionsRaw': null,
        });
        expect(settings.calendarDisplayOptionsRaw, isNull);
      },
    );
  });

  group('SettingsService diary card style', () {
    const key = 'app.settings.diary_card_style';

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('persists the raw json and clears it with null or blank', () async {
      final settings = await SettingsService.create();
      expect(settings.diaryCardStyleRaw, isNull);

      await settings.setDiaryCardStyleRaw('  {"v":1,"current":{}}  ');
      expect(settings.diaryCardStyleRaw, '{"v":1,"current":{}}');
      expect(
        (await SettingsService.create()).diaryCardStyleRaw,
        '{"v":1,"current":{}}',
      );

      await settings.setDiaryCardStyleRaw('   ');
      final prefs = await SharedPreferences.getInstance();
      expect(settings.diaryCardStyleRaw, isNull);
      expect(prefs.containsKey(key), isFalse);

      await settings.setDiaryCardStyleRaw('{"v":1}');
      await settings.setDiaryCardStyleRaw(null);
      expect(prefs.containsKey(key), isFalse);
    });

    test('tolerates a stored value of the wrong type', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{key: 42});
      final settings = await SettingsService.create();
      expect(settings.diaryCardStyleRaw, isNull);
    });

    test(
      'backups carry the style and older backups keep the local one',
      () async {
        final settings = await SettingsService.create();
        await settings.setDiaryCardStyleRaw('{"v":1,"current":{"a":1}}');

        final captured = BackupSettings.capture(settings);
        expect(captured['diaryCardStyleRaw'], '{"v":1,"current":{"a":1}}');

        await BackupSettings.restore(settings, <String, dynamic>{
          'themeMode': 'dark',
        });
        expect(settings.diaryCardStyleRaw, '{"v":1,"current":{"a":1}}');

        // 手工编辑过的备份把样式写成了对象：按 JSON 重新编码后保存。
        await BackupSettings.restore(settings, <String, dynamic>{
          'diaryCardStyleRaw': <String, dynamic>{'v': 1},
        });
        expect(settings.diaryCardStyleRaw, '{"v":1}');

        await BackupSettings.restore(settings, <String, dynamic>{
          'diaryCardStyleRaw': null,
        });
        expect(settings.diaryCardStyleRaw, isNull);
      },
    );
  });
}

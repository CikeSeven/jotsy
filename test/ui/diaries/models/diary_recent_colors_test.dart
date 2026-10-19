import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/diaries/models/diary_recent_colors.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';
import 'package:node_diary/ui/diaries/providers/diary_recent_colors_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 最近用过的自定义颜色：记录顺序、去重、上限、跳过预设，JSON 逐项容错，
/// 以及 provider 的写盘与跟随设置变化。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const a = Color(0xFF112233);
  const b = Color(0xFF445566);

  group('DiaryRecentColors.record', () {
    test('puts the newest first and moves a repeat to the front', () {
      final recent = DiaryRecentColors.empty
          .record(DiaryColorTarget.text, a)
          .record(DiaryColorTarget.text, b)
          .record(DiaryColorTarget.text, a);
      expect(recent.text, <Color>[a, b]);
      expect(recent.background, isEmpty);
    });

    test('keeps the two targets apart', () {
      final recent = DiaryRecentColors.empty
          .record(DiaryColorTarget.text, a)
          .record(DiaryColorTarget.background, const Color(0x4D445566));
      expect(recent.forTarget(DiaryColorTarget.text), <Color>[a]);
      expect(recent.forTarget(DiaryColorTarget.background), <Color>[
        const Color(0x4D445566),
      ]);
    });

    test('caps each list and drops the oldest', () {
      var recent = DiaryRecentColors.empty;
      for (var i = 0; i < DiaryRecentColors.maxCount + 3; i++) {
        recent = recent.record(DiaryColorTarget.text, Color(0xFF000100 + i));
      }
      expect(recent.text, hasLength(DiaryRecentColors.maxCount));
      expect(recent.text.first, const Color(0xFF000100 + 14));
      expect(recent.text.last, const Color(0xFF000100 + 3));
    });

    test('ignores presets and a repeat of the newest color', () {
      final recent = DiaryRecentColors.empty.record(DiaryColorTarget.text, a);
      final preset = DiaryColorPreset.red.colorFor(DiaryColorTarget.text);
      expect(
        identical(recent.record(DiaryColorTarget.text, preset), recent),
        isTrue,
      );
      expect(
        identical(recent.record(DiaryColorTarget.text, a), recent),
        isTrue,
      );
    });
  });

  group('DiaryRecentColors JSON', () {
    test('round-trips as uppercase #AARRGGBB', () {
      final recent = DiaryRecentColors.empty
          .record(DiaryColorTarget.text, a)
          .record(DiaryColorTarget.background, const Color(0x4DABCDEF));
      final raw = recent.encode();
      expect(raw, '{"text":["#FF112233"],"background":["#4DABCDEF"]}');
      expect(DiaryRecentColors.decode(raw), recent);
    });

    test('an empty record encodes to null', () {
      expect(DiaryRecentColors.empty.encode(), isNull);
    });

    test('skips unreadable, repeated and surplus entries', () {
      final many = List<String>.generate(
        20,
        (int i) => '"#FF0001${i.toRadixString(16).padLeft(2, '0')}"',
      ).join(',');
      final recent = DiaryRecentColors.decode(
        '{"text":["#ff112233",7,"red","#FF112233","#445566"],'
        '"background":[$many]}',
      );
      expect(recent.text, <Color>[a, b]);
      expect(recent.background, hasLength(DiaryRecentColors.maxCount));
    });

    test('broken or mistyped json means no colors', () {
      for (final raw in <String?>[null, '', 'not json', '[1]', '{"text":3}']) {
        expect(
          DiaryRecentColors.decode(raw),
          DiaryRecentColors.empty,
          reason: raw,
        );
      }
    });
  });

  group('diaryRecentColorsProvider', () {
    test('records into settings and follows restores', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final settings = await SettingsService.create();
      final container = ProviderContainer(
        overrides: [
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
      );
      addTearDown(container.dispose);
      await container.read(settingsServiceProvider.future);
      final sub = container.listen(diaryRecentColorsProvider, (_, _) {});
      addTearDown(sub.close);

      container
          .read(diaryRecentColorsProvider.notifier)
          .record(DiaryColorTarget.text, a);
      expect(container.read(diaryRecentColorsProvider).text, <Color>[a]);
      await pumpEventQueue();
      expect(
        settings.diaryRecentColorsRaw,
        '{"text":["#FF112233"],"background":[]}',
      );

      // 备份恢复改写设置后，provider 跟着变。
      await settings.setDiaryRecentColorsRaw('{"text":["#FF445566"]}');
      expect(container.read(diaryRecentColorsProvider).text, <Color>[b]);
    });
  });
}

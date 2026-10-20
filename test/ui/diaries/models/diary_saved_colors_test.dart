import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/diaries/models/diary_saved_colors.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';
import 'package:node_diary/ui/diaries/providers/diary_saved_colors_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 我的颜色：保存顺序与位置稳定、同一次调色原地替换、移除、上限、跳过预设，
/// JSON 逐项容错（沿用最近颜色的键与格式），以及 provider 的写盘与跟随设置
/// 变化。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const a = Color(0xFF112233);
  const b = Color(0xFF445566);
  const c = Color(0xFF778899);
  const text = DiaryColorTarget.text;

  group('DiarySavedColors.save', () {
    test('puts a new color first and leaves a saved one where it is', () {
      final saved = DiarySavedColors.empty
          .save(text, a)
          .save(text, b)
          .save(text, a);
      expect(saved.text, <Color>[b, a]);
      expect(saved.background, isEmpty);
    });

    test('keeps the two targets apart', () {
      final saved = DiarySavedColors.empty
          .save(text, a)
          .save(DiaryColorTarget.background, const Color(0x4D445566));
      expect(saved.forTarget(text), <Color>[a]);
      expect(saved.forTarget(DiaryColorTarget.background), <Color>[
        const Color(0x4D445566),
      ]);
      expect(saved.contains(text, a), isTrue);
      expect(saved.contains(DiaryColorTarget.background, a), isFalse);
    });

    test('replacing swaps the color in place', () {
      final saved = DiarySavedColors.empty
          .save(text, a)
          .save(text, b)
          .save(text, c, replacing: a);
      expect(saved.text, <Color>[b, c]);
    });

    test('replacing with a saved color or a preset only drops the old one', () {
      final saved = DiarySavedColors.empty.save(text, a).save(text, b);
      expect(saved.save(text, a, replacing: b).text, <Color>[a]);
      final preset = DiaryColorPreset.red.colorFor(text);
      expect(saved.save(text, preset, replacing: b).text, <Color>[a]);
    });

    test('a replaced color that is gone is just a new color', () {
      final saved = DiarySavedColors.empty.save(text, a);
      expect(saved.save(text, b, replacing: c).text, <Color>[b, a]);
    });

    test('caps each list and drops the oldest', () {
      var saved = DiarySavedColors.empty;
      for (var i = 0; i < DiarySavedColors.maxCount + 3; i++) {
        saved = saved.save(text, Color(0xFF000100 + i));
      }
      expect(saved.text, hasLength(DiarySavedColors.maxCount));
      expect(
        saved.text.first,
        Color(0xFF000100 + DiarySavedColors.maxCount + 2),
      );
      expect(saved.text.last, const Color(0xFF000100 + 3));
    });

    test('ignores presets and colors already saved', () {
      final saved = DiarySavedColors.empty.save(text, a);
      final preset = DiaryColorPreset.red.colorFor(text);
      expect(identical(saved.save(text, preset), saved), isTrue);
      expect(identical(saved.save(text, a), saved), isTrue);
      expect(identical(saved.save(text, a, replacing: a), saved), isTrue);
    });
  });

  group('DiarySavedColors.remove', () {
    test('removes only that color of that target', () {
      final saved = DiarySavedColors.empty
          .save(text, a)
          .save(text, b)
          .save(DiaryColorTarget.background, a);
      final next = saved.remove(text, a);
      expect(next.text, <Color>[b]);
      expect(next.background, <Color>[a]);
      expect(identical(next.remove(text, c), next), isTrue);
    });
  });

  group('DiarySavedColors JSON', () {
    test('round-trips as uppercase #AARRGGBB', () {
      final saved = DiarySavedColors.empty
          .save(text, a)
          .save(DiaryColorTarget.background, const Color(0x4DABCDEF));
      final raw = saved.encode();
      expect(raw, '{"text":["#FF112233"],"background":["#4DABCDEF"]}');
      expect(DiarySavedColors.decode(raw), saved);
    });

    test('nothing saved encodes to null', () {
      expect(DiarySavedColors.empty.encode(), isNull);
      expect(
        DiarySavedColors.empty.save(text, a).remove(text, a).encode(),
        isNull,
      );
    });

    test('skips unreadable, repeated and surplus entries', () {
      final many = List<String>.generate(
        30,
        (int i) => '"#FF0001${i.toRadixString(16).padLeft(2, '0')}"',
      ).join(',');
      final saved = DiarySavedColors.decode(
        '{"text":["#ff112233",7,"red","#FF112233","#445566"],'
        '"background":[$many]}',
      );
      expect(saved.text, <Color>[a, b]);
      expect(saved.background, hasLength(DiarySavedColors.maxCount));
    });

    test('broken or mistyped json means no colors', () {
      for (final raw in <String?>[null, '', 'not json', '[1]', '{"text":3}']) {
        expect(
          DiarySavedColors.decode(raw),
          DiarySavedColors.empty,
          reason: raw,
        );
      }
    });
  });

  group('diarySavedColorsProvider', () {
    test('writes edits into settings and follows restores', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        // 早先的最近颜色原样成为我的颜色。
        'app.settings.diary_recent_colors': '{"text":["#FF445566"]}',
      });
      final settings = await SettingsService.create();
      final container = ProviderContainer(
        overrides: [
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
      );
      addTearDown(container.dispose);
      await container.read(settingsServiceProvider.future);
      final sub = container.listen(diarySavedColorsProvider, (_, _) {});
      addTearDown(sub.close);
      expect(container.read(diarySavedColorsProvider).text, <Color>[b]);

      final notifier = container.read(diarySavedColorsProvider.notifier);
      notifier.edit((DiarySavedColors saved) => saved.save(text, a));
      expect(container.read(diarySavedColorsProvider).text, <Color>[a, b]);
      await pumpEventQueue();
      expect(
        settings.diarySavedColorsRaw,
        '{"text":["#FF112233","#FF445566"],"background":[]}',
      );

      // 每次改写都作用在最新的记录上。
      notifier.edit((DiarySavedColors saved) => saved.remove(text, b));
      notifier.edit((DiarySavedColors saved) => saved.save(text, c));
      expect(container.read(diarySavedColorsProvider).text, <Color>[c, a]);

      // 备份恢复改写设置后，provider 跟着变。
      await settings.setDiarySavedColorsRaw('{"text":["#FF445566"]}');
      expect(container.read(diarySavedColorsProvider).text, <Color>[b]);
    });
  });
}

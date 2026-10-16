import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style_code.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style_settings.dart';

const _rounded = DiaryCardStyle(
  surface: DiaryCardSurfaceStyle(cornerRadius: 8),
);

void main() {
  group('DiaryCardStyleSettings', () {
    test('defaults encode to null so the settings key is removed', () {
      expect(DiaryCardStyleSettings.defaults.encode(), isNull);
      expect(
        DiaryCardStyleSettings.decode(null),
        DiaryCardStyleSettings.defaults,
      );
      expect(
        DiaryCardStyleSettings.decode('{oops'),
        DiaryCardStyleSettings.defaults,
      );
      expect(
        DiaryCardStyleSettings.decode('[]'),
        DiaryCardStyleSettings.defaults,
      );
    });

    test('round-trips the current style and saved styles', () {
      final settings = DiaryCardStyleSettings.defaults
          .withCurrent(_rounded)
          .addSaved('我的圆角', _rounded, now: DateTime(2026, 10, 16))
          .addSaved('默认', DiaryCardStyle.defaults, now: DateTime(2026, 10, 16));
      final decoded = DiaryCardStyleSettings.decode(settings.encode());
      expect(decoded, settings);
      expect(decoded.saved.map((item) => item.name), <String>['我的圆角', '默认']);
      // 同一时刻保存的两项 id 也不能重复。
      expect(decoded.saved.map((item) => item.id).toSet(), hasLength(2));
    });

    test('saved styles alone keep the key even with the default style', () {
      final settings = DiaryCardStyleSettings.defaults.addSaved('A', _rounded);
      expect(settings.isDefault, isFalse);
      expect(settings.encode(), isNotNull);
    });

    test('caps saved styles and ignores blank names', () {
      var settings = DiaryCardStyleSettings.defaults;
      for (var i = 0; i < DiaryCardStyleSettings.maxSaved + 3; i++) {
        settings = settings.addSaved('Style $i', _rounded);
      }
      expect(settings.saved, hasLength(DiaryCardStyleSettings.maxSaved));
      expect(settings.canSaveMore, isFalse);
      expect(
        DiaryCardStyleSettings.defaults.addSaved('   ', _rounded).saved,
        isEmpty,
      );
    });

    test('normalizes names by characters without splitting emoji', () {
      expect(DiaryCardStyleSettings.normalizeName('  a \n  b  '), 'a b');
      final long = '👨‍👩‍👧${'字' * 40}';
      final normalized = DiaryCardStyleSettings.normalizeName(long);
      expect(normalized.startsWith('👨‍👩‍👧'), isTrue);
      expect(normalized.runes.length, lessThan(long.runes.length));
    });

    test('skips malformed and duplicate saved entries', () {
      final raw = jsonEncode(<String, Object>{
        'v': 1,
        'current': <String, Object>{
          'surface': <String, Object>{'cornerRadius': 8},
        },
        'saved': <Object>[
          <String, Object>{
            'id': 'a',
            'name': 'One',
            'style': <String, Object>{},
          },
          <String, Object>{
            'id': 'a',
            'name': 'Dup',
            'style': <String, Object>{},
          },
          <String, Object>{
            'id': 'b',
            'name': '   ',
            'style': <String, Object>{},
          },
          <String, Object>{'name': 'No id'},
          'junk',
          <String, Object>{'id': 'c', 'name': 'Bad style', 'style': 'x'},
        ],
      });
      final decoded = DiaryCardStyleSettings.decode(raw);
      expect(decoded.current, _rounded);
      expect(decoded.saved.map((item) => item.id), <String>['a', 'c']);
      expect(decoded.saved.last.style, DiaryCardStyle.defaults);
    });

    test('rename, remove and restore saved styles', () {
      final settings = DiaryCardStyleSettings.defaults
          .addSaved('A', _rounded, now: DateTime(2026))
          .addSaved('B', _rounded, now: DateTime(2027));
      final first = settings.saved.first;
      final renamed = settings.renameSaved(first.id, '  Renamed  ');
      expect(renamed.saved.first.name, 'Renamed');
      expect(renamed.renameSaved(first.id, ' '), renamed);

      final removed = renamed.removeSaved(first.id);
      expect(removed.saved.map((item) => item.name), <String>['B']);
      final restored = removed.restoreSaved(renamed.saved.first, 0);
      expect(restored, renamed);
      // 已存在的条目不会被重复放回。
      expect(restored.restoreSaved(renamed.saved.first, 0), restored);
      expect(restored.savedById(first.id)?.name, 'Renamed');
      expect(restored.savedById('missing'), isNull);
    });
  });

  group('DiaryCardStyleCode', () {
    test('round-trips a style and its name', () {
      final code = DiaryCardStyleCode.encode(_rounded, name: ' 圆角 ');
      expect(code, startsWith('jotsy-card:v1:'));
      expect(code, isNot(contains('=')));
      final result = DiaryCardStyleCode.decode(code);
      expect(result.status, DiaryCardStyleCodeStatus.ok);
      expect(result.style, _rounded);
      expect(result.name, '圆角');
    });

    test('finds a code embedded in surrounding text', () {
      final code = DiaryCardStyleCode.encode(_rounded);
      final result = DiaryCardStyleCode.decode('试试我的样式：\n$code\n好看吗？');
      expect(result.status, DiaryCardStyleCodeStatus.ok);
      expect(result.style, _rounded);
      expect(result.name, isNull);
    });

    test('rejects empty, foreign, corrupt and oversized input', () {
      expect(
        DiaryCardStyleCode.decode('  ').status,
        DiaryCardStyleCodeStatus.empty,
      );
      expect(
        DiaryCardStyleCode.decode('hello').status,
        DiaryCardStyleCodeStatus.invalid,
      );
      expect(
        DiaryCardStyleCode.decode('jotsy-card:v1:!!!').status,
        DiaryCardStyleCodeStatus.invalid,
      );
      expect(
        DiaryCardStyleCode.decode('jotsy-card:v1:aGVsbG8').status,
        DiaryCardStyleCodeStatus.invalid,
      );
      final code = DiaryCardStyleCode.encode(_rounded);
      expect(
        DiaryCardStyleCode.decode(
          code + ' ' * DiaryCardStyleCode.maxLength,
        ).status,
        DiaryCardStyleCodeStatus.invalid,
      );
    });

    test('decodes a newer version tolerantly and flags it', () {
      final payload = base64Url
          .encode(
            utf8.encode(
              jsonEncode(<String, Object>{
                'v': 9,
                's': <String, Object>{
                  'surface': <String, Object>{'cornerRadius': 8, 'glow': 3},
                },
              }),
            ),
          )
          .replaceAll('=', '');
      final result = DiaryCardStyleCode.decode('jotsy-card:v9:$payload');
      expect(result.status, DiaryCardStyleCodeStatus.newerVersion);
      expect(result.style, _rounded);
    });
  });
}

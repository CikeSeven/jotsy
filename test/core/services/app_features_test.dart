import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_features.dart';

void main() {
  group('AppFeatures.decode', () {
    test('falls back to defaults for missing or unreadable values', () {
      for (final raw in <String?>[null, '', '   ', '{not json', '[1,2]', '7']) {
        expect(AppFeatures.decode(raw), AppFeatures.defaults, reason: raw);
      }
    });

    test('reads each field on its own and ignores unknown keys', () {
      final features = AppFeatures.decode(
        jsonEncode(<String, Object?>{
          'calendar': false,
          'explore': 'no',
          'notebooks': false,
          'anniversaries': null,
          'templates': 0,
          'timeCapsules': false,
          'swipeArchive': 'off',
          'comments': true,
          'futureFeature': false,
        }),
      );

      expect(
        features,
        const AppFeatures(
          calendar: false,
          notebooks: false,
          timeCapsules: false,
          comments: true,
        ),
      );
    });
  });

  group('AppFeatures.encode', () {
    test('writes the defaults in full, so a saved choice is never missing', () {
      final raw = AppFeatures.defaults.encode();

      expect(jsonDecode(raw), <String, bool>{
        'calendar': true,
        'explore': true,
        'notebooks': true,
        'anniversaries': false,
        'templates': true,
        'timeCapsules': true,
        'swipeArchive': true,
        'comments': false,
      });
      expect(AppFeatures.decode(raw), AppFeatures.defaults);
    });

    test('round-trips every non-default combination field', () {
      const features = AppFeatures(
        explore: false,
        anniversaries: true,
        templates: false,
        swipeArchive: false,
        comments: true,
      );
      final raw = features.encode();

      expect((jsonDecode(raw) as Map).keys, <String>[
        'calendar',
        'explore',
        'notebooks',
        'anniversaries',
        'templates',
        'timeCapsules',
        'swipeArchive',
        'comments',
      ]);
      expect(AppFeatures.decode(raw), features);
    });
  });

  group('AppFeatures.anniversariesEnabled', () {
    test('is off by default and needs both the calendar and its toggle', () {
      expect(AppFeatures.defaults.anniversaries, isFalse);
      expect(AppFeatures.defaults.anniversariesEnabled, isFalse);
      expect(
        const AppFeatures(anniversaries: true).anniversariesEnabled,
        isTrue,
      );
      expect(
        const AppFeatures(
          calendar: false,
          anniversaries: true,
        ).anniversariesEnabled,
        isFalse,
        reason: 'calendar off hides anniversaries even when kept on',
      );
      expect(
        const AppFeatures(anniversaries: false).anniversariesEnabled,
        isFalse,
      );
      expect(
        const AppFeatures(
          calendar: false,
          anniversaries: false,
        ).anniversariesEnabled,
        isFalse,
      );
    });

    test(
      'restores the stored anniversaries choice when the calendar returns',
      () {
        const off = AppFeatures(calendar: false, anniversaries: false);
        expect(off.copyWith(calendar: true).anniversariesEnabled, isFalse);

        const kept = AppFeatures(calendar: false, anniversaries: true);
        expect(kept.copyWith(calendar: true).anniversariesEnabled, isTrue);
      },
    );
  });

  group('AppFeatures value semantics', () {
    test('copyWith changes only the given fields', () {
      final next = AppFeatures.defaults.copyWith(notebooks: false);

      expect(next, const AppFeatures(notebooks: false));
      expect(next.copyWith(), next);
      expect(next.copyWith(notebooks: true), AppFeatures.defaults);
    });

    test('equal values share a hash code', () {
      const a = AppFeatures(explore: false, timeCapsules: false);
      const b = AppFeatures(timeCapsules: false, explore: false);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == AppFeatures.defaults, isFalse);
    });
  });
}

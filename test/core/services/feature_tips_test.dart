import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/feature_tips.dart';

void main() {
  const tip = FeatureTip.tagFilterPull;

  test('an unset or unreadable value shows every tip from the start', () {
    for (final raw in <String?>[null, '', '  ', 'not json', '[1, 2]', '"x"']) {
      final tips = FeatureTips.decode(raw);
      expect(tips.recordOf(tip), FeatureTipRecord.initial, reason: '$raw');
      expect(tips.shouldShow(tip), isTrue, reason: '$raw');
    }
  });

  test('progress round-trips through the stored JSON', () {
    final tips = FeatureTips.empty.markShown(tip).markShown(tip);
    final decoded = FeatureTips.decode(tips.encode());

    expect(decoded.recordOf(tip), const FeatureTipRecord(shown: 2));
    expect(jsonDecode(decoded.markLearned(tip).encode()), <String, Object?>{
      'tagFilterPull': <String, Object?>{'learned': true, 'shown': 2},
    });
  });

  test('a bad field only resets that field', () {
    final tips = FeatureTips.decode(
      jsonEncode(<String, Object?>{
        'tagFilterPull': <String, Object?>{'learned': 'yes', 'shown': 2},
      }),
    );
    expect(tips.recordOf(tip), const FeatureTipRecord(shown: 2));

    for (final shown in <Object?>[-1, 1.5, '2', null]) {
      final record = FeatureTips.decode(
        jsonEncode(<String, Object?>{
          'tagFilterPull': <String, Object?>{'learned': true, 'shown': shown},
        }),
      ).recordOf(tip);
      expect(record, const FeatureTipRecord(learned: true), reason: '$shown');
    }

    expect(
      FeatureTips.decode('{"tagFilterPull": 3}').recordOf(tip),
      FeatureTipRecord.initial,
    );
  });

  test('tips written by newer versions survive a rewrite', () {
    final raw = jsonEncode(<String, Object?>{
      'futureTip': <String, Object?>{'learned': true, 'shown': 1, 'extra': 7},
    });

    final rewritten = FeatureTips.decode(raw).markShown(tip).encode();

    expect(jsonDecode(rewritten), <String, Object?>{
      'futureTip': <String, Object?>{'learned': true, 'shown': 1, 'extra': 7},
      'tagFilterPull': <String, Object?>{'learned': false, 'shown': 1},
    });
  });

  test('a tip stops after it is learned or reaches its show limit', () {
    var tips = FeatureTips.empty;
    for (var index = 0; index < tip.maxShows - 1; index++) {
      tips = tips.markShown(tip);
      expect(tips.shouldShow(tip), isTrue);
    }
    expect(tips.markShown(tip).shouldShow(tip), isFalse);
    expect(FeatureTips.empty.markLearned(tip).shouldShow(tip), isFalse);
  });

  test('learning twice returns the same value so callers skip the write', () {
    final learned = FeatureTips.empty.markLearned(tip);

    expect(identical(learned.markLearned(tip), learned), isTrue);
    expect(learned.markShown(tip).recordOf(tip).learned, isTrue);
  });
}

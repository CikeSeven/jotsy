import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/utils/precise_time_formatter.dart';

void main() {
  group('PreciseTimeFormatter', () {
    test('同一天仅显示小时分钟', () {
      final now = DateTime(2026, 3, 11, 21, 30, 59);
      final target = DateTime(2026, 3, 11, 12, 22, 10);

      final result = PreciseTimeFormatter.format(target: target, now: now);

      expect(result, '12:22');
    });

    test('同一年不同天显示月日和时间', () {
      final now = DateTime(2026, 3, 11, 21, 30);
      final target = DateTime(2026, 2, 9, 7, 5);

      final result = PreciseTimeFormatter.format(target: target, now: now);

      expect(result, '2月9日 07:05');
    });

    test('跨年显示完整年月日和时间', () {
      final now = DateTime(2026, 3, 11, 21, 30);
      final target = DateTime(2013, 3, 23, 12, 13);

      final result = PreciseTimeFormatter.format(target: target, now: now);

      expect(result, '2013年 3月23日 12:13');
    });
  });
}

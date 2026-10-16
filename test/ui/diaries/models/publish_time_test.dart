import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/publish_time.dart';

void main() {
  final now = DateTime(2026, 10, 16, 14, 25, 30, 123, 456);

  test('no requested time publishes now', () {
    expect(resolvePublishAt(null, now: now), now);
  });

  test('a date-only request keeps the day and takes the current time', () {
    expect(
      resolvePublishAt(DateTime(2026, 10, 10), now: now),
      DateTime(2026, 10, 10, 14, 25, 30, 123, 456),
    );
  });

  test('a past moment is kept as is', () {
    final requested = DateTime(2025, 3, 15, 10, 30, 45);
    expect(resolvePublishAt(requested, now: now), requested);
  });

  test('a future moment or future day falls back to now', () {
    expect(resolvePublishAt(DateTime(2026, 10, 16, 23), now: now), now);
    expect(resolvePublishAt(DateTime(2026, 10, 20), now: now), now);
  });
}

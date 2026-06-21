import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calendar page keeps stale content during refresh states', () async {
    final source =
        await File('lib/ui/calendar/pages/calendar_page.dart').readAsString();

    expect(source, contains('_cachedMarkerBuckets'));
    expect(source, contains('_cachedDayDiaries'));
    expect(source, contains('Keep the last'));
    expect(source, contains('Reuse the last'));
    expect(source, contains('LoadingIndicatorM3E'));
    expect(source, contains('AnimatedSwitcher'));
    expect(source, isNot(contains('CircularProgressIndicator')));
  });
}

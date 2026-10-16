import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calendar page keeps stale content during refresh states', () async {
    // 页面装配拆在 calendar_page.dart 与其 part 文件 calendar_page_sections.dart。
    final source = <String>[
      await File('lib/ui/calendar/pages/calendar_page.dart').readAsString(),
      await File(
        'lib/ui/calendar/pages/calendar_page_sections.dart',
      ).readAsString(),
    ].join('\n');
    final capsuleSource = await File(
      'lib/ui/calendar/widgets/calendar_refresh_capsule.dart',
    ).readAsString();

    expect(source, contains('_cachedDaySummaries'));
    expect(source, contains('_cachedDayDiaries'));
    expect(source, contains('_cachedInlineImages'));
    expect(source, contains('Keep the last'));
    expect(source, contains('Reuse the last'));
    expect(capsuleSource, contains('ExpressiveLoadingIndicator'));
    expect(capsuleSource, contains('DelayedLoadingGate'));
    for (final file in <String>[source, capsuleSource]) {
      expect(file, isNot(contains('CircularProgressIndicator')));
    }
  });

  test('calendar snack bars go through the tracked Home hint helper', () {
    // AGENTS.md §6：SnackBar 统一经 HomeHintVisibilityScope.showTrackedSnackBar，
    // Home 的 FAB 才会随提示条上移。
    final files = Directory('lib/ui/calendar')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File file) => file.path.endsWith('.dart'));
    for (final file in files) {
      expect(
        file.readAsStringSync(),
        isNot(contains('.showSnackBar(')),
        reason: file.path,
      );
    }
  });
}

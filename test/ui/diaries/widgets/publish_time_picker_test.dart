import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/publish_time_picker.dart';

import '../../../support/expressive_test_theme.dart';

/// 发表时间选择器的取值边界：已发布日记的发表时间可能早于选择器下限，
/// 也可能在未来（胶囊提前解封后仍保留原解封时间）。
void main() {
  Future<List<DateTime?>> openPicker(
    WidgetTester tester,
    DateTime current,
  ) async {
    final results = <DateTime?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => results.add(
                await showPublishTimePicker(context, current: current),
              ),
              child: const Text('Pick'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pick'));
    await tester.pumpAndSettle();
    return results;
  }

  Future<void> confirmDateAndTime(WidgetTester tester) async {
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  testWidgets('a diary dated before 2010 opens on its own month', (
    tester,
  ) async {
    final results = await openPicker(tester, DateTime(2008, 5, 20, 8, 15, 30));
    expect(tester.takeException(), isNull);

    // 下限只放宽到原日期当天，之后的日期照常可选。
    await tester.tap(find.text('25'));
    await confirmDateAndTime(tester);
    expect(results, [DateTime(2008, 5, 25, 8, 15)]);
  });

  testWidgets('a future publish time starts from today and keeps its time', (
    tester,
  ) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final results = await openPicker(
      tester,
      DateTime(today.year, today.month, today.day + 3, 21, 40),
    );

    await confirmDateAndTime(tester);
    expect(results, [DateTime(today.year, today.month, today.day, 21, 40)]);
  });
}

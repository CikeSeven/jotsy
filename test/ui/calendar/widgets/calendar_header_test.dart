import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_header.dart';

Widget _host(String title, DateTime month) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Stack(
      children: <Widget>[
        CalendarHeader(
          title: title,
          month: month,
          onJumpToToday: () {},
          onPreviousMonth: () {},
          onNextMonth: () {},
          onPickDate: () {},
        ),
      ],
    ),
  ),
);

/// 标题切换途中，新标题相对旧标题的水平位置（正值在右侧）。
Future<double> _incomingOffset(
  WidgetTester tester, {
  required String from,
  required String to,
  required DateTime fromMonth,
  required DateTime toMonth,
}) async {
  await tester.pumpWidget(_host(from, fromMonth));
  await tester.pumpWidget(_host(to, toMonth));
  await tester.pump(const Duration(milliseconds: 60));
  final incoming = tester.getCenter(find.text(to)).dx;
  final outgoing = tester.getCenter(find.text(from)).dx;
  await tester.pumpAndSettle();
  expect(find.text(from), findsNothing);
  return incoming - outgoing;
}

void main() {
  testWidgets('next month slides in from the right', (tester) async {
    final offset = await _incomingOffset(
      tester,
      from: 'Sep 2026',
      to: 'Oct 2026',
      fromMonth: DateTime(2026, 9),
      toMonth: DateTime(2026, 10),
    );
    expect(offset, greaterThan(0));
  });

  testWidgets('previous month slides in from the left', (tester) async {
    final offset = await _incomingOffset(
      tester,
      from: 'Oct 2026',
      to: 'Sep 2026',
      fromMonth: DateTime(2026, 10),
      toMonth: DateTime(2026, 9),
    );
    expect(offset, lessThan(0));
  });
}

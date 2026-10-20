import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/anniversaries/providers/anniversary_providers.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/calendar/providers/calendar_diary_providers.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_header.dart';

/// 空数据的日历页；视口不高，月视图 + 选中日区域足以向下滚动。
Future<void> _pumpCalendar(WidgetTester tester) async {
  // 页宽取整数（见 calendar_page_month_switch_test 的说明），高度取 600
  // 让内容超出视口。
  tester.view.physicalSize = const Size(401.6, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        calendarMonthMarkersProvider.overrideWith(
          (ref, month) => Stream.value(const <DiaryCalendarMarker>[]),
        ),
        calendarDayDiariesProvider.overrideWith(
          (ref, day) => Stream.value(const <DiaryWithTags>[]),
        ),
        calendarOnThisDayProvider.overrideWith(
          (ref, day) => Stream.value(const <DiaryWithTags>[]),
        ),
        moodOptionsProvider.overrideWith(
          (ref) => Stream.value(const <String>[]),
        ),
        anniversaryListProvider.overrideWith(
          (ref) => Stream.value(const <Anniversary>[]),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CalendarPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('scrolling the calendar down keeps only the title bar', (
    tester,
  ) async {
    await _pumpCalendar(tester);
    final l10n = tester.element(find.byType(CalendarPage)).l10n;
    final monthTitle = find.text(DateFormat.yMMM('zh').format(DateTime.now()));
    final titleBar = find.text(l10n.autoT0183);
    final titleRect = tester.getRect(titleBar);
    expect(
      tester.getSize(find.byType(CalendarHeader)).height,
      CalendarHeader.contentHeight,
    );
    expect(monthTitle.hitTestable(), findsOneWidget);

    // 在页头上往上拖：页头本身也在列表里，拖动它同样滚动内容。
    await tester.drag(titleBar, const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(CalendarHeader)).height,
      CalendarHeader.titleBarHeight,
    );
    expect(tester.getRect(titleBar), titleRect);
    expect(monthTitle.hitTestable(), findsNothing);
    expect(find.byTooltip(l10n.autoT0180).hitTestable(), findsOneWidget);

    // 往回拖到顶部，月份行重新出现。
    await tester.drag(titleBar, const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(CalendarHeader)).height,
      CalendarHeader.contentHeight,
    );
    expect(monthTitle.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_day_empty_state.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_month_grid.dart';

import '../../support/calendar_test_harness.dart';

/// 时间胶囊功能关闭时，日历里写胶囊与胶囊角标的入口隐藏（数据保留）。
const _featuresKey = 'app.settings.app_features';

AppLocalizations _l10n(WidgetTester tester) =>
    tester.element(find.byType(CalendarPage)).l10n;

/// 当前网格中的某个日期数字（月视图里 15 号这类中段日期只出现一次）。
Finder _gridDay(int day) => find.descendant(
  of: find.byType(CalendarMonthGrid),
  matching: find.text('$day'),
);

/// 翻到下个月再长按 15 号：一定是未来日期。
Future<void> _longPressFutureDay(WidgetTester tester) async {
  await tester.tap(find.byTooltip(_l10n(tester).autoT0185));
  await tester.pumpAndSettle();
  await tester.longPress(_gridDay(15));
  await tester.pumpAndSettle();
}

void main() {
  for (final enabled in <bool>[true, false]) {
    final prefs = enabled
        ? const <String, Object>{}
        : const <String, Object>{_featuresKey: '{"timeCapsules":false}'};
    final expected = enabled ? findsOneWidget : findsNothing;

    testWidgets(
      'a future day ${enabled ? 'offers' : 'does not offer'} a time capsule',
      (tester) async {
        await pumpCalendarPage(tester, prefs: prefs);
        final l10n = _l10n(tester);
        await _longPressFutureDay(tester);
        expect(find.text(l10n.calendarDayActionWrite), findsOneWidget);
        expect(find.text(l10n.calendarDayActionRange), findsOneWidget);
        expect(find.text(l10n.calendarDayActionCapsule), expected);
      },
    );

    testWidgets(
      'the display options ${enabled ? 'show' : 'hide'} the capsule badge row',
      (tester) async {
        await pumpCalendarPage(tester, prefs: prefs);
        final l10n = _l10n(tester);
        await tester.tap(find.byTooltip(l10n.calendarDisplayOptionsTooltip));
        await tester.pumpAndSettle();
        expect(find.text(l10n.calendarBadgeCount), findsOneWidget);
        expect(find.text(l10n.calendarBadgeCapsule), expected);
      },
    );

    testWidgets(
      'an empty future day ${enabled ? 'offers' : 'has no'} capsule button',
      (tester) async {
        await pumpCalendarPage(tester, prefs: prefs);
        final l10n = _l10n(tester);
        await tester.tap(find.byTooltip(l10n.autoT0185));
        await tester.pumpAndSettle();
        await tester.tap(_gridDay(15));
        await tester.pumpAndSettle();
        final empty = find.byType(CalendarDayEmptyState);
        expect(
          find.descendant(of: empty, matching: find.text(l10n.autoT0211)),
          findsOneWidget,
        );
        expect(find.text(l10n.calendarFutureCapsuleAction), expected);
        expect(
          find.descendant(of: empty, matching: find.byType(FilledButton)),
          expected,
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_header.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_presets.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_resolved_style.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_chrome_scope.dart';
import 'package:node_diary/ui/widgets/glass/glass_surface.dart';

Widget _host(String title, DateTime month, {bool glass = false}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) {
      final page = Scaffold(
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
      );
      if (!glass) {
        return page;
      }
      // 与首页相同：玻璃预设的 HomeChromeScope 包在页面之上。
      return HomeChromeScope(
        style: HomeBarResolvedStyle.resolve(
          HomeBarPreset.glass.style,
          Theme.of(context).colorScheme,
        ),
        child: page,
      );
    },
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

  testWidgets('the anniversary button fits a 320dp English header', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              CalendarHeader(
                title: 'October 2026',
                month: DateTime(2026, 10),
                onJumpToToday: () {},
                onPreviousMonth: () {},
                onNextMonth: () {},
                onPickDate: () {},
                onOpenDisplayOptions: () {},
                onOpenFilter: () {},
                onOpenAnniversaries: () => opened++,
              ),
            ],
          ),
        ),
      ),
    );
    final l10n = tester.element(find.byType(CalendarHeader)).l10n;
    await tester.tap(find.byTooltip(l10n.anniversaryListTitle));
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a home scope the header stays a plain surface block', (
    tester,
  ) async {
    await tester.pumpWidget(_host('Oct 2026', DateTime(2026, 10)));
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(GlassSurface), findsNothing);
    final box = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(CalendarHeader),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(
      box.color,
      Theme.of(tester.element(find.byType(CalendarHeader))).colorScheme.surface,
    );
  });

  testWidgets('glass top bars blur behind the header at the same layout', (
    tester,
  ) async {
    await tester.pumpWidget(_host('Oct 2026', DateTime(2026, 10)));
    final solidTitle = tester.getRect(find.text('Oct 2026'));
    final solidHeight = tester.getSize(find.byType(CalendarHeader)).height;

    await tester.pumpWidget(_host('Oct 2026', DateTime(2026, 10), glass: true));
    final backdrop = find.descendant(
      of: find.byType(CalendarHeader),
      matching: find.byType(BackdropFilter),
    );
    expect(backdrop, findsOneWidget);
    expect(tester.widget<BackdropFilter>(backdrop).enabled, isTrue);
    expect(tester.getRect(find.text('Oct 2026')), solidTitle);
    expect(tester.getSize(find.byType(CalendarHeader)).height, solidHeight);
  });
}

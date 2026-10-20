import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_header.dart';
import 'package:node_diary/ui/calendar/widgets/calendar_header_sliver.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_presets.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_resolved_style.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_chrome_scope.dart';

const _contentKey = ValueKey<String>('content');

/// 页头 sliver + 一段内容，与日历页的滚动结构相同；[contentHeight] 决定能
/// 滚多远。
Widget _host({
  required ScrollController controller,
  double contentHeight = 2000,
  bool glass = false,
  VoidCallback? onPreviousMonth,
}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) {
      final page = Scaffold(
        body: CustomScrollView(
          controller: controller,
          slivers: <Widget>[
            CalendarHeaderSliver(
              builder: (_, double collapsedExtent) => CalendarHeader(
                title: 'Oct 2026',
                month: DateTime(2026, 10),
                onJumpToToday: () {},
                onPreviousMonth: onPreviousMonth ?? () {},
                onNextMonth: () {},
                onPickDate: () {},
                collapsedExtent: collapsedExtent,
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(key: _contentKey, height: contentHeight),
            ),
          ],
        ),
      );
      if (!glass) {
        return page;
      }
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

double _headerHeight(WidgetTester tester) =>
    tester.getSize(find.byType(CalendarHeader)).height;

void main() {
  testWidgets('scrolling down tucks the month row under the title bar', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var previous = 0;
    await tester.pumpWidget(
      _host(controller: controller, onPreviousMonth: () => previous++),
    );
    final l10n = tester.element(find.byType(CalendarHeader)).l10n;
    final titleBar = find.text(l10n.autoT0183);
    final titleRect = tester.getRect(titleBar);
    expect(_headerHeight(tester), CalendarHeader.contentHeight);
    expect(find.text('Oct 2026').hitTestable(), findsOneWidget);

    // 半途：月份行与内容一起上移同样的距离，标题栏不动。
    controller.jumpTo(20);
    await tester.pump();
    expect(_headerHeight(tester), CalendarHeader.contentHeight - 20);
    expect(
      tester.getTopLeft(find.byKey(_contentKey)).dy,
      CalendarHeader.contentHeight - 20,
    );
    expect(tester.getRect(titleBar), titleRect);

    // 滚过月份行的高度后只剩标题栏，内容从页头下方滑过。
    controller.jumpTo(300);
    await tester.pump();
    expect(_headerHeight(tester), CalendarHeader.titleBarHeight);
    expect(tester.getRect(titleBar), titleRect);
    expect(titleBar.hitTestable(), findsOneWidget);
    expect(find.text('Oct 2026').hitTestable(), findsNothing);
    expect(find.byTooltip(l10n.autoT0184).hitTestable(), findsNothing);

    // 回到顶部，月份行重新展开并可点按。
    controller.jumpTo(0);
    await tester.pump();
    expect(_headerHeight(tester), CalendarHeader.contentHeight);
    await tester.tap(find.byTooltip(l10n.autoT0184));
    expect(previous, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a fully collapsed month row is skipped by screen readers and keyboard focus',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller: controller));
      final l10n = tester.element(find.byType(CalendarHeader)).l10n;
      // 按钮的提示文字在语义树里是 tooltip，不是 label。
      SemanticsFinder button(String tooltip) =>
          find.semantics.byPredicate((node) => node.tooltip == tooltip);

      /// 连按 Tab 走一圈，看焦点是否落进过“上个月”按钮。
      Future<bool> tabReachesPreviousMonth() async {
        final previous = find.byTooltip(l10n.autoT0184);
        var reached = false;
        for (var i = 0; i < 6; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          final focused = FocusManager.instance.primaryFocus?.context;
          if (focused != null &&
              find
                  .descendant(
                    of: previous,
                    matching: find.byElementPredicate((e) => e == focused),
                  )
                  .evaluate()
                  .isNotEmpty) {
            reached = true;
          }
        }
        return reached;
      }

      expect(button(l10n.autoT0184), findsOne);
      expect(await tabReachesPreviousMonth(), isTrue);

      controller.jumpTo(300);
      await tester.pump();
      expect(button(l10n.autoT0184), findsNothing);
      expect(button(l10n.autoT0185), findsNothing);
      expect(button(l10n.autoT0180), findsOne);
      expect(await tabReachesPreviousMonth(), isFalse);
      semantics.dispose();
    },
  );

  testWidgets('the header realigns in the same frame when content shrinks', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller: controller));
    controller.jumpTo(30);
    await tester.pump();
    expect(_headerHeight(tester), CalendarHeader.contentHeight - 30);

    // 内容变得比视口还矮（如切到周视图），滚动位置在布局里被校正回 0：
    // 同一帧里页头展开、内容紧贴在它下面，中间不留空。
    await tester.pumpWidget(_host(controller: controller, contentHeight: 100));
    expect(controller.offset, 0);
    expect(_headerHeight(tester), CalendarHeader.contentHeight);
    expect(
      tester.getTopLeft(find.byKey(_contentKey)).dy,
      CalendarHeader.contentHeight,
    );
  });

  testWidgets('a glass header keeps blurring while collapsed', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller: controller, glass: true));
    controller.jumpTo(300);
    await tester.pump();
    final backdrop = find.descendant(
      of: find.byType(CalendarHeader),
      matching: find.byType(BackdropFilter),
    );
    expect(backdrop, findsOneWidget);
    expect(tester.widget<BackdropFilter>(backdrop).enabled, isTrue);
    expect(_headerHeight(tester), CalendarHeader.titleBarHeight);
  });
}

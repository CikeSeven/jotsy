import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_resolved_style.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_bar.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_indicator.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_rail.dart';

import '../../../../support/expressive_test_theme.dart';

const _items = <BottomNavItem>[
  BottomNavItem(label: 'Diaries', icon: FontAwesomeIcons.book),
  BottomNavItem(label: 'Calendar', icon: FontAwesomeIcons.calendarDays),
  BottomNavItem(label: 'Explore', icon: FontAwesomeIcons.compass),
  BottomNavItem(label: 'Settings', icon: FontAwesomeIcons.gear),
];

HomeBarResolvedStyle _style({
  HomeBarMaterial material = HomeBarMaterial.solid,
  HomeBarLabelMode labelMode = HomeBarLabelMode.always,
  HomeBarIndicator indicator = HomeBarIndicator.capsule,
}) => HomeBarResolvedStyle.resolve(
  HomeBarStyle(material: material, labelMode: labelMode, indicator: indicator),
  expressiveTestTheme(Brightness.light).colorScheme,
);

Future<void> _pump(
  WidgetTester tester, {
  HomeBarResolvedStyle? style,
  int selected = 0,
  ValueChanged<int>? onTap,
  VoidCallback? onCreate,
  Size size = const Size(800, 600),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: Scaffold(
          body: Row(
            children: <Widget>[
              HomeNavRail(
                items: _items,
                selectedIndex: selected,
                onTap: onTap ?? (_) {},
                style: style ?? _style(),
                leading: HomeNavRailCreateButton(
                  label: 'New',
                  onPressed: onCreate ?? () {},
                ),
              ),
              const Expanded(child: SizedBox.expand()),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'the rail is 96 wide, filled with the solid fill and full height',
    (tester) async {
      final style = _style(material: HomeBarMaterial.glass);
      await _pump(tester, style: style);
      final rail = find.byType(HomeNavRail);
      expect(tester.getSize(rail), const Size(96, 600));
      final material = tester.widget<Material>(
        find.descendant(of: rail, matching: find.byType(Material)).first,
      );
      // 玻璃样式在侧边栏上也只用不透明的等效色，从不模糊。
      expect(material.color, style.solidFill);
      expect(
        find.descendant(of: rail, matching: find.byType(BackdropFilter)),
        findsNothing,
      );
    },
  );

  testWidgets('the create button sits 16 below the top and is 56 square', (
    tester,
  ) async {
    var created = 0;
    await _pump(tester, onCreate: () => created++);
    final fab = find.byType(FloatingActionButton);
    expect(tester.getSize(fab), const Size(56, 56));
    expect(tester.getTopLeft(fab), const Offset(20, 16));
    await tester.tap(fab);
    expect(created, 1);
    // 文字只作提示。
    expect(find.byTooltip('New'), findsOneWidget);
  });

  testWidgets('destinations stack below the button and settings is pinned '
      'to the bottom', (tester) async {
    await _pump(tester);
    final fabBottom = tester.getBottomLeft(find.byType(FloatingActionButton));
    final diaries = tester.getRect(find.text('Diaries'));
    final calendar = tester.getRect(find.text('Calendar'));
    final settings = tester.getRect(find.text('Settings'));
    // 指示器（32 高）在 FAB 下方 28 处，文字再往下。
    expect(diaries.top, greaterThan(fabBottom.dy + 28 + 32));
    expect(calendar.top, greaterThan(diaries.bottom));
    expect(settings.bottom, closeTo(600 - 16, 0.01));
  });

  testWidgets('the capsule indicator is 56 by 32 around the icon', (
    tester,
  ) async {
    await _pump(tester, selected: 1);
    final indicators = find.byType(HomeNavIndicator);
    expect(indicators, findsNWidgets(4));
    expect(tester.getSize(indicators.at(1)), const Size(56, 32));
    final icon = tester.getCenter(find.byType(FaIcon).at(2));
    expect(tester.getCenter(indicators.at(1)), icon);
  });

  testWidgets('tapping a destination reports its index', (tester) async {
    final tapped = <int>[];
    await _pump(tester, onTap: tapped.add);
    await tester.tap(find.text('Calendar'));
    await tester.tap(find.text('Settings'));
    await tester.tap(find.text('Diaries'));
    expect(tapped, <int>[1, 3, 0]);
  });

  testWidgets('semantics marks only the selected destination', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, selected: 2);
    expect(
      tester.getSemantics(find.text('Explore')),
      matchesSemantics(
        label: 'Explore',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    expect(
      tester.getSemantics(find.text('Diaries')),
      matchesSemantics(
        label: 'Diaries',
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('hidden labels still read and fall back to tooltips', (
    tester,
  ) async {
    await _pump(tester, style: _style(labelMode: HomeBarLabelMode.never));
    expect(find.text('Diaries'), findsNothing);
    expect(find.byTooltip('Diaries'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
  });

  testWidgets('selected-only labels show the selected label alone', (
    tester,
  ) async {
    await _pump(
      tester,
      style: _style(labelMode: HomeBarLabelMode.selected),
      selected: 1,
    );
    // 未选中项的文字高度收为 0，只留提示。
    expect(tester.getSize(find.text('Calendar')).height, greaterThan(0));
    expect(find.byTooltip('Calendar'), findsNothing);
    expect(find.byTooltip('Diaries'), findsOneWidget);
  });

  testWidgets(
    'hovering a destination shows a pointer cursor on desktop',
    variant: TargetPlatformVariant.desktop(),
    (tester) async {
      await _pump(tester);
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        pointer: 1,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text('Calendar')));
      await tester.pump();
      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.click,
      );
    },
  );

  for (final indicator in HomeBarIndicator.values) {
    for (final labelMode in HomeBarLabelMode.values) {
      testWidgets('a short window scrolls instead of overflowing '
          '($indicator, $labelMode, text 2.0)', (tester) async {
        await _pump(
          tester,
          style: _style(indicator: indicator, labelMode: labelMode),
          size: const Size(700, 260),
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}

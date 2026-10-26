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
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(brightness),
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
  testWidgets('a solid rail paints the same fill as the phone bottom bar', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      final theme = expressiveTestTheme(brightness);
      final style = HomeBarResolvedStyle.resolve(
        HomeBarStyle.defaults,
        theme.colorScheme,
      );
      await _pump(tester, style: style, brightness: brightness);
      final rail = find.byType(HomeNavRail);
      expect(tester.getSize(rail), const Size(96, 600));
      final material = tester.widget<Material>(
        find.descendant(of: rail, matching: find.byType(Material)).first,
      );
      // 与 BottomNav 的底色同源。
      expect(
        material.color,
        theme.navigationBarTheme.backgroundColor,
        reason: '$brightness',
      );
    }
  });

  testWidgets('a glass rail uses the opaque tint, custom colours included, '
      'and never blurs', (tester) async {
    final style = HomeBarResolvedStyle.resolve(
      const HomeBarStyle(
        material: HomeBarMaterial.glass,
        tint: HomeBarTint.custom,
        tintColor: 0xFF3366AA,
      ),
      expressiveTestTheme(Brightness.light).colorScheme,
    );
    await _pump(tester, style: style);
    final rail = find.byType(HomeNavRail);
    final material = tester.widget<Material>(
      find.descendant(of: rail, matching: find.byType(Material)).first,
    );
    expect(material.color, style.solidFill);
    expect(
      find.descendant(of: rail, matching: find.byType(BackdropFilter)),
      findsNothing,
    );
  });

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
    final indicators = find.byType(HomeNavIndicator);
    // 第一个指示器在 FAB 下方 28 处。
    expect(
      tester.getRect(indicators.at(0)).top,
      closeTo(fabBottom.dy + 28, 0.01),
    );
    // 上一项文字底到下一项指示器顶 16。
    expect(
      tester.getRect(indicators.at(1)).top - diaries.bottom,
      closeTo(16, 0.01),
    );
    expect(
      tester.getRect(indicators.at(2)).top - calendar.bottom,
      closeTo(16, 0.01),
    );
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
    'hovering a destination keeps the platform default cursor',
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
        SystemMouseCursors.basic,
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

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_resolved_style.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_bar.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_rail.dart';

import '../../../../support/expressive_test_theme.dart';

const _items = <BottomNavItem>[
  BottomNavItem(label: 'Diaries', icon: FontAwesomeIcons.book),
  BottomNavItem(label: 'To-dos', icon: FontAwesomeIcons.squareCheck),
  BottomNavItem(label: 'Calendar', icon: FontAwesomeIcons.calendarDays),
  BottomNavItem(label: 'Explore', icon: FontAwesomeIcons.compass),
];

HomeBarResolvedStyle _style({
  HomeBarLabelMode labelMode = HomeBarLabelMode.always,
}) => HomeBarResolvedStyle.resolve(
  HomeBarStyle(labelMode: labelMode),
  expressiveTestTheme(Brightness.light).colorScheme,
);

/// 各导航项的格子（承载指示器与内容的那层 Stack）。
Finder get _cells => find.descendant(
  of: find.byType(HomeNavRailDestination),
  matching: find.byType(Stack),
);

/// 各格子里的指示器（未选中时横向缩放为 0）。
Finder get _indicators => find.descendant(
  of: find.byType(HomeNavRailDestination),
  matching: find.byType(Ink),
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
  testWidgets('an untinted rail blends with the page canvas', (tester) async {
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
      // 中性色调：与页面连成一片，不用玻璃的等效色。
      expect(style.tinted, isFalse);
      expect(
        material.color,
        theme.navigationBarTheme.backgroundColor,
        reason: '$brightness',
      );
    }
  });

  testWidgets('a tinted rail uses the opaque tint and never blurs', (
    tester,
  ) async {
    final style = HomeBarResolvedStyle.resolve(
      const HomeBarStyle(tint: HomeBarTint.theme),
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

  testWidgets('destinations stack below the button from the top', (
    tester,
  ) async {
    await _pump(tester);
    final fabBottom = tester.getBottomLeft(find.byType(FloatingActionButton));
    expect(_cells, findsNWidgets(4));
    // 第一格在 FAB 下方 28 处。
    expect(tester.getRect(_cells.at(0)).top, closeTo(fabBottom.dy + 28, 0.01));
    // 相邻两格之间 8；最后一项同样紧接上一项，不固定在栏底（设置不是 Tab）。
    for (var i = 1; i < 4; i++) {
      expect(
        tester.getRect(_cells.at(i)).top -
            tester.getRect(_cells.at(i - 1)).bottom,
        closeTo(8, 0.01),
      );
    }
    expect(tester.getRect(_cells.at(3)).bottom, lessThan(600 - 16 - 100));
  });

  testWidgets('a destination is the same cell as on the bottom bar', (
    tester,
  ) async {
    await _pump(tester, selected: 1);
    for (var i = 0; i < 4; i++) {
      final cell = tester.getRect(_cells.at(i));
      // 72×56 的格子在 96 宽的栏里居中，图标与文字在格子里居中。
      expect(cell.size, const Size(72, 48));
      expect(cell.center.dx, 48);
      final icon = tester.getCenter(find.byType(FaIcon).at(i + 1));
      final label = tester.getRect(find.text(_items[i].label));
      expect(icon.dx, closeTo(cell.center.dx, 0.01));
      expect(label.center.dx, closeTo(cell.center.dx, 0.01));
      expect(
        icon.dy - 12 - cell.top,
        closeTo(cell.bottom - label.bottom, 0.01),
      );
    }

    await _pump(tester, style: _style(labelMode: HomeBarLabelMode.never));
    expect(tester.getRect(_cells.at(0)).size, const Size(64, 42));
  });

  testWidgets('only the selected cell shows the capsule indicator', (
    tester,
  ) async {
    final style = _style();
    await _pump(tester, style: style, selected: 2);
    for (var i = 0; i < 4; i++) {
      final ink = tester.widget<Ink>(_indicators.at(i));
      final decoration = ink.decoration! as ShapeDecoration;
      expect(decoration.shape, const StadiumBorder());
      expect(decoration.color, style.indicatorColor);
      final scaleX = tester
          .widget<Transform>(
            find
                .ancestor(
                  of: _indicators.at(i),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .storage[0];
      expect(scaleX, i == 2 ? 1 : 0, reason: 'cell $i');
    }
  });

  testWidgets('tapping a destination reports its index', (tester) async {
    final tapped = <int>[];
    await _pump(tester, onTap: tapped.add);
    await tester.tap(find.text('Calendar'));
    await tester.tap(find.text('Explore'));
    await tester.tap(find.text('Diaries'));
    expect(tapped, <int>[2, 3, 0]);
  });

  testWidgets('semantics marks only the selected destination', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, selected: 3);
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
    expect(find.byTooltip('Explore'), findsOneWidget);
  });

  testWidgets('selected-only labels show the selected label alone', (
    tester,
  ) async {
    await _pump(
      tester,
      style: _style(labelMode: HomeBarLabelMode.selected),
      selected: 2,
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

  for (final labelMode in HomeBarLabelMode.values) {
    testWidgets('a short window scrolls instead of overflowing '
        '($labelMode, text 2.0)', (tester) async {
      await _pump(
        tester,
        style: _style(labelMode: labelMode),
        size: const Size(700, 260),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

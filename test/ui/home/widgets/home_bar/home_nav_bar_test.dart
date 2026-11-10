import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_metrics.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_resolved_style.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_bar.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_destination.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_geometry.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_indicator.dart';

import '../../../../support/expressive_test_theme.dart';

const _labels = <String>['Diaries', 'Calendar', 'Explore', 'Settings'];
const _items = <BottomNavItem>[
  BottomNavItem(label: 'Diaries', icon: FontAwesomeIcons.book),
  BottomNavItem(label: 'Calendar', icon: FontAwesomeIcons.calendarDays),
  BottomNavItem(label: 'Explore', icon: FontAwesomeIcons.compass),
  BottomNavItem(label: 'Settings', icon: FontAwesomeIcons.gear),
];

ColorScheme get _scheme => expressiveTestTheme(Brightness.light).colorScheme;

HomeBarResolvedStyle _style({
  HomeBarLabelMode labelMode = HomeBarLabelMode.always,
}) => HomeBarResolvedStyle.resolve(HomeBarStyle(labelMode: labelMode), _scheme);

Future<void> _pump(
  WidgetTester tester, {
  HomeBarResolvedStyle? style,
  List<BottomNavItem> items = _items,
  int selected = 0,
  ValueChanged<int>? onTap,
  ValueListenable<double>? position,
  double? itemWidth,
  bool reduceMotion = false,
  TextDirection textDirection = TextDirection.ltr,
  double textScale = 1,
}) => tester.pumpWidget(
  MaterialApp(
    theme: expressiveTestTheme(Brightness.light),
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: reduceMotion,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Directionality(textDirection: textDirection, child: child!),
    ),
    home: Scaffold(
      body: Center(
        child: HomeNavBar(
          items: items,
          selectedIndex: selected,
          onTap: onTap ?? (_) {},
          style: style ?? _style(),
          itemWidth: itemWidth,
          position: position,
        ),
      ),
    ),
  ),
);

Finder _destination(int index) => find.byType(HomeNavDestination).at(index);

/// 指示器此刻画出的圆角矩形（导航行的坐标系）。
RRect _indicator(WidgetTester tester) {
  RRect? painted;
  expect(
    tester.renderObject(
      find.descendant(
        of: find.byType(HomeNavIndicator),
        matching: find.byType(CustomPaint),
      ),
    ),
    paints..something((Symbol method, List<dynamic> arguments) {
      if (method != #drawRRect) {
        return false;
      }
      painted = arguments.first as RRect;
      return true;
    }),
  );
  return painted!;
}

/// 指示器中心所在的小数序号（按首选项宽 72 换算）。
double _indicatorAt(WidgetTester tester, {double itemWidth = 72}) =>
    _indicator(tester).center.dx / itemWidth - 0.5;

FaIcon _icon(WidgetTester tester, int index) => tester.widget<FaIcon>(
  find.descendant(of: _destination(index), matching: find.byType(FaIcon)),
);

Offset _iconCenter(WidgetTester tester, int index) => tester.getCenter(
  find.descendant(of: _destination(index), matching: find.byType(FaIcon)),
);

Finder _transforms(int index) =>
    find.descendant(of: _destination(index), matching: find.byType(Transform));

/// 内容的按压缩放（导航项里最外层的 Transform）。
double _pressScale(WidgetTester tester, int index) =>
    tester.widget<Transform>(_transforms(index).first).transform.storage[0];

/// 图标的选中放大（包着图标的 Transform）。
double _iconScale(WidgetTester tester, int index) =>
    tester.widget<Transform>(_transforms(index).last).transform.storage[0];

/// “只显示选中项文字”时文字的展开程度与不透明度。
double _labelExtent(WidgetTester tester, String label) => tester
    .widget<Align>(
      find.ancestor(of: find.text(label), matching: find.byType(Align)).first,
    )
    .heightFactor!;

double _labelOpacity(WidgetTester tester, String label) => tester
    .widget<Opacity>(
      find.ancestor(of: find.text(label), matching: find.byType(Opacity)).first,
    )
    .opacity;

void main() {
  testWidgets('the row is a strip of fixed-width cells', (tester) async {
    await _pump(tester);
    // 四项 × 72 宽、64 高的栏减去上下的缝。
    expect(tester.getSize(find.byType(HomeNavBar)), const Size(288, 48));
    for (var i = 0; i < _items.length; i++) {
      expect(tester.getSize(_destination(i)), const Size(72, 48));
    }
    // 项越少栏越短，每项的宽度不变。
    await _pump(tester, items: _items.sublist(0, 2));
    expect(tester.getSize(find.byType(HomeNavBar)), const Size(144, 48));
  });

  testWidgets('icon-only bars use shorter, narrower cells', (tester) async {
    await _pump(tester, style: _style(labelMode: HomeBarLabelMode.never));
    expect(tester.getSize(find.byType(HomeNavBar)), const Size(256, 42));
    expect(tester.getSize(_destination(0)), const Size(64, 42));
  });

  testWidgets('a narrower item width from the bar is honoured', (tester) async {
    await _pump(tester, itemWidth: 60, selected: 3);
    expect(tester.getSize(find.byType(HomeNavBar)).width, 240);
    expect(_indicator(tester).outerRect, const Rect.fromLTWH(180, 0, 60, 48));
  });

  testWidgets('tapping a destination reports its index', (tester) async {
    final taps = <int>[];
    await _pump(tester, onTap: taps.add);
    for (final label in _labels.reversed) {
      await tester.tap(find.text(label));
    }
    expect(taps, <int>[3, 2, 1, 0]);
  });

  testWidgets('each destination is a tab with its position in semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, selected: 2);
    for (var i = 0; i < _labels.length; i++) {
      expect(
        tester.getSemantics(_destination(i)),
        isSemantics(
          label: '${_labels[i]}\nTab ${i + 1} of 4',
          isSelected: i == 2,
          isButton: true,
          hasTapAction: true,
        ),
      );
    }
    semantics.dispose();
  });

  testWidgets('keyboard focus and Enter or Space activate a destination', (
    tester,
  ) async {
    final taps = <int>[];
    await _pump(tester, onTap: taps.add);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(taps, <int>[0, 1]);
  });

  testWidgets('the icon sits above the label, centred in the cell', (
    tester,
  ) async {
    await _pump(tester, selected: 1);
    for (var i = 0; i < _labels.length; i++) {
      final cell = tester.getRect(_destination(i));
      final icon = _iconCenter(tester, i);
      final label = tester.getRect(find.text(_labels[i]));
      expect(icon.dx, closeTo(cell.center.dx, 0.01));
      expect(label.center.dx, closeTo(cell.center.dx, 0.01));
      // 图标框（24）+ 间距 + 文字整体竖直居中：上下留白相等。
      final top = icon.dy - HomeBarMetrics.iconBox / 2 - cell.top;
      final bottom = cell.bottom - label.bottom;
      expect(top, closeTo(bottom, 0.01));
      expect(
        label.top - (icon.dy + HomeBarMetrics.iconBox / 2),
        closeTo(HomeBarMetrics.labelGap, 0.01),
      );
    }
  });

  testWidgets('long labels shrink to fit the cell instead of clipping', (
    tester,
  ) async {
    const long = <BottomNavItem>[
      BottomNavItem(label: 'A very long destination', icon: FontAwesomeIcons.a),
      BottomNavItem(label: 'B', icon: FontAwesomeIcons.b),
    ];
    for (final scale in <double>[1, 3]) {
      await _pump(tester, items: long, textScale: scale);
      final cell = tester.getRect(_destination(0));
      final label = tester.getRect(find.text('A very long destination'));
      expect(label.left, greaterThanOrEqualTo(cell.left));
      expect(label.right, lessThanOrEqualTo(cell.right));
      expect(label.bottom, lessThanOrEqualTo(cell.bottom));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('selected label mode shows only the selected label', (
    tester,
  ) async {
    final style = _style(labelMode: HomeBarLabelMode.selected);
    await _pump(tester, style: style, selected: 1);
    expect(_labelExtent(tester, 'Calendar'), 1);
    expect(_labelOpacity(tester, 'Calendar'), 1);
    expect(_labelExtent(tester, 'Diaries'), 0);
    expect(_labelOpacity(tester, 'Diaries'), 0);
    // 没有文字的项图标竖直居中；有文字的图标让到上方。
    final cell = tester.getRect(_destination(0));
    expect(_iconCenter(tester, 0).dy, closeTo(cell.center.dy, 0.01));
    expect(_iconCenter(tester, 1).dy, lessThan(cell.center.dy - 4));

    await _pump(tester, style: style, selected: 0);
    await tester.pumpAndSettle();
    expect(_labelExtent(tester, 'Diaries'), 1);
    expect(_labelOpacity(tester, 'Diaries'), 1);
    expect(_labelExtent(tester, 'Calendar'), 0);
    expect(_iconCenter(tester, 1).dy, closeTo(cell.center.dy, 0.01));
  });

  testWidgets('never label mode centres icons and keeps names in semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, style: _style(labelMode: HomeBarLabelMode.never));
    expect(find.text('Diaries'), findsNothing);
    final cell = tester.getRect(_destination(0));
    expect(_iconCenter(tester, 0), within(distance: 0.01, from: cell.center));
    expect(
      tester.getSemantics(_destination(0)),
      isSemantics(
        label: 'Diaries\nTab 1 of 4',
        isSelected: true,
        isButton: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('the indicator is a capsule filling the selected cell', (
    tester,
  ) async {
    final style = _style();
    await _pump(tester, style: style, selected: 2);
    final indicator = _indicator(tester);
    expect(indicator.outerRect, const Rect.fromLTWH(144, 0, 72, 48));
    expect(indicator.tlRadiusX, 24);
    expect(
      tester.renderObject(
        find.descendant(
          of: find.byType(HomeNavIndicator),
          matching: find.byType(CustomPaint),
        ),
      ),
      paints..rrect(color: style.indicatorColor),
    );
  });

  testWidgets('right-to-left mirrors the indicator with the cells', (
    tester,
  ) async {
    await _pump(tester, selected: 0, textDirection: TextDirection.rtl);
    expect(_indicator(tester).outerRect, const Rect.fromLTWH(216, 0, 72, 48));
    final bar = tester.getRect(find.byType(HomeNavBar));
    expect(tester.getRect(_destination(0)).right, bar.right);
  });

  testWidgets('a new selection slides the one indicator over on a spring', (
    tester,
  ) async {
    await _pump(tester);
    expect(_indicatorAt(tester), 0);

    await _pump(tester, selected: 2);
    await tester.pump(const Duration(milliseconds: 80));
    // 途中：在两项之间，并被速度拉长、压扁。
    final moving = _indicator(tester);
    expect(_indicatorAt(tester), inExclusiveRange(0, 2));
    expect(moving.width, greaterThan(72));
    expect(moving.height, lessThan(48));

    await tester.pumpAndSettle();
    expect(_indicator(tester).outerRect, const Rect.fromLTWH(144, 0, 72, 48));
  });

  testWidgets('the spring eases past the target before settling', (
    tester,
  ) async {
    await _pump(tester);
    await _pump(tester, selected: 1);
    var furthest = 0.0;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final at = _indicatorAt(tester);
      if (at > furthest) furthest = at;
    }
    // 轻轻越过再收回：看得出弹性，但远不到下一项。
    expect(furthest, greaterThan(1));
    expect(furthest, lessThan(1.1));
    await tester.pumpAndSettle();
    expect(_indicatorAt(tester), closeTo(1, 0.0001));
  });

  testWidgets('the indicator squashes against the pill instead of leaving it', (
    tester,
  ) async {
    await _pump(tester);
    await _pump(tester, selected: 3);
    final bar = tester.getSize(find.byType(HomeNavBar));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final rect = _indicator(tester).outerRect;
      expect(rect.left, greaterThanOrEqualTo(-HomeNavGeometry.edgeRoom));
      expect(
        rect.right,
        lessThanOrEqualTo(bar.width + HomeNavGeometry.edgeRoom),
      );
    }
  });

  testWidgets('destinations the indicator passes over keep their colour', (
    tester,
  ) async {
    final style = _style();
    await _pump(tester, style: style);
    await _pump(tester, style: style, selected: 3);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(_icon(tester, 1).color, style.unselectedForeground);
      expect(_icon(tester, 2).color, style.unselectedForeground);
    }
    await tester.pumpAndSettle();
    expect(_icon(tester, 3).color, style.selectedForeground);
    expect(_icon(tester, 0).color, style.unselectedForeground);
  });

  testWidgets('retargeting mid-flight heads for the newest selection', (
    tester,
  ) async {
    await _pump(tester);
    await _pump(tester, selected: 3);
    await tester.pump(const Duration(milliseconds: 120));
    final midway = _indicatorAt(tester);
    expect(midway, greaterThan(0.5));
    await _pump(tester, selected: 0);
    // 带着原来的速度掉头：下一帧还在往前走一点，随后才往回。
    await tester.pump(const Duration(milliseconds: 16));
    expect(_indicatorAt(tester), greaterThan(midway - 0.2));
    await tester.pumpAndSettle();
    expect(_indicatorAt(tester), closeTo(0, 0.0001));
  });

  testWidgets('the icon pops past its selected size before settling', (
    tester,
  ) async {
    await _pump(tester);
    expect(_iconScale(tester, 0), HomeNavGeometry.selectedIconScale);
    expect(_iconScale(tester, 1), 1);

    await _pump(tester, selected: 1);
    var largest = 0.0;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final scale = _iconScale(tester, 1);
      if (scale > largest) largest = scale;
    }
    expect(largest, greaterThan(HomeNavGeometry.selectedIconScale + 0.01));
    await tester.pumpAndSettle();
    expect(
      _iconScale(tester, 1),
      closeTo(HomeNavGeometry.selectedIconScale, 0.001),
    );
    expect(_iconScale(tester, 0), closeTo(1, 0.001));
  });

  testWidgets('reduce motion moves everything at once', (tester) async {
    await _pump(tester, reduceMotion: true);
    await _pump(tester, reduceMotion: true, selected: 3);
    await tester.pump();
    expect(_indicator(tester).outerRect, const Rect.fromLTWH(216, 0, 72, 48));
    expect(_iconScale(tester, 3), HomeNavGeometry.selectedIconScale);
    expect(_iconScale(tester, 0), 1);
  });

  testWidgets('pressing shrinks the content and releasing springs it back', (
    tester,
  ) async {
    await _pump(tester);
    expect(_pressScale(tester, 2), 1);
    final gesture = await tester.startGesture(
      tester.getCenter(_destination(2)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(_pressScale(tester, 2), lessThan(0.97));
    // 其他项不受影响。
    expect(_pressScale(tester, 1), 1);

    await gesture.up();
    var largest = 0.0;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final scale = _pressScale(tester, 2);
      if (scale > largest) largest = scale;
    }
    // 松手后弹过原大小一点再落回。
    expect(largest, greaterThan(1));
    await tester.pumpAndSettle();
    expect(_pressScale(tester, 2), closeTo(1, 0.001));
  });

  testWidgets('reduce motion skips the press scale', (tester) async {
    await _pump(tester, reduceMotion: true);
    final gesture = await tester.startGesture(
      tester.getCenter(_destination(2)),
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(_pressScale(tester, 2), 1);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('switching tab sets drops the indicator on the new index', (
    tester,
  ) async {
    await _pump(tester, selected: 3);
    // Tab 集合变化（功能管理关掉一个 Tab）：旧序号已不对应同一项，不滑动。
    await _pump(tester, items: _items.sublist(0, 3), selected: 1);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(_indicator(tester).outerRect, const Rect.fromLTWH(72, 0, 72, 48));
    }
  });

  testWidgets('an out-of-range selection clamps to the last item', (
    tester,
  ) async {
    await _pump(tester, items: _items.sublist(0, 2), selected: 5);
    expect(_indicator(tester).outerRect, const Rect.fromLTWH(72, 0, 72, 48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('follow swipe puts the indicator between the two pages', (
    tester,
  ) async {
    final style = _style(labelMode: HomeBarLabelMode.selected);
    final position = ValueNotifier<double>(0);
    addTearDown(position.dispose);
    await _pump(tester, style: style, position: position);

    position.value = 0.5;
    await tester.pump();
    // 跟手：正好在两项中间，不拉伸。
    expect(_indicator(tester).outerRect, const Rect.fromLTWH(36, 0, 72, 48));
    // 两项的图标与文字都按距离插值。
    expect(_labelOpacity(tester, 'Diaries'), closeTo(0.5, 0.001));
    expect(_labelOpacity(tester, 'Calendar'), closeTo(0.5, 0.001));
    expect(
      _icon(tester, 0).color,
      Color.lerp(style.unselectedForeground, style.selectedForeground, 0.5),
    );
    expect(_icon(tester, 2).color, style.unselectedForeground);

    // 页面越界回弹时指示器停在两端。
    position.value = -0.4;
    await tester.pump();
    expect(_indicator(tester).outerRect, const Rect.fromLTWH(0, 0, 72, 48));
    position.value = 3.4;
    await tester.pump();
    expect(_indicator(tester).outerRect, const Rect.fromLTWH(216, 0, 72, 48));
  });

  testWidgets('turning follow swipe off leaves the indicator where it was', (
    tester,
  ) async {
    final position = ValueNotifier<double>(2);
    addTearDown(position.dispose);
    await _pump(tester, selected: 2, position: position);
    await _pump(tester, selected: 2);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(_indicator(tester).outerRect, const Rect.fromLTWH(144, 0, 72, 48));
    }
  });

  testWidgets('colours come from the resolved style', (tester) async {
    final style = _style();
    await _pump(tester, style: style, selected: 1);
    expect(_icon(tester, 1).color, style.selectedForeground);
    expect(_icon(tester, 0).color, style.unselectedForeground);
    expect(
      tester.widget<Text>(find.text('Calendar')).style!.color,
      style.selectedForeground,
    );
    final unselected = tester.widget<Text>(find.text('Diaries')).style!;
    expect(unselected.color, style.unselectedForeground);
    expect(unselected.fontSize, HomeBarMetrics.labelFontSize);
    // 选中与否同一字重：切换时文字不左右抖。
    expect(
      unselected.fontWeight,
      tester.widget<Text>(find.text('Calendar')).style!.fontWeight,
    );
  });
}

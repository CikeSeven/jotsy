import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_resolved_style.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_bar.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_destination.dart';
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
  HomeBarIndicator indicator = HomeBarIndicator.capsule,
}) => HomeBarResolvedStyle.resolve(
  HomeBarStyle(labelMode: labelMode, indicator: indicator),
  _scheme,
);

Future<void> _pump(
  WidgetTester tester, {
  HomeBarResolvedStyle? style,
  int selected = 0,
  ValueChanged<int>? onTap,
  ValueListenable<double>? position,
  double width = 400,
  double height = 80,
  bool reduceMotion = false,
}) => tester.pumpWidget(
  MaterialApp(
    theme: expressiveTestTheme(Brightness.light),
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: width,
          child: HomeNavBar(
            items: _items,
            selectedIndex: selected,
            onTap: onTap ?? (_) {},
            style: style ?? _style(),
            height: height,
            position: position,
          ),
        ),
      ),
    ),
  ),
);

Finder _destination(int index) => find.byType(HomeNavDestination).at(index);

Finder _indicator(int index) => find.descendant(
  of: _destination(index),
  matching: find.byType(HomeNavIndicator),
);

double _labelOpacity(WidgetTester tester, String label) => tester
    .widget<FadeTransition>(
      find
          .ancestor(of: find.text(label), matching: find.byType(FadeTransition))
          .first,
    )
    .opacity
    .value;

Offset _iconCenter(WidgetTester tester, int index) => tester.getCenter(
  find.descendant(of: _destination(index), matching: find.byType(FaIcon)),
);

double _indicatorScaleX(WidgetTester tester, int index) => tester
    .widget<Transform>(
      find.descendant(of: _indicator(index), matching: find.byType(Transform)),
    )
    .transform
    .storage[0];

/// 此刻画着指示器的那一项（其余项的指示器缩放为 0）。
int _anchor(WidgetTester tester) => <int>[
  for (var i = 0; i < _items.length; i++)
    if (_indicatorScaleX(tester, i) == 1) i,
].single;

FaIcon _icon(WidgetTester tester, int index) => tester.widget<FaIcon>(
  find.descendant(of: _destination(index), matching: find.byType(FaIcon)),
);

/// 整项的按压缩放（包着导航项布局的那层 Transform）。
double _pressScale(WidgetTester tester, int index) => tester
    .widget<Transform>(
      find
          .ancestor(
            of: find.descendant(
              of: _destination(index),
              matching: find.byType(CustomMultiChildLayout),
            ),
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .storage[0];

void main() {
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

  testWidgets('always shows every label', (tester) async {
    await _pump(tester, selected: 1);
    for (final label in _labels) {
      expect(_labelOpacity(tester, label), 1);
    }
  });

  testWidgets('selected label mode shows only the selected label', (
    tester,
  ) async {
    await _pump(
      tester,
      selected: 1,
      style: _style(labelMode: HomeBarLabelMode.selected),
    );
    final barCenterY = tester.getCenter(find.byType(HomeNavBar)).dy;
    for (var i = 0; i < _labels.length; i++) {
      expect(_labelOpacity(tester, _labels[i]), i == 1 ? 1 : 0);
      if (i != 1) {
        expect(_iconCenter(tester, i).dy, closeTo(barCenterY, 0.01));
      }
    }
    expect(_iconCenter(tester, 1).dy, lessThan(barCenterY - 1));

    // 切换选中：新项的文字随选中动画显现，旧项的收起。
    await _pump(
      tester,
      selected: 2,
      style: _style(labelMode: HomeBarLabelMode.selected),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(_labelOpacity(tester, 'Explore'), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(_labelOpacity(tester, 'Explore'), 1);
    expect(_labelOpacity(tester, 'Calendar'), 0);
  });

  testWidgets('never label mode centres icons and keeps labels in semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, style: _style(labelMode: HomeBarLabelMode.never));
    final barCenterY = tester.getCenter(find.byType(HomeNavBar)).dy;
    for (var i = 0; i < _labels.length; i++) {
      expect(_labelOpacity(tester, _labels[i]), 0);
      expect(_iconCenter(tester, i).dy, closeTo(barCenterY, 0.01));
      expect(
        tester.getSemantics(_destination(i)),
        isSemantics(label: '${_labels[i]}\nTab ${i + 1} of 4'),
      );
    }
    expect(find.byTooltip('Diaries'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('capsule indicator is 64 by 32 centred on the icon', (
    tester,
  ) async {
    await _pump(tester, selected: 1);
    final rect = tester.getRect(_indicator(1));
    expect(rect.size, const Size(64, 32));
    expect(rect.center.dx, closeTo(_iconCenter(tester, 1).dx, 0.01));
    expect(_indicatorScaleX(tester, 1), 1);
    expect(_indicatorScaleX(tester, 0), 0);
  });

  testWidgets('no indicator draws no fill', (tester) async {
    await _pump(tester, style: _style(indicator: HomeBarIndicator.none));
    expect(find.byType(HomeNavIndicator), findsNothing);
    final icon = tester.widget<FaIcon>(
      find.descendant(of: _destination(0), matching: find.byType(FaIcon)),
    );
    expect(icon.color, _style().selectedForeground);
  });

  testWidgets('a new selection slides the one indicator over on a spring', (
    tester,
  ) async {
    await _pump(tester);
    expect(_anchor(tester), 0);
    final from = _iconCenter(tester, 0).dx;
    final to = _iconCenter(tester, 3).dx;

    await _pump(tester, selected: 3);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    // 途中：只有一个指示器，位置在两项之间，并被速度横向拉长。
    final mid = tester.getRect(_indicator(_anchor(tester)));
    expect(mid.center.dx, inExclusiveRange(from, to));
    expect(mid.width, greaterThan(64));
    expect(mid.height, 32);

    await tester.pumpAndSettle();
    expect(_anchor(tester), 3);
    final rest = tester.getRect(_indicator(3));
    expect(rest.center.dx, closeTo(to, 0.1));
    expect(rest.width, closeTo(64, 0.01));
  });

  testWidgets('the spring overshoots the target before settling', (
    tester,
  ) async {
    await _pump(tester);
    final to = _iconCenter(tester, 1).dx;
    await _pump(tester, selected: 1);
    await tester.pump();
    var furthest = double.negativeInfinity;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final dx = tester.getRect(_indicator(_anchor(tester))).center.dx;
      if (dx > furthest) furthest = dx;
    }
    // 越过目标一点再落回，但不会冲到下一项。
    expect(furthest, greaterThan(to + 1));
    expect(furthest, lessThan(to + 20));
    await tester.pumpAndSettle();
    expect(tester.getRect(_indicator(1)).center.dx, closeTo(to, 0.1));
  });

  testWidgets('destinations the indicator passes over keep their colour', (
    tester,
  ) async {
    final style = _style();
    await _pump(tester, style: style);
    await _pump(tester, style: style, selected: 3);
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(_icon(tester, 1).color, style.unselectedForeground);
      expect(_icon(tester, 2).color, style.unselectedForeground);
    }
    // 新旧两项的颜色在渐变，途中既不是选中色也不是未选中色。
    expect(_icon(tester, 3).color, isNot(style.unselectedForeground));
    expect(_icon(tester, 3).color, isNot(style.selectedForeground));
    await tester.pumpAndSettle();
    expect(_icon(tester, 3).color, style.selectedForeground);
    expect(_icon(tester, 0).color, style.unselectedForeground);
  });

  testWidgets('retargeting mid-flight heads for the newest selection', (
    tester,
  ) async {
    await _pump(tester);
    await _pump(tester, selected: 3);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await _pump(tester, selected: 1);
    await tester.pumpAndSettle();
    expect(_anchor(tester), 1);
    expect(
      tester.getRect(_indicator(1)).center.dx,
      closeTo(_iconCenter(tester, 1).dx, 0.1),
    );
  });

  testWidgets('reduce motion moves the indicator at once', (tester) async {
    await _pump(tester, reduceMotion: true);
    await _pump(tester, selected: 2, reduceMotion: true);
    await tester.pump();
    expect(_anchor(tester), 2);
    expect(
      tester.getRect(_indicator(2)).center.dx,
      closeTo(_iconCenter(tester, 2).dx, 0.01),
    );
    // 图标的放大与颜色也一步到位。
    expect(_icon(tester, 2).color, _style().selectedForeground);
    expect(_icon(tester, 0).color, _style().unselectedForeground);
    await tester.pumpAndSettle();
  });

  testWidgets('pressing shrinks a destination and releasing springs it back', (
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
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: HomeNavBar(
              items: _items.sublist(0, 2),
              selectedIndex: 1,
              onTap: (_) {},
              style: _style(),
              height: 80,
            ),
          ),
        ),
      ),
    );
    // 没有滑动的过程：下一帧指示器就在新的选中项上。
    expect(_indicatorScaleX(tester, 1), 1);
    expect(
      tester.getRect(_indicator(1)).center.dx,
      closeTo(_iconCenter(tester, 1).dx, 0.01),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('follow swipe puts the indicator between the two pages', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final position = ValueNotifier<double>(1.5);
    addTearDown(position.dispose);
    await _pump(tester, selected: 1, position: position);
    // 锚点项（第 1 项）画指示器，平移半格到第 1、2 项之间；其余缩放为 0。
    final rect = tester.getRect(_indicator(1));
    final between = (_iconCenter(tester, 1).dx + _iconCenter(tester, 2).dx) / 2;
    expect(rect.center.dx, closeTo(between, 0.01));
    expect(_indicatorScaleX(tester, 1), 1);
    for (final other in <int>[0, 2, 3]) {
      expect(_indicatorScaleX(tester, other), 0);
    }
    // 颜色按距离插值：两项各一半。
    final half = Color.lerp(
      _style().unselectedForeground,
      _style().selectedForeground,
      0.5,
    );
    for (final index in <int>[1, 2]) {
      final icon = tester.widget<FaIcon>(
        find.descendant(of: _destination(index), matching: find.byType(FaIcon)),
      );
      expect(icon.color, half);
    }
    // 语义仍按 selectedIndex。
    expect(tester.getSemantics(_destination(1)), isSemantics(isSelected: true));
    expect(
      tester.getSemantics(_destination(2)),
      isSemantics(isSelected: false),
    );

    position.value = 2;
    await tester.pump();
    expect(
      tester.getRect(_indicator(2)).center.dx,
      closeTo(_iconCenter(tester, 2).dx, 0.01),
    );
    expect(_indicatorScaleX(tester, 1), 0);
    semantics.dispose();
  });

  testWidgets('colours come from the resolved style', (tester) async {
    final style = _style();
    await _pump(tester, style: style, selected: 1);
    FaIcon icon(int index) => tester.widget<FaIcon>(
      find.descendant(of: _destination(index), matching: find.byType(FaIcon)),
    );
    expect(icon(1).color, style.selectedForeground);
    expect(icon(0).color, style.unselectedForeground);
    final selectedText = tester.widget<Text>(find.text('Calendar'));
    expect(selectedText.style!.color, style.selectedForeground);
    expect(selectedText.style!.fontWeight, FontWeight.w700);
    final otherText = tester.widget<Text>(find.text('Diaries'));
    expect(otherText.style!.color, style.unselectedForeground);
    expect(otherText.style!.fontWeight, FontWeight.w500);
    final ink = tester.widget<Ink>(
      find.descendant(of: _indicator(1), matching: find.byType(Ink)),
    );
    expect((ink.decoration! as ShapeDecoration).color, style.indicatorColor);
  });
}

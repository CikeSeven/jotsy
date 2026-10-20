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
  HomeBarMaterial material = HomeBarMaterial.solid,
  HomeBarLabelMode labelMode = HomeBarLabelMode.always,
  HomeBarIndicator indicator = HomeBarIndicator.capsule,
}) => HomeBarResolvedStyle.resolve(
  HomeBarStyle(material: material, labelMode: labelMode, indicator: indicator),
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
}) => tester.pumpWidget(
  MaterialApp(
    theme: expressiveTestTheme(Brightness.light),
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
    expect(icon.color, _scheme.onSecondaryContainer);
  });

  testWidgets('a new selection grows its indicator over the motion duration', (
    tester,
  ) async {
    await _pump(tester);
    await _pump(tester, selected: 3);
    await tester.pump(const Duration(milliseconds: 60));
    expect(_indicatorScaleX(tester, 3), inExclusiveRange(0.4, 1.2));
    await tester.pumpAndSettle();
    expect(_indicatorScaleX(tester, 3), 1);
    expect(_indicatorScaleX(tester, 0), 0);
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
      _scheme.onSurfaceVariant,
      _scheme.onSecondaryContainer,
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

  testWidgets('glass colours come from the resolved style', (tester) async {
    final style = _style(material: HomeBarMaterial.glass);
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

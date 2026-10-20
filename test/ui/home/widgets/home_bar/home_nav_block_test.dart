import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_resolved_style.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_bar.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_block.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_destination.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_indicator.dart';

import '../../../../support/expressive_test_theme.dart';

// 圆角块的尺寸、内边距与图标文字间距。测试字体按方块排版，文字尺寸一律
// 从渲染结果量取，不写死。

const _items = <BottomNavItem>[
  BottomNavItem(label: 'Diaries', icon: FontAwesomeIcons.book),
  BottomNavItem(label: 'Calendar', icon: FontAwesomeIcons.calendarDays),
  BottomNavItem(label: 'Explore', icon: FontAwesomeIcons.compass),
  BottomNavItem(label: 'Settings', icon: FontAwesomeIcons.gear),
];

const _glassBlock = HomeBarStyle(
  material: HomeBarMaterial.glass,
  indicator: HomeBarIndicator.block,
  labelGap: HomeBarStyle.glassLabelGap,
);

Future<void> _pump(
  WidgetTester tester,
  HomeBarStyle style, {
  int selected = 0,
  double width = 400,
  double height = 64,
  ValueListenable<double>? position,
}) async {
  final theme = expressiveTestTheme(Brightness.light);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: width,
            child: HomeNavBar(
              items: _items,
              selectedIndex: selected,
              onTap: (_) {},
              style: HomeBarResolvedStyle.resolve(style, theme.colorScheme),
              height: height,
              position: position,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _destination(int index) => find.byType(HomeNavDestination).at(index);

Rect _block(WidgetTester tester, int index) => tester.getRect(
  find.descendant(
    of: _destination(index),
    matching: find.byType(HomeNavIndicator),
  ),
);

Rect _icon(WidgetTester tester, int index) => tester.getRect(
  find.descendant(of: _destination(index), matching: find.byType(FaIcon)),
);

Rect _label(WidgetTester tester, int index) =>
    tester.getRect(find.text(_items[index].label));

void main() {
  testWidgets('glass block leaves the padding around icon and label', (
    tester,
  ) async {
    await _pump(tester, _glassBlock);
    final bar = tester.getRect(find.byType(HomeNavBar));
    final block = _block(tester, 0);
    final icon = _icon(tester, 0);
    final label = _label(tester, 0);
    // 选中图标放大 1.12 倍，量到的是放大后的矩形；图标框按放大留了余量，
    // 上沿最多比未放大时高 (1.12 − 1) × 20 / 2 = 1.2。
    expect(block.top, lessThanOrEqualTo(icon.top - 6 + 1.2 + 0.01));
    expect(block.bottom, greaterThanOrEqualTo(label.bottom + 5.5));
    expect(block.top, greaterThanOrEqualTo(bar.top));
    expect(block.bottom, lessThanOrEqualTo(bar.bottom));
    // 块与内容同心，内容在栏里竖直居中。
    expect(block.center.dy, closeTo(bar.center.dy, 0.01));
    expect(block.center.dx, closeTo(icon.center.dx, 0.01));

    // 圆角与栏同心：栏圆角 32 减去块到栏上下边缘的距离。
    final ink = tester.widget<Ink>(
      find.descendant(of: _destination(0), matching: find.byType(Ink)),
    );
    final shape = (ink.decoration! as ShapeDecoration).shape;
    expect(shape, isA<HomeNavBlockBorder>());
    final radius = (shape as HomeNavBlockBorder).radiusFor(block.height);
    expect(
      radius,
      closeTo((32 - (64 - block.height) / 2).clamp(0, block.height / 2), 0.001),
    );
  });

  testWidgets('block width keeps the old base rule and grows for long text', (
    tester,
  ) async {
    // 宽格子（每格 200）：短于基础宽度的内容用基础宽度 96。
    await _pump(
      tester,
      _glassBlock.copyWith(labelMode: HomeBarLabelMode.never),
      width: 800,
    );
    expect(_block(tester, 0).width, closeTo(96, 0.01));

    // 文字比基础宽度更宽时，块按文字宽 + 2 × 内边距加宽。
    await _pump(tester, _glassBlock.copyWith(blockPadding: 16), width: 800);
    final label = _label(tester, 0);
    expect(
      _block(tester, 0).width,
      closeTo((label.width + 32).clamp(96, 200 - 4), 0.01),
    );

    // 窄格子（每格 100）：块宽封顶为格宽 − 4。
    await _pump(tester, _glassBlock.copyWith(blockPadding: 16));
    expect(_block(tester, 0).width, lessThanOrEqualTo(96 + 0.01));
  });

  testWidgets('more padding grows the block until it reaches the bar margin', (
    tester,
  ) async {
    await _pump(tester, _glassBlock.copyWith(blockPadding: 4));
    final base = _block(tester, 0).height;
    await _pump(tester, _glassBlock);
    expect(_block(tester, 0).height, closeTo(base + 4, 0.01));
    // 再大就夹到栏高 − 4，块不贴住栏的边缘。
    await _pump(tester, _glassBlock.copyWith(blockPadding: 16));
    expect(_block(tester, 0).height, closeTo(64 - 4, 0.01));
    final bar = tester.getRect(find.byType(HomeNavBar));
    expect(_block(tester, 0).top, closeTo(bar.top + 2, 0.01));
  });

  for (final indicator in <HomeBarIndicator>[
    HomeBarIndicator.capsule,
    HomeBarIndicator.block,
  ]) {
    testWidgets('label gap moves the label away from the icon ($indicator)', (
      tester,
    ) async {
      double gap() => _label(tester, 1).top - _icon(tester, 1).center.dy;

      await _pump(
        tester,
        HomeBarStyle(indicator: indicator, labelGap: 2),
        height: 80,
      );
      final narrow = gap();
      await _pump(
        tester,
        HomeBarStyle(indicator: indicator, labelGap: 9),
        height: 80,
      );
      expect(gap() - narrow, closeTo(7, 0.01));
    });
  }

  testWidgets('without labels the block wraps only the icon slot', (
    tester,
  ) async {
    await _pump(
      tester,
      _glassBlock.copyWith(labelMode: HomeBarLabelMode.never),
    );
    final block = _block(tester, 0);
    // 图标框 = 图标 20 + 放大余量 4，上下各加内边距 6。
    expect(block.height, closeTo(20 + 4 + 12, 0.01));
    expect(block.center.dy, closeTo(_icon(tester, 0).center.dy, 0.01));
  });

  testWidgets('selected-only labels: unselected items wrap just the icon', (
    tester,
  ) async {
    await _pump(
      tester,
      _glassBlock.copyWith(labelMode: HomeBarLabelMode.selected),
      selected: 1,
    );
    final withLabel = _block(tester, 1);
    expect(withLabel.bottom, greaterThanOrEqualTo(_label(tester, 1).bottom));
    // 改选第 0 项：它的块按图标框 + 文字长出，旧项的文字收起。
    await _pump(
      tester,
      _glassBlock.copyWith(labelMode: HomeBarLabelMode.selected),
    );
    expect(_block(tester, 0).height, closeTo(withLabel.height, 0.01));
  });

  testWidgets('follow swipe interpolates the block between two items', (
    tester,
  ) async {
    final position = ValueNotifier<double>(1);
    addTearDown(position.dispose);
    // 宽格子（每格 150）+ 大内边距：块宽由文字决定，两项不同宽。
    final style = _glassBlock.copyWith(blockPadding: 12);
    await _pump(tester, style, selected: 1, width: 600, position: position);
    final calendar = _block(tester, 1);
    position.value = 2;
    await tester.pump();
    final explore = _block(tester, 2);

    position.value = 1.5;
    await tester.pump();
    final rect = _block(tester, 1);
    expect(
      rect.center.dx,
      closeTo(
        (_icon(tester, 1).center.dx + _icon(tester, 2).center.dx) / 2,
        0.01,
      ),
    );
    expect(rect.width, closeTo((calendar.width + explore.width) / 2, 0.01));
    expect(rect.height, closeTo((calendar.height + explore.height) / 2, 0.01));
  });

  test('block radius is concentric with the bar and never negative', () {
    const border = HomeNavBlockBorder(cornerRadius: 32, barHeight: 64);
    expect(border.radiusFor(52), 26);
    expect(border.radiusFor(20), 10);
    const square = HomeNavBlockBorder(cornerRadius: 0, barHeight: 64);
    expect(square.radiusFor(52), 0);
  });
}

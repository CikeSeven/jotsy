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

/// 圆角块 + 图标 20：与测试里按 20 图标推算的尺寸对应。栏高固定 60，
/// 与默认一致；内边距取默认的 3。
const _glassBlock = HomeBarStyle(
  indicator: HomeBarIndicator.block,
  iconSize: 20,
  labelGap: 2,
  barHeight: 60,
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
    // 上沿最多比未放大时高 (1.12 − 1) × 20 / 2 = 1.2。内边距 3。
    expect(block.top, lessThanOrEqualTo(icon.top - 3 + 1.2 + 0.01));
    expect(block.bottom, greaterThanOrEqualTo(label.bottom + 2.5));
    expect(block.top, greaterThanOrEqualTo(bar.top));
    expect(block.bottom, lessThanOrEqualTo(bar.bottom));
    // 块与内容同心，内容在栏里竖直居中。
    expect(block.center.dy, closeTo(bar.center.dy, 0.01));
    expect(block.center.dx, closeTo(icon.center.dx, 0.01));

    // 圆角与栏同心：栏圆角 30 减去块到栏上下边缘的距离。
    final ink = tester.widget<Ink>(
      find.descendant(of: _destination(0), matching: find.byType(Ink)),
    );
    final shape = (ink.decoration! as ShapeDecoration).shape;
    expect(shape, isA<HomeNavBlockBorder>());
    final radius = (shape as HomeNavBlockBorder).radiusFor(block.height);
    expect(
      radius,
      closeTo((30 - (64 - block.height) / 2).clamp(0, block.height / 2), 0.001),
    );
  });

  testWidgets('block width hugs the content with the padding', (tester) async {
    // 宽格子（每格 200）：块宽 = 内容宽 + 2 × 内边距，不再按格宽铺开。
    await _pump(
      tester,
      _glassBlock.copyWith(labelMode: HomeBarLabelMode.never),
      width: 800,
    );
    final iconOnly = _block(tester, 0);
    // 只有图标时也不窄于最小宽度，仍是一颗像样的胶囊；测试字体下图标框
    // 24 宽，加内边距 6 是 30，被最小宽度 32 托住。
    expect(iconOnly.width, closeTo(32, 0.01));

    // 长文字让块按文字宽加内边距加宽。
    await _pump(tester, _glassBlock.copyWith(blockPadding: 12), width: 800);
    final label = _label(tester, 0);
    expect(
      _block(tester, 0).width,
      closeTo((label.width + 24).clamp(32, 200 - 4), 0.01),
    );

    // 窄格子（每格 100）：块宽封顶为格宽 − 4。
    await _pump(tester, _glassBlock.copyWith(blockPadding: 12));
    expect(_block(tester, 0).width, lessThanOrEqualTo(100 - 4 + 0.01));
  });

  testWidgets('padding keeps equal gaps inside the block and to the bar', (
    tester,
  ) async {
    // 块与栏同心：上下留白相等，不会一头贴着栏边、一头空着。
    await _pump(tester, _glassBlock);
    final bar = tester.getRect(find.byType(HomeNavBar));
    final block = _block(tester, 0);
    expect(block.top - bar.top, closeTo(bar.bottom - block.bottom, 0.01));
    // 块高 = 内容高 + 2 × 内边距（内边距 3）：图标框 24 + 间距 + 文字。
    expect(block.height - _icon(tester, 0).height, greaterThan(2 * 3 + 2 + 10));
    // 栏高 64 默认下块仍与栏边留出距离（不被栏高顶满）。
    expect(block.top - bar.top, greaterThan(1));

    // 内边距越大块越高，但永远不贴住栏边（至少留 2）。
    await _pump(tester, _glassBlock.copyWith(blockPadding: 12));
    final tall = _block(tester, 0);
    expect(tall.height, greaterThan(block.height));
    expect(tall.top, greaterThanOrEqualTo(bar.top + 2 - 0.01));
    expect(tall.bottom, lessThanOrEqualTo(bar.bottom - 2 + 0.01));
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
    // 图标框 = 图标 20 + 放大余量 4，上下各加默认内边距 3。
    expect(block.height, closeTo(20 + 4 + 6, 0.01));
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
    const border = HomeNavBlockBorder(cornerRadius: 32, barHeight: 60);
    expect(border.radiusFor(52), 26);
    expect(border.radiusFor(20), 10);
    const square = HomeNavBlockBorder(cornerRadius: 0, barHeight: 64);
    expect(square.radiusFor(52), 0);
  });
}

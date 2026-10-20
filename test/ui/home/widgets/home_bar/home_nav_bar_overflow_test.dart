import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_resolved_style.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_bar.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_destination.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_indicator.dart';

import '../../../../support/expressive_test_theme.dart';

// 测试字体下英文按方块排版，比真实字体宽得多：这里的长名称在 320dp 上
// 必然放不下，正好检验省略与不溢出。
const _items = <BottomNavItem>[
  BottomNavItem(label: 'Diaries and notes', icon: FontAwesomeIcons.book),
  BottomNavItem(label: 'Calendar', icon: FontAwesomeIcons.calendarDays),
  BottomNavItem(label: 'Explore everything', icon: FontAwesomeIcons.compass),
  BottomNavItem(label: 'Settings', icon: FontAwesomeIcons.gear),
];

// 默认间距与内边距，以及两者都取最大值：栏太矮时先收窄间距与内边距，
// 文字与圆角块都不越出栏。
const _spacings = <(double, double)>[(4, 6), (12, 16)];

void main() {
  for (final textScale in <double>[1.0, 1.3, 2.0]) {
    for (final height in <double>[56, 80]) {
      testWidgets(
        'every label mode and indicator fits 320dp at text scale $textScale '
        'and height $height',
        (tester) async {
          final theme = expressiveTestTheme(Brightness.light);
          for (final (labelGap, blockPadding) in _spacings) {
            for (final labelMode in HomeBarLabelMode.values) {
              for (final indicator in HomeBarIndicator.values) {
                final style = HomeBarResolvedStyle.resolve(
                  HomeBarStyle(
                    iconSize: 28,
                    labelMode: labelMode,
                    indicator: indicator,
                    labelGap: labelGap,
                    blockPadding: blockPadding,
                  ),
                  theme.colorScheme,
                );
                await tester.pumpWidget(
                  MaterialApp(
                    theme: theme,
                    builder: (BuildContext context, Widget? child) =>
                        MediaQuery(
                          data: MediaQuery.of(
                            context,
                          ).copyWith(textScaler: TextScaler.linear(textScale)),
                          child: child!,
                        ),
                    home: Scaffold(
                      body: Align(
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(
                          width: 320,
                          child: HomeNavBar(
                            items: _items,
                            selectedIndex: 2,
                            onTap: (_) {},
                            style: style,
                            height: height,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                final reason =
                    '$labelMode / $indicator / gap $labelGap / '
                    'padding $blockPadding';
                expect(tester.takeException(), isNull, reason: reason);
                // 文字不超出自己的格子（单行省略）。
                for (var i = 0; i < _items.length; i++) {
                  final cell = tester.getRect(
                    find.byType(HomeNavDestination).at(i),
                  );
                  final paragraph = tester.renderObject<RenderParagraph>(
                    find.text(_items[i].label),
                  );
                  expect(
                    paragraph.size.width,
                    lessThanOrEqualTo(cell.width),
                    reason: reason,
                  );
                  // 显示着的文字竖直方向也不越出栏：间距先收窄到 0。图标框
                  // （图标 28 + 余量 4 = 32）加大字体的文字本身就比 56 高时，
                  // 只允许这部分无法避免的超出（上下各一半）。
                  if (labelMode == HomeBarLabelMode.always ||
                      (labelMode == HomeBarLabelMode.selected && i == 2)) {
                    final label = tester.getRect(find.text(_items[i].label));
                    final excess =
                        math.max(0.0, 32 + label.height - cell.height) / 2;
                    expect(
                      label.bottom,
                      lessThanOrEqualTo(cell.bottom + excess + 0.01),
                      reason: reason,
                    );
                  }
                }
                // 圆角块留在栏里（至少离边缘 2）。
                if (indicator == HomeBarIndicator.block) {
                  final cell = tester.getRect(
                    find.byType(HomeNavDestination).at(2),
                  );
                  final block = tester.getRect(
                    find.descendant(
                      of: find.byType(HomeNavDestination).at(2),
                      matching: find.byType(HomeNavIndicator),
                    ),
                  );
                  expect(
                    block.top,
                    greaterThanOrEqualTo(cell.top + 2 - 0.01),
                    reason: reason,
                  );
                  expect(
                    block.bottom,
                    lessThanOrEqualTo(cell.bottom - 2 + 0.01),
                    reason: reason,
                  );
                }
              }
            }
          }
        },
      );
    }
  }
}

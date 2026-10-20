import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_resolved_style.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_bar.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_destination.dart';

import '../../../../support/expressive_test_theme.dart';

// 测试字体下英文按方块排版，比真实字体宽得多：这里的长名称在 320dp 上
// 必然放不下，正好检验省略与不溢出。
const _items = <BottomNavItem>[
  BottomNavItem(label: 'Diaries and notes', icon: FontAwesomeIcons.book),
  BottomNavItem(label: 'Calendar', icon: FontAwesomeIcons.calendarDays),
  BottomNavItem(label: 'Explore everything', icon: FontAwesomeIcons.compass),
  BottomNavItem(label: 'Settings', icon: FontAwesomeIcons.gear),
];

void main() {
  for (final textScale in <double>[1.0, 1.3, 2.0]) {
    for (final height in <double>[56, 80]) {
      testWidgets(
        'every label mode and indicator fits 320dp at text scale $textScale '
        'and height $height',
        (tester) async {
          final theme = expressiveTestTheme(Brightness.light);
          for (final labelMode in HomeBarLabelMode.values) {
            for (final indicator in HomeBarIndicator.values) {
              final style = HomeBarResolvedStyle.resolve(
                HomeBarStyle(
                  iconSize: 28,
                  labelMode: labelMode,
                  indicator: indicator,
                ),
                theme.colorScheme,
              );
              await tester.pumpWidget(
                MaterialApp(
                  theme: theme,
                  builder: (BuildContext context, Widget? child) => MediaQuery(
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
              final reason = '$labelMode / $indicator';
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
              }
            }
          }
        },
      );
    }
  }
}

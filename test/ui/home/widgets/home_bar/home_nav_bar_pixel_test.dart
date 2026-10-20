import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/ui/widgets/bottom_nav.dart';

import '../../../../support/expressive_test_theme.dart';

/// 改版前基于 Material `NavigationBar` 的 BottomNav 构建代码，原样冻结在这里
/// 作为像素基线：默认样式下新的 HomeNavBar 渲染必须与它逐字节相同。
class _ReferenceBottomNav extends StatelessWidget {
  const _ReferenceBottomNav({required this.items, required this.selectedIndex});

  final List<BottomNavItem> items;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = colorScheme.brightness == Brightness.light;
    final navBackgroundColor =
        theme.navigationBarTheme.backgroundColor ??
        colorScheme.surfaceContainer;
    final maxIndex = items.length - 1;
    final clampedIndex = selectedIndex < 0
        ? 0
        : (selectedIndex > maxIndex ? maxIndex : selectedIndex);

    return Container(
      decoration: BoxDecoration(
        color: navBackgroundColor,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(
              alpha: isLight ? 0.35 : 0.15,
            ),
            width: 0.6,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: NavigationBar(
          animationDuration: ExpressiveMotion.duration(context),
          height: 80,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: clampedIndex,
          onDestinationSelected: (_) {},
          indicatorColor: colorScheme.secondaryContainer,
          backgroundColor: Colors.transparent,
          destinations: [
            for (var index = 0; index < items.length; index++)
              NavigationDestination(
                icon: AnimatedScale(
                  scale: clampedIndex == index ? 1.12 : 1,
                  duration: ExpressiveMotion.duration(context),
                  curve: ExpressiveMotion.spatial,
                  child: FaIcon(
                    items[index].icon,
                    size: 20,
                    color: clampedIndex == index
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                label: items[index].label,
              ),
          ],
        ),
      ),
    );
  }
}

const _items = <BottomNavItem>[
  BottomNavItem(label: '日记', icon: FontAwesomeIcons.book),
  BottomNavItem(label: '日历', icon: FontAwesomeIcons.calendarDays),
  BottomNavItem(label: 'Explore', icon: FontAwesomeIcons.compass),
  BottomNavItem(label: '设置', icon: FontAwesomeIcons.gear),
];

const _boundaryKey = ValueKey<String>('nav-boundary');
const _bottomInset = 24.0;

Future<Uint8List> _render(
  WidgetTester tester, {
  required Brightness brightness,
  required Widget nav,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(brightness),
      home: Align(
        alignment: Alignment.bottomCenter,
        child: RepaintBoundary(key: _boundaryKey, child: nav),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundaryKey),
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

void main() {
  setUpAll(() async {
    final fonts = <String, List<String>>{
      'HarmonyOSSansSC': <String>[
        'assets/fonts/harmonyos_sans_sc/HarmonyOS_Sans_SC_Regular.ttf',
        'assets/fonts/harmonyos_sans_sc/HarmonyOS_Sans_SC_Medium.ttf',
        'assets/fonts/harmonyos_sans_sc/HarmonyOS_Sans_SC_Bold.ttf',
      ],
      'packages/font_awesome_flutter/FontAwesomeSolid': <String>[
        'packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Solid-900.otf',
      ],
      'packages/font_awesome_flutter/FontAwesomeRegular': <String>[
        'packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Regular-400.otf',
      ],
    };
    for (final font in fonts.entries) {
      final loader = FontLoader(font.key);
      for (final asset in font.value) {
        loader.addFont(rootBundle.load(asset));
      }
      await loader.load();
    }
  });

  for (final width in <double>[400, 320]) {
    for (final brightness in Brightness.values) {
      for (final selected in <int>[0, 2]) {
        testWidgets(
          'default BottomNav matches the NavigationBar baseline at ${width}dp, '
          '$brightness, selected $selected',
          (tester) async {
            tester.view
              ..devicePixelRatio = 1
              ..physicalSize = Size(width, 80 + _bottomInset + 200)
              ..padding = const FakeViewPadding(bottom: _bottomInset);
            addTearDown(tester.view.reset);

            final reference = await _render(
              tester,
              brightness: brightness,
              nav: _ReferenceBottomNav(items: _items, selectedIndex: selected),
            );
            final actual = await _render(
              tester,
              brightness: brightness,
              nav: BottomNav(
                items: _items,
                selectedIndex: selected,
                onTap: (_) {},
              ),
            );
            expect(actual.length, reference.length);
            var differing = 0;
            for (var i = 0; i < reference.length; i++) {
              if (reference[i] != actual[i]) differing++;
            }
            expect(differing, 0, reason: '$differing bytes differ');
          },
        );
      }
    }
  }
}

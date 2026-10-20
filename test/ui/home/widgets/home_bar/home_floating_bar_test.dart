import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_resolved_style.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_floating_bar.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_nav_bar.dart';
import 'package:node_diary/ui/widgets/glass/glass_surface.dart';

import '../../../../support/expressive_test_theme.dart';

const _items = <BottomNavItem>[
  BottomNavItem(label: 'Diaries', icon: FontAwesomeIcons.book),
  BottomNavItem(label: 'Calendar', icon: FontAwesomeIcons.calendarDays),
  BottomNavItem(label: 'Settings', icon: FontAwesomeIcons.gear),
];

const double _width = 360;

HomeBarResolvedStyle _style({
  double barHeight = 64,
  double cornerRadius = 32,
  bool shadow = true,
  bool highContrast = false,
}) => HomeBarResolvedStyle.resolve(
  HomeBarStyle(
    material: HomeBarMaterial.glass,
    barHeight: barHeight,
    cornerRadius: cornerRadius,
    shadow: shadow,
  ),
  expressiveTestTheme(Brightness.light).colorScheme,
  highContrast: highContrast,
);

Widget _button(HomeBarResolvedStyle style, {VoidCallback? onPressed}) =>
    HomeInlineCreateButton(
      style: style,
      label: 'New',
      onPressed: onPressed ?? () {},
    );

Future<void> _pump(
  WidgetTester tester, {
  required HomeBarResolvedStyle style,
  bool showInline = false,
  bool withInline = true,
  double progress = 1,
  VoidCallback? onPressed,
}) => tester.pumpWidget(
  MaterialApp(
    theme: expressiveTestTheme(Brightness.light),
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomLeft,
        child: SizedBox(
          width: _width,
          child: HomeFloatingBar(
            items: _items,
            selectedIndex: 0,
            onTap: (_) {},
            style: style,
            progress: progress,
            inlineAction: withInline
                ? _button(style, onPressed: onPressed)
                : null,
            showInlineAction: showInline,
          ),
        ),
      ),
    ),
  ),
);

Finder get _pill => find.byType(GlassSurface);

Finder get _buttonFinder => find.byType(HomeInlineCreateButton);

void main() {
  testWidgets('the pill is a glass surface as tall as the bar', (tester) async {
    final style = _style();
    await _pump(tester, style: style, withInline: false);
    expect(tester.getSize(_pill), const Size(_width, 64));
    final surface = tester.widget<GlassSurface>(_pill);
    expect(surface.fill, style.fill);
    expect(surface.blur, isTrue);
    expect(surface.border?.color, style.borderColor);
    expect(surface.shadowColor, style.shadowColor);
    final backdrop = tester.widget<BackdropFilter>(
      find.descendant(of: _pill, matching: find.byType(BackdropFilter)),
    );
    expect(backdrop.enabled, isTrue);
    // 导航项一行左右各留 4。
    final pill = tester.getRect(_pill);
    expect(
      tester.getRect(find.byType(HomeNavBar)),
      Rect.fromLTRB(pill.left + 4, pill.top, pill.right - 4, pill.bottom),
    );
  });

  testWidgets('progress drives the glass instead of an opacity layer', (
    tester,
  ) async {
    await _pump(tester, style: _style(), withInline: false, progress: 0.4);
    expect(tester.widget<GlassSurface>(_pill).progress, 0.4);
    expect(
      find.ancestor(of: _pill, matching: find.byType(Opacity)),
      findsNothing,
    );
  });

  testWidgets('a shown inline button takes bar height plus an 8dp gap', (
    tester,
  ) async {
    await _pump(tester, style: _style(), showInline: true);
    expect(tester.getSize(_buttonFinder), const Size(64, 64));
    expect(tester.getSize(_pill).width, _width - 64 - 8);
    expect(tester.getRect(_buttonFinder).right, _width);
    expect(tester.getRect(_buttonFinder).left - tester.getRect(_pill).right, 8);
  });

  testWidgets('hiding the button animates the pill back to full width', (
    tester,
  ) async {
    final style = _style();
    await _pump(tester, style: style, showInline: true);
    await _pump(tester, style: style);
    await tester.pump(const Duration(milliseconds: 60));
    final mid = tester.getSize(_pill).width;
    expect(mid, inExclusiveRange(_width - 72, _width));
    await tester.pumpAndSettle();
    expect(tester.getSize(_pill).width, _width);
    // 隐藏后的按钮不可点、不进语义树。
    final semantics = tester.ensureSemantics();
    expect(find.semantics.byLabel('New'), findsNothing);
    semantics.dispose();
    expect(
      tester
          .widgetList<IgnorePointer>(
            find.ancestor(
              of: _buttonFinder,
              matching: find.byType(IgnorePointer),
            ),
          )
          .any((widget) => widget.ignoring),
      isTrue,
    );

    await _pump(tester, style: style, showInline: true);
    await tester.pumpAndSettle();
    expect(tester.getSize(_pill).width, _width - 72);
  });

  testWidgets('reduce motion swaps the inline button without animating', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final style = _style();
    await _pump(tester, style: style);
    await _pump(tester, style: style, showInline: true);
    await tester.pump();
    expect(tester.getSize(_pill).width, _width - 72);
  });

  testWidgets('the button radius never exceeds half its side', (tester) async {
    final style = _style(barHeight: 56, cornerRadius: 40);
    await _pump(tester, style: style, showInline: true);
    expect(tester.getSize(_buttonFinder), const Size(56, 56));
    final material = tester.widget<Material>(
      find.descendant(of: _buttonFinder, matching: find.byType(Material)),
    );
    final shape = material.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(28));
    final scheme = expressiveTestTheme(Brightness.light).colorScheme;
    expect(material.color, scheme.primaryContainer);
    final icon = tester.widget<FaIcon>(
      find.descendant(of: _buttonFinder, matching: find.byType(FaIcon)),
    );
    expect(icon.color, scheme.onPrimaryContainer);
    expect(icon.size, 20);
  });

  testWidgets('the button is a labelled button that reports taps', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await _pump(
      tester,
      style: _style(),
      showInline: true,
      onPressed: () => taps++,
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('New')),
      isSemantics(label: 'New', isButton: true, hasTapAction: true),
    );
    expect(find.semantics.byLabel('New'), findsOneWidget);
    await tester.tap(_buttonFinder);
    expect(taps, 1);
    expect(find.byTooltip('New'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the button shadow follows the style switch', (tester) async {
    Finder paint() => find
        .descendant(of: _buttonFinder, matching: find.byType(CustomPaint))
        .first;
    await _pump(tester, style: _style(), showInline: true);
    expect(tester.widget<CustomPaint>(paint()).painter, isNotNull);
    await _pump(tester, style: _style(shadow: false), showInline: true);
    expect(tester.widget<CustomPaint>(paint()).painter, isNull);
  });

  testWidgets('high contrast keeps the pill but turns the blur off', (
    tester,
  ) async {
    await _pump(tester, style: _style(highContrast: true), withInline: false);
    final backdrop = tester.widget<BackdropFilter>(
      find.descendant(of: _pill, matching: find.byType(BackdropFilter)),
    );
    expect(backdrop.enabled, isFalse);
    expect(tester.getSize(_pill), const Size(_width, 64));
  });
}

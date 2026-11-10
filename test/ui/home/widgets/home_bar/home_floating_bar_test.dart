import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_metrics.dart';
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
  HomeBarLabelMode labelMode = HomeBarLabelMode.always,
  bool highContrast = false,
}) => HomeBarResolvedStyle.resolve(
  HomeBarStyle(labelMode: labelMode),
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
  double width = _width,
  List<BottomNavItem> items = _items,
  VoidCallback? onPressed,
}) => tester.pumpWidget(
  MaterialApp(
    theme: expressiveTestTheme(Brightness.light),
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomLeft,
        child: SizedBox(
          width: width,
          child: HomeFloatingBar(
            items: items,
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

/// 三项、每项 72 宽、两侧各 4 的缝。
const double _pillWidth = 3 * 72 + 12;

void main() {
  testWidgets('the pill hugs its items and sits in the middle', (tester) async {
    final style = _style();
    await _pump(tester, style: style, withInline: false);
    expect(
      tester.getSize(find.byType(HomeFloatingBar)),
      const Size(_width, 60),
    );
    final pill = tester.getRect(_pill);
    expect(pill.size, const Size(_pillWidth, 60));
    expect(pill.center.dx, _width / 2);
    // 导航行四周到胶囊内壁都是同样的缝：指示器与胶囊同心。
    expect(
      tester.getRect(find.byType(HomeNavBar)),
      pill.deflate(HomeBarMetrics.inset),
    );

    // 项越少胶囊越短。
    await _pump(
      tester,
      style: style,
      withInline: false,
      items: _items.sublist(0, 2),
    );
    expect(tester.getSize(_pill).width, 2 * 72 + 12);
  });

  testWidgets('the pill is a glass capsule with an outline and a shadow', (
    tester,
  ) async {
    final style = _style();
    await _pump(tester, style: style, withInline: false);
    final surface = tester.widget<GlassSurface>(_pill);
    expect(surface.borderRadius, BorderRadius.circular(30));
    expect(surface.fill, style.fill);
    expect(surface.blur, isTrue);
    expect(surface.blurSigma, style.blurSigma);
    expect(surface.saturation, HomeBarMetrics.saturation);
    expect(surface.border?.color, style.borderColor);
    expect(surface.border?.width, HomeBarMetrics.borderWidth);
    expect(surface.shadowColor, style.shadowColor);
    final backdrop = tester.widget<BackdropFilter>(
      find.descendant(of: _pill, matching: find.byType(BackdropFilter)),
    );
    expect(backdrop.enabled, isTrue);
    // 描边画在 Material 的形状里、居内：不会被外层的圆角裁切切掉。
    final shape =
        tester
                .widget<Material>(
                  find
                      .descendant(of: _pill, matching: find.byType(Material))
                      .first,
                )
                .shape!
            as RoundedRectangleBorder;
    expect(shape.side.strokeAlign, BorderSide.strokeAlignInside);
  });

  testWidgets('an icon-only bar is shorter', (tester) async {
    await _pump(
      tester,
      style: _style(labelMode: HomeBarLabelMode.never),
      withInline: false,
    );
    expect(tester.getSize(_pill), const Size(3 * 64 + 12, 54));
    expect(
      tester.widget<GlassSurface>(_pill).borderRadius,
      BorderRadius.circular(27),
    );
  });

  testWidgets('items narrow evenly when the bar does not fit', (tester) async {
    await _pump(tester, style: _style(), withInline: false, width: 200);
    expect(tester.getSize(_pill).width, 200);
    expect(tester.getSize(find.byType(HomeNavBar)).width, 188);
    expect(tester.takeException(), isNull);
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

  testWidgets('a shown inline button joins the pill as one centred group', (
    tester,
  ) async {
    await _pump(tester, style: _style(), showInline: true);
    final pill = tester.getRect(_pill);
    final button = tester.getRect(_buttonFinder);
    expect(button.size, const Size(60, 60));
    expect(pill.width, _pillWidth);
    expect(button.left - pill.right, HomeBarMetrics.inlineGap);
    // 胶囊 + 间距 + 按钮作为一组居中。
    expect((pill.left + button.right) / 2, closeTo(_width / 2, 0.01));
  });

  testWidgets('hiding the button springs the pill back to the middle', (
    tester,
  ) async {
    final style = _style();
    await _pump(tester, style: style, showInline: true);
    final shifted = tester.getRect(_pill).center.dx;
    expect(shifted, lessThan(_width / 2));

    await _pump(tester, style: style);
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      tester.getRect(_pill).center.dx,
      inExclusiveRange(shifted, _width / 2),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(_pill).center.dx, closeTo(_width / 2, 0.01));
    expect(tester.getSize(_pill).width, _pillWidth);
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
    expect(tester.getRect(_pill).center.dx, closeTo(shifted, 0.01));
  });

  testWidgets('on a narrow screen the pill gives way as the button grows', (
    tester,
  ) async {
    // 240 宽放得下三项（228），加上按钮（68）就放不下：项宽随槽位收窄。
    final style = _style();
    await _pump(tester, style: style, width: 240);
    expect(tester.getSize(_pill).width, _pillWidth);

    await _pump(tester, style: style, width: 240, showInline: true);
    var last = _pillWidth;
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final width = tester.getSize(_pill).width;
      // 逐帧让出，不在第一帧跳到最终宽度。
      expect(width, lessThanOrEqualTo(last + 0.01));
      last = width;
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
    expect(tester.getSize(_pill).width, closeTo(240 - 68, 0.01));
    expect(tester.getRect(_buttonFinder).right, closeTo(240, 0.01));
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
    expect(
      tester.getRect(_buttonFinder).left - tester.getRect(_pill).right,
      HomeBarMetrics.inlineGap,
    );
    expect(tester.getSize(_buttonFinder), const Size(60, 60));
  });

  testWidgets('the button is a circle as tall as the bar', (tester) async {
    final style = _style(labelMode: HomeBarLabelMode.never);
    await _pump(tester, style: style, showInline: true);
    expect(tester.getSize(_buttonFinder), const Size(54, 54));
    final material = tester.widget<Material>(
      find.descendant(of: _buttonFinder, matching: find.byType(Material)),
    );
    final shape = material.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(27));
    final scheme = expressiveTestTheme(Brightness.light).colorScheme;
    expect(material.color, scheme.primaryContainer);
    final icon = tester.widget<FaIcon>(
      find.descendant(of: _buttonFinder, matching: find.byType(FaIcon)),
    );
    expect(icon.color, scheme.onPrimaryContainer);
    expect(icon.size, 20);
    // 投影与胶囊同源。
    final paint = tester.widget<CustomPaint>(
      find
          .descendant(of: _buttonFinder, matching: find.byType(CustomPaint))
          .first,
    );
    expect(paint.painter, isNotNull);
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

  testWidgets('high contrast keeps the pill but turns the blur off', (
    tester,
  ) async {
    await _pump(tester, style: _style(highContrast: true), withInline: false);
    final backdrop = tester.widget<BackdropFilter>(
      find.descendant(of: _pill, matching: find.byType(BackdropFilter)),
    );
    expect(backdrop.enabled, isFalse);
    expect(tester.getSize(_pill), const Size(_pillWidth, 60));
  });
}

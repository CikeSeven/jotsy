import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu_geometry.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu_layout.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu_panel.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu_selection.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_submenu.dart';

import '../../support/expressive_test_theme.dart';

const _tooltip = 'More actions';

List<Widget> _items({
  VoidCallback? onEdit,
  VoidCallback? onDelete,
  String editLabel = 'Edit',
}) => <Widget>[
  ExpressiveMenuItem(
    leadingIcon: const FaIcon(FontAwesomeIcons.penToSquare),
    onPressed: onEdit ?? () {},
    child: Text(editLabel),
  ),
  ExpressiveMenuItem(
    leadingIcon: const FaIcon(FontAwesomeIcons.trashCan),
    destructive: true,
    onPressed: onDelete ?? () {},
    child: const Text('Delete'),
  ),
];

Widget _app({
  required Widget home,
  TextDirection textDirection = TextDirection.ltr,
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  theme: expressiveTestTheme(brightness),
  builder: (BuildContext context, Widget? child) =>
      Directionality(textDirection: textDirection, child: child!),
  home: home,
);

Widget _menuButton({
  required List<Widget> items,
  ExpressiveMenuPlacement placement = ExpressiveMenuPlacement.end,
}) => ExpressiveMenuButton(
  tooltip: _tooltip,
  icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 18),
  placement: placement,
  items: items,
);

/// 顶栏右侧的 ⋮ 菜单，正文铺满一个计数按钮，用来检查点外部是否穿透。
Widget _topBarPage({List<Widget>? items, VoidCallback? onBodyTap}) => Scaffold(
  appBar: AppBar(
    title: const Text('Page'),
    actionsPadding: const EdgeInsetsDirectional.only(end: 16),
    actions: <Widget>[_menuButton(items: items ?? _items())],
  ),
  body: SizedBox.expand(
    child: TextButton(onPressed: onBodyTap, child: const Text('Body')),
  ),
);

/// 放在任意位置的菜单按钮。
Widget _alignedPage(
  Alignment alignment, {
  List<Widget>? items,
  ExpressiveMenuPlacement placement = ExpressiveMenuPlacement.end,
  EdgeInsets padding = EdgeInsets.zero,
}) => Scaffold(
  body: Padding(
    padding: padding,
    child: Align(
      alignment: alignment,
      child: _menuButton(items: items ?? _items(), placement: placement),
    ),
  ),
);

Finder get _trigger => find.byTooltip(_tooltip);

/// 图标按钮那个 40 的圆（面板从它长出来、贴着它的角对齐）。
Rect _circle(WidgetTester tester) =>
    Rect.fromCenter(center: tester.getCenter(_trigger), width: 40, height: 40);

Finder _faIcon(FaIconData icon) => find.byWidgetPredicate(
  (Widget widget) =>
      widget is FaIcon && widget.icon?.codePoint == icon.codePoint,
);

Finder get _panels => find.byType(ExpressiveMenuPanel);
Finder get _primary => _panels.first;
Finder get _items0 => find.byType(ExpressiveMenuItem);

RenderExpressiveMenuCascade _cascade(WidgetTester tester) =>
    tester.renderObject<RenderExpressiveMenuCascade>(
      find.byType(ExpressiveMenuCascade),
    );

ExpressiveMenuSelection _selection(WidgetTester tester, Finder panel) {
  final paint = tester.widget<CustomPaint>(
    find
        .descendant(
          of: panel,
          matching: find.byWidgetPredicate(
            (Widget w) =>
                w is CustomPaint && w.painter is ExpressiveMenuMaskPainter,
          ),
        )
        .first,
  );
  return (paint.painter! as ExpressiveMenuMaskPainter).selection;
}

Matcher _near(double value, {double epsilon = 0.01}) =>
    moreOrLessEquals(value, epsilon: epsilon);

Matcher _nearOffset(Offset value) =>
    offsetMoreOrLessEquals(value, epsilon: 0.01);

Color _textColor(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text)).text.style!.color!;

double _opacityAbove(WidgetTester tester, Finder trigger) => tester
    .widget<FadeTransition>(
      find.ancestor(of: trigger, matching: find.byType(FadeTransition)).first,
    )
    .opacity
    .value;

void main() {
  void useSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(_trigger);
    await tester.pumpAndSettle();
  }

  group('placement', () {
    testWidgets('covers the button, top-right corner on its circle', (
      tester,
    ) async {
      useSize(tester, const Size(393, 800));
      await tester.pumpWidget(_app(home: _topBarPage()));
      final circle = _circle(tester);
      await openMenu(tester);

      final panel = tester.getRect(_primary);
      expect(panel.topRight, _nearOffset(circle.topRight));
      expect(panel.width, inInclusiveRange(200, 288));
      final placed = _cascade(tester).primaryPlacement!;
      expect(placed.side, ExpressiveMenuSide.below);
      expect(placed.alignRight, isTrue);
      expect(placed.seed, circle);
    });

    testWidgets('aligns the top-left corner in right-to-left text', (
      tester,
    ) async {
      useSize(tester, const Size(393, 800));
      await tester.pumpWidget(
        _app(home: _topBarPage(), textDirection: TextDirection.rtl),
      );
      final circle = _circle(tester);
      await openMenu(tester);
      expect(tester.getRect(_primary).topLeft, _nearOffset(circle.topLeft));
    });

    testWidgets('a start-aligned menu starts at the circle start corner', (
      tester,
    ) async {
      useSize(tester, const Size(393, 800));
      await tester.pumpWidget(
        _app(
          home: _alignedPage(
            const Alignment(-0.5, -0.5),
            placement: ExpressiveMenuPlacement.start,
          ),
        ),
      );
      final circle = _circle(tester);
      await openMenu(tester);
      expect(tester.getRect(_primary).topLeft, _nearOffset(circle.topLeft));
    });

    testWidgets('grows upward from the bottom corner near the bottom edge', (
      tester,
    ) async {
      useSize(tester, const Size(393, 800));
      await tester.pumpWidget(
        _app(
          home: _alignedPage(
            Alignment.bottomRight,
            padding: const EdgeInsets.all(16),
          ),
        ),
      );
      final circle = _circle(tester);
      await openMenu(tester);
      expect(
        tester.getRect(_primary).bottomRight,
        _nearOffset(circle.bottomRight),
      );
      expect(_cascade(tester).primaryPlacement!.side, ExpressiveMenuSide.above);
    });

    testWidgets('stays inside a 320dp screen with long labels', (tester) async {
      useSize(tester, const Size(320, 640));
      for (final placement in ExpressiveMenuPlacement.values) {
        for (final alignment in <Alignment>[
          Alignment.topLeft,
          Alignment.topRight,
          Alignment.bottomLeft,
          Alignment.bottomRight,
        ]) {
          await tester.pumpWidget(
            _app(
              home: _alignedPage(
                alignment,
                placement: placement,
                items: _items(editLabel: 'A very long menu label ' * 4),
              ),
            ),
          );
          await openMenu(tester);
          final panel = tester.getRect(_primary);
          expect(panel.left, greaterThanOrEqualTo(8), reason: '$alignment');
          expect(panel.right, lessThanOrEqualTo(312), reason: '$alignment');
          expect(panel.top, greaterThanOrEqualTo(0), reason: '$alignment');
          expect(panel.bottom, lessThanOrEqualTo(640), reason: '$alignment');
          expect(panel.width, lessThanOrEqualTo(288));
          expect(tester.takeException(), isNull);
          await tester.tapAt(const Offset(160, 320));
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('a large anchor gets the menu beside it, grown from a dot', (
      tester,
    ) async {
      useSize(tester, const Size(393, 800));
      await tester.pumpWidget(
        _app(
          home: Scaffold(
            body: Align(
              alignment: const Alignment(0, -0.6),
              child: ExpressiveMenuAnchor(
                placement: ExpressiveMenuPlacement.start,
                menuChildren: _items(),
                builder: (context, menu, child) => GestureDetector(
                  onTap: menu.toggle,
                  child: const SizedBox(
                    width: 300,
                    height: 120,
                    child: Text('Card'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final card = tester.getRect(
        find.ancestor(of: find.text('Card'), matching: find.byType(SizedBox)),
      );
      await tester.tap(find.text('Card'));
      await tester.pumpAndSettle();
      final panel = tester.getRect(_primary);
      expect(panel.left, _near(card.left));
      expect(panel.top, _near(card.bottom + 8));
      final seed = _cascade(tester).primaryPlacement!.seed;
      expect(seed.size, const Size(28, 28));
      expect(seed.topLeft, _nearOffset(panel.topLeft));
      // 卡片不会随菜单淡出。
      expect(_opacityAbove(tester, find.text('Card')), 1);
    });

    test('a menu taller than both sides is centred on the seed', () {
      final placed = placeCoveringMenu(
        seed: const Rect.fromLTWH(100, 290, 40, 40),
        size: const Size(200, 500),
        bounds: const Rect.fromLTWH(0, 0, 400, 600),
        placement: ExpressiveMenuPlacement.start,
        textDirection: TextDirection.ltr,
      );
      expect(placed.side, ExpressiveMenuSide.middle);
      expect(placed.rect.center.dy, _near(310));
    });

    test('the morph rect starts on the seed and ends on the panel', () {
      const size = Size(220, 180);
      const seed = Rect.fromLTWH(180, 0, 40, 40);
      Rect at(double f, double p) => expressiveMenuMorphRect(
        size: size,
        seed: seed,
        fraction: f,
        origin: p,
        side: ExpressiveMenuSide.below,
        alignRight: true,
      );
      expect(at(0, 0), seed);
      expect(at(1, 1), Offset.zero & size);
      // 只迁移、不长大：中心移到面板中心。
      expect(at(0, 1).center, _nearOffset(size.center(Offset.zero)));
      // 只长大、不迁移：右上角钉在起点的右上角。
      expect(at(0.5, 0).topRight, _nearOffset(seed.topRight));
    });
  });

  group('motion', () {
    testWidgets('the button grows into the panel, its icon fading out', (
      tester,
    ) async {
      useSize(tester, const Size(393, 800));
      await tester.pumpWidget(_app(home: _topBarPage()));
      final circle = _circle(tester);
      await tester.tap(_trigger);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final early = tester.getRect(_primary);
      final earlyIcon = _opacityAbove(tester, _trigger);
      await tester.pump(const Duration(milliseconds: 60));
      final midway = tester.getRect(_primary);
      await tester.pumpAndSettle();
      final settled = tester.getRect(_primary);

      // 内容按“此刻宽 / 面板宽”等比缩放：一开始只比那个圆大一点。
      expect(early.width, lessThan(settled.width * 0.5));
      expect(midway.width, inExclusiveRange(early.width, settled.width));
      expect((early.center - circle.center).distance, lessThan(60));
      expect(earlyIcon, inExclusiveRange(0, 1));
      expect(_opacityAbove(tester, _trigger), 0);
    });

    testWidgets('the size spring overshoots a little before settling', (
      tester,
    ) async {
      useSize(tester, const Size(393, 800));
      await tester.pumpWidget(_app(home: _topBarPage()));
      await tester.tap(_trigger);
      await tester.pump();
      var widest = 0.0;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final width = tester.getRect(_primary).width;
        if (width > widest) widest = width;
      }
      await tester.pumpAndSettle();
      final settled = tester.getRect(_primary).width;
      expect(widest, greaterThan(settled + 1));
      expect(widest, lessThan(settled * 1.04));
    });

    testWidgets('closing shrinks back into the button within 340ms', (
      tester,
    ) async {
      await tester.pumpWidget(_app(home: _topBarPage()));
      await openMenu(tester);
      await tester.tapAt(const Offset(40, 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_items0, findsNWidgets(2));
      // 收起途中不再响应条目，按钮的图标提早淡回来。
      expect(
        tester
            .state<ExpressiveMenuAnchorState>(find.byType(ExpressiveMenuAnchor))
            .interactive,
        isFalse,
      );
      expect(_opacityAbove(tester, _trigger), greaterThan(0.5));
      await tester.pump(const Duration(milliseconds: 160));
      await tester.pump();
      expect(_items0, findsNothing);
      expect(_opacityAbove(tester, _trigger), 1);
    });

    testWidgets('the glass panel blurs what is behind it', (tester) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          _app(home: _topBarPage(), brightness: brightness),
        );
        await openMenu(tester);
        final blur = tester.widget<BackdropFilter>(
          find.byType(BackdropFilter).first,
        );
        expect(blur.enabled, isTrue, reason: '$brightness');
        await tester.tapAt(const Offset(40, 400));
        await tester.pumpAndSettle();
      }
    });

    group('with reduced motion', () {
      tearDown(
        () => TestWidgetsFlutterBinding.instance.platformDispatcher
            .clearAccessibilityFeaturesTestValue(),
      );

      testWidgets('opens and closes instantly, solid and unblurred', (
        tester,
      ) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        await tester.pumpWidget(_app(home: _topBarPage()));
        final circle = _circle(tester);
        await tester.tap(_trigger);
        await tester.pump();

        expect(tester.getRect(_primary).topRight, _nearOffset(circle.topRight));
        expect(
          tester
              .widget<BackdropFilter>(find.byType(BackdropFilter).first)
              .enabled,
          isFalse,
        );
        await tester.tapAt(const Offset(40, 400));
        await tester.pump();
        expect(_items0, findsNothing);
      });
    });
  });

  group('items', () {
    testWidgets('tapping an item closes the menu and runs it once', (
      tester,
    ) async {
      var edits = 0;
      await tester.pumpWidget(
        _app(
          home: _topBarPage(items: _items(onEdit: () => edits++)),
        ),
      );
      await openMenu(tester);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(edits, 1);
      expect(_items0, findsNothing);
    });

    testWidgets('taps while the panel is still growing are ignored', (
      tester,
    ) async {
      var edits = 0;
      await tester.pumpWidget(
        _app(
          home: _topBarPage(items: _items(onEdit: () => edits++)),
        ),
      );
      await tester.tap(_trigger);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.text('Edit'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(edits, 0);
    });

    testWidgets('rows are inset pills with the NexioSchedule metrics', (
      tester,
    ) async {
      useSize(tester, const Size(393, 800));
      await tester.pumpWidget(_app(home: _topBarPage()));
      await openMenu(tester);
      final panel = tester.getRect(_primary);
      final row = tester.getRect(_items0.first);
      final icon = tester.getRect(_faIcon(FontAwesomeIcons.penToSquare));
      final edit = tester.getRect(find.text('Edit'));
      expect(row.top - panel.top, _near(8));
      expect(panel.bottom - tester.getRect(_items0.last).bottom, _near(8));
      // 胶囊缩进 8 + 内边距 14，图标格 24、间距 10。
      expect(icon.center.dx - panel.left, _near(8 + 14 + 12));
      expect(edit.left - panel.left, _near(8 + 14 + 24 + 10));
      // 动作项行高 = 上下 10.5 + 24 的图标格。
      expect(row.height, _near(45));
      final style = tester
          .renderObject<RenderParagraph>(find.text('Edit'))
          .text
          .style!;
      expect(style.fontSize, 15.6);
      expect(style.fontWeight, FontWeight.w500);
    });

    testWidgets('a selected choice turns primary with a trailing check', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          home: _topBarPage(
            items: <Widget>[
              ExpressiveMenuItem(
                selected: true,
                onPressed: () {},
                child: const Text('Newest'),
              ),
              ExpressiveMenuItem(
                selected: false,
                onPressed: () {},
                child: const Text('Oldest'),
              ),
            ],
          ),
        ),
      );
      await openMenu(tester);
      final colors = Theme.of(tester.element(find.text('Newest'))).colorScheme;
      expect(_textColor(tester, 'Newest'), colors.primary);
      expect(_textColor(tester, 'Oldest'), colors.onSurface);
      expect(_faIcon(FontAwesomeIcons.check), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Newest')),
        isSemantics(isSelected: true, isButton: true, hasSelectedState: true),
      );
    });

    testWidgets('destructive and disabled items', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          home: _topBarPage(
            items: <Widget>[
              ExpressiveMenuItem(
                destructive: true,
                onPressed: () {},
                child: const Text('Delete'),
              ),
              const ExpressiveMenuItem(onPressed: null, child: Text('Locked')),
              ExpressiveMenuItem(
                onPressed: () => taps++,
                child: const Text('Other'),
              ),
            ],
          ),
        ),
      );
      await openMenu(tester);
      final colors = Theme.of(tester.element(find.text('Delete'))).colorScheme;
      expect(_textColor(tester, 'Delete'), colors.error);
      expect(_textColor(tester, 'Locked').a, _near(0.38));
      await tester.tap(find.text('Locked'));
      await tester.pumpAndSettle();
      expect(_items0, findsNWidgets(3));
      expect(taps, 0);
    });

    testWidgets('a summary line sits under the title', (tester) async {
      await tester.pumpWidget(
        _app(
          home: _topBarPage(
            items: <Widget>[
              ExpressiveMenuItem(
                onPressed: () {},
                summary: const Text('Hangzhou, Xihu'),
                child: const Text('District'),
              ),
            ],
          ),
        ),
      );
      await openMenu(tester);
      expect(
        tester.getRect(find.text('Hangzhou, Xihu')).top,
        greaterThanOrEqualTo(tester.getRect(find.text('District')).bottom),
      );
    });
  });

  group('drag to select', () {
    List<Widget> three(List<String> log) => <Widget>[
      for (final label in <String>['One', 'Two', 'Three'])
        ExpressiveMenuItem(onPressed: () => log.add(label), child: Text(label)),
    ];

    testWidgets('press, slide to another row and release runs that row', (
      tester,
    ) async {
      final log = <String>[];
      await tester.pumpWidget(_app(home: _topBarPage(items: three(log))));
      await openMenu(tester);
      final from = tester.getCenter(find.text('One'));
      final to = tester.getCenter(find.text('Three'));
      final gesture = await tester.startGesture(from);
      await tester.pump();
      final selection = _selection(tester, _primary);
      expect(selection.pressed, isNotNull);
      final top = selection.maskTop.value;
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy((to - from) / 10);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 200));
      // 高亮胶囊滑到了 Three。
      expect(selection.maskTop.value, greaterThan(top + 50));
      expect(selection.maskAlpha.value, 1);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(log, <String>['Three']);
      expect(_items0, findsNothing);
    });

    testWidgets('sliding off the rows and releasing runs nothing', (
      tester,
    ) async {
      final log = <String>[];
      await tester.pumpWidget(_app(home: _topBarPage(items: three(log))));
      await openMenu(tester);
      final panel = tester.getRect(_primary);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Two')),
      );
      await tester.pump();
      await gesture.moveTo(Offset(panel.center.dx, panel.bottom + 60));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(log, isEmpty);
      expect(_items0, findsNWidgets(3));
    });

    testWidgets('pressing makes the panel a little bigger', (tester) async {
      await tester.pumpWidget(_app(home: _topBarPage()));
      await openMenu(tester);
      final settled = tester.getRect(_primary);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Edit')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final pressed = tester.getRect(_primary);
      expect(pressed.height, greaterThan(settled.height + 1));
      expect(pressed.height, lessThan(settled.height + 4));
      await gesture.cancel();
      await tester.pumpAndSettle();
    });
  });

  group('behaviour', () {
    testWidgets('tapping outside closes without hitting the widget below', (
      tester,
    ) async {
      var bodyTaps = 0;
      await tester.pumpWidget(
        _app(home: _topBarPage(onBodyTap: () => bodyTaps++)),
      );
      await openMenu(tester);
      await tester.tapAt(const Offset(40, 400));
      await tester.pumpAndSettle();

      expect(_items0, findsNothing);
      expect(bodyTaps, 0);

      await tester.tapAt(const Offset(40, 400));
      await tester.pump();
      expect(bodyTaps, 1);
    });

    testWidgets('system back closes the menu but keeps the route', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => _topBarPage())),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await openMenu(tester);
      expect(find.byType(BackButton), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_items0, findsNothing);
      expect(find.text('Page'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('keyboard: arrows focus items, enter runs, escape closes', (
      tester,
    ) async {
      var edits = 0;
      await tester.pumpWidget(
        _app(
          home: _topBarPage(items: _items(onEdit: () => edits++)),
        ),
      );
      await openMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(Focus.of(tester.element(find.text('Edit'))).hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_items0, findsNothing);
      expect(
        Focus.of(tester.element(find.byType(FaIcon).first)).hasFocus,
        isTrue,
      );

      await openMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(edits, 1);
    });

    testWidgets('the trigger reports its expanded state to semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(home: _topBarPage()));
      expect(
        tester.getSemantics(_trigger),
        isSemantics(hasExpandedState: true, isExpanded: false, isButton: true),
      );
      await openMenu(tester);
      expect(
        tester.getSemantics(_trigger),
        isSemantics(hasExpandedState: true, isExpanded: true, isButton: true),
      );
      handle.dispose();
    });
  });

  group('openAt (context menu at a position)', () {
    final anchorKey = GlobalKey<ExpressiveMenuAnchorState>();
    final fieldFocus = FocusNode();
    tearDownAll(fieldFocus.dispose);

    Widget page() => Scaffold(
      body: Column(
        children: <Widget>[
          TextField(focusNode: fieldFocus),
          Expanded(
            child: ExpressiveMenuAnchor(
              key: anchorKey,
              menuChildren: _items(),
              builder: (context, menu, child) => const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );

    testWidgets('puts the start corner of the menu at the given point', (
      tester,
    ) async {
      useSize(tester, const Size(800, 600));
      await tester.pumpWidget(_app(home: page()));
      anchorKey.currentState!.openAt(const Offset(200, 300));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(_primary).topLeft,
        _nearOffset(const Offset(200, 300)),
      );
      final seed = _cascade(tester).primaryPlacement!.seed;
      expect(seed.topLeft, _nearOffset(const Offset(200, 300)));
    });

    testWidgets('flips above the point and stays inside near the corner', (
      tester,
    ) async {
      useSize(tester, const Size(800, 600));
      await tester.pumpWidget(_app(home: page()));
      anchorKey.currentState!.openAt(const Offset(790, 590));
      await tester.pumpAndSettle();
      final panel = tester.getRect(_primary);
      expect(panel.bottom, _near(590));
      expect(panel.right, lessThanOrEqualTo(800 - 8));
    });

    testWidgets('reopening at another point moves the menu', (tester) async {
      useSize(tester, const Size(800, 600));
      await tester.pumpWidget(_app(home: page()));
      anchorKey.currentState!.openAt(const Offset(100, 200));
      await tester.pumpAndSettle();
      anchorKey.currentState!.openAt(const Offset(300, 250));
      await tester.pumpAndSettle();
      expect(_items0, findsNWidgets(2));
      expect(
        tester.getRect(_primary).topLeft,
        _nearOffset(const Offset(300, 250)),
      );
    });

    testWidgets('escape closes it and focus goes back to where it was', (
      tester,
    ) async {
      useSize(tester, const Size(800, 600));
      await tester.pumpWidget(_app(home: page()));
      fieldFocus.requestFocus();
      await tester.pump();
      anchorKey.currentState!.openAt(const Offset(200, 300));
      await tester.pumpAndSettle();
      expect(fieldFocus.hasFocus, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(Focus.of(tester.element(find.text('Edit'))).hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_items0, findsNothing);
      expect(fieldFocus.hasFocus, isTrue);
    });

    testWidgets('a keyboard open focuses the first item', (tester) async {
      useSize(tester, const Size(800, 600));
      var edits = 0;
      await tester.pumpWidget(
        _app(
          home: Scaffold(
            body: ExpressiveMenuAnchor(
              key: anchorKey,
              menuChildren: _items(onEdit: () => edits++),
              builder: (context, menu, child) => const SizedBox.expand(),
            ),
          ),
        ),
      );
      anchorKey.currentState!.openAt(
        const Offset(200, 300),
        focusFirstItem: true,
      );
      await tester.pumpAndSettle();
      expect(Focus.of(tester.element(find.text('Edit'))).hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(edits, 1);
      expect(_items0, findsNothing);
    });
  });

  group('submenus (cascading morph)', () {
    List<Widget> nestedItems({
      VoidCallback? onLarge,
      VoidCallback? onPick,
      VoidCallback? onRoot,
      bool sizeFirst = true,
    }) {
      final size = ExpressiveSubmenuItem(
        leadingIcon: const FaIcon(FontAwesomeIcons.font),
        menuChildren: <Widget>[
          ExpressiveMenuItem(
            onPressed: onLarge ?? () {},
            child: const Text('Large'),
          ),
          ExpressiveMenuItem(
            closeOnActivate: false,
            onPressed: onPick ?? () {},
            child: const Text('Pick'),
          ),
          ExpressiveMenuItem(onPressed: () {}, child: const Text('Third')),
        ],
        child: const Text('Size'),
      );
      final root = ExpressiveMenuItem(
        onPressed: onRoot ?? () {},
        child: const Text('Root'),
      );
      return sizeFirst ? <Widget>[size, root] : <Widget>[root, size];
    }

    final header = find.byType(ExpressiveSubmenuHeader);

    Future<void> openSize(WidgetTester tester) async {
      await openMenu(tester);
      await tester.tap(find.text('Size'));
      await tester.pumpAndSettle();
    }

    testWidgets('the trigger pill grows into a panel over the shrunk menu', (
      tester,
    ) async {
      useSize(tester, const Size(393, 800));
      await tester.pumpWidget(
        _app(home: _topBarPage(items: nestedItems(sizeFirst: false))),
      );
      await openMenu(tester);
      final primaryBefore = tester.getRect(_primary);
      final row = tester.getRect(find.byType(ExpressiveSubmenuItem));

      await tester.tap(find.text('Size'));
      await tester.pumpAndSettle();
      expect(_panels, findsNWidgets(2));
      expect(header, findsOneWidget);
      expect(find.byType(ExpressiveMenuDivider), findsOneWidget);
      // 主菜单以贴着按钮的右上角为原点缩到 0.95。
      final primaryAfter = tester.getRect(_primary);
      expect(primaryAfter.width, _near(primaryBefore.width * 0.95));
      expect(primaryAfter.topRight, _nearOffset(primaryBefore.topRight));
      // 起点是触发行缩进后的胶囊；标题行停在触发行原处。
      final cascade = _cascade(tester);
      final pill = cascade.submenuPillRect!;
      expect(pill.left, _near(row.left + 8));
      expect(pill.right, _near(row.right - 8));
      expect(pill.top, _near(row.top));
      expect(tester.getRect(header).topLeft, _nearOffset(row.topLeft));
      final secondary = tester.getRect(_panels.last);
      expect(secondary.top, _near(row.top - 8));
      expect(secondary.width, greaterThanOrEqualTo(primaryBefore.width));
      final turns = tester
          .widget<RotationTransition>(
            find.descendant(
              of: header,
              matching: find.byType(RotationTransition),
            ),
          )
          .turns
          .value;
      expect(turns, _near(-0.25));
    });

    testWidgets('tapping the header, the mask or outside collapses it first', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(home: _topBarPage(items: nestedItems(sizeFirst: false))),
      );
      final collapsers = <Future<void> Function()>[
        () => tester.tap(find.text('Size').last),
        () => tester.tap(find.text('Root')),
        () => tester.tapAt(const Offset(40, 500)),
      ];
      for (final collapse in collapsers) {
        await openSize(tester);
        await collapse();
        await tester.pumpAndSettle();
        expect(header, findsNothing);
        expect(find.text('Root'), findsOneWidget);
        expect(_panels, findsOneWidget);
        // 收回后主菜单没有残留的高亮胶囊。
        expect(_selection(tester, _primary).maskAlpha.value, 0);
        await tester.tapAt(const Offset(40, 500));
        await tester.pumpAndSettle();
        expect(_items0, findsNothing);
      }
    });

    testWidgets('an item that keeps the menu open runs without closing', (
      tester,
    ) async {
      var picks = 0;
      await tester.pumpWidget(
        _app(
          home: _topBarPage(items: nestedItems(onPick: () => picks++)),
        ),
      );
      await openSize(tester);
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
      expect(picks, 1);
      expect(header, findsOneWidget);
    });

    testWidgets('a normal item in a submenu closes the whole menu', (
      tester,
    ) async {
      var large = 0;
      await tester.pumpWidget(
        _app(
          home: _topBarPage(items: nestedItems(onLarge: () => large++)),
        ),
      );
      await openSize(tester);
      await tester.tap(find.text('Large'));
      await tester.pumpAndSettle();
      expect(large, 1);
      expect(_items0, findsNothing);

      await openMenu(tester);
      expect(find.text('Root'), findsOneWidget);
      expect(header, findsNothing);
    });

    testWidgets('primary rows ignore taps under the mask', (tester) async {
      var roots = 0;
      await tester.pumpWidget(
        _app(
          home: _topBarPage(
            items: nestedItems(onRoot: () => roots++, sizeFirst: false),
          ),
        ),
      );
      await openSize(tester);
      await tester.tap(find.text('Root'));
      await tester.pumpAndSettle();
      expect(roots, 0);
      expect(header, findsNothing);
      await tester.tap(find.text('Root'));
      await tester.pumpAndSettle();
      expect(roots, 1);
    });

    testWidgets('system back leaves the submenu first, then closes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _topBarPage(items: nestedItems()),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await openSize(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(header, findsNothing);
      expect(find.text('Root'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_items0, findsNothing);
      expect(find.text('Page'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('keyboard: enter opens it, left arrow and escape go back', (
      tester,
    ) async {
      await tester.pumpWidget(_app(home: _topBarPage(items: nestedItems())));
      await openMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(Focus.of(tester.element(find.text('Size'))).hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(header, findsOneWidget);
      expect(Focus.of(tester.element(find.text('Size').last)).hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(header, findsNothing);
      expect(Focus.of(tester.element(find.text('Size'))).hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(header, findsNothing);
      expect(find.text('Root'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_items0, findsNothing);
    });

    testWidgets('chevrons point the other way in right-to-left text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          home: _topBarPage(items: nestedItems()),
          textDirection: TextDirection.rtl,
        ),
      );
      await openMenu(tester);
      expect(_faIcon(FontAwesomeIcons.angleLeft), findsOneWidget);
      expect(_faIcon(FontAwesomeIcons.angleRight), findsNothing);
      await tester.tap(find.text('Size'));
      await tester.pumpAndSettle();
      final turns = tester
          .widget<RotationTransition>(
            find.descendant(
              of: header,
              matching: find.byType(RotationTransition),
            ),
          )
          .turns
          .value;
      expect(turns, _near(0.25));
    });

    testWidgets('appears and goes at once with reduced motion', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(_app(home: _topBarPage(items: nestedItems())));
      await tester.tap(_trigger);
      await tester.pump();
      await tester.tap(find.text('Size'));
      await tester.pump();
      expect(find.text('Pick'), findsOneWidget);
      await tester.tap(find.text('Size').last);
      await tester.pump();
      expect(header, findsNothing);
    });
  });

  group('when its page stops ticking (switched to another tab)', () {
    testWidgets('a closing menu goes away at once and taps reach the rest', (
      tester,
    ) async {
      var ticking = true;
      var navTaps = 0;
      await tester.pumpWidget(
        _app(
          home: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) => Column(
              children: <Widget>[
                Expanded(
                  child: TickerMode(
                    enabled: ticking,
                    child: _topBarPage(
                      items: <Widget>[
                        ExpressiveMenuItem(
                          onPressed: () => setState(() => ticking = false),
                          child: const Text('Settings'),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => navTaps++,
                  child: const Text('Nav'),
                ),
              ],
            ),
          ),
        ),
      );
      await openMenu(tester);
      await tester.tap(find.text('Settings'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(_items0, findsNothing);

      await tester.tap(find.text('Nav'));
      expect(navTaps, 1);
    });
  });
}

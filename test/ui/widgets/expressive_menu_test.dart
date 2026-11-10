import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu_geometry.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu_layout.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu_panel.dart';
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

/// 铺满屏幕的变暗层。
Finder get _dim => find.byWidgetPredicate(
  (Widget widget) =>
      widget is FadeTransition &&
      widget.child is ColoredBox &&
      widget.opacity is AnimationController,
);

Matcher _near(double value, {double epsilon = 0.01}) =>
    moreOrLessEquals(value, epsilon: epsilon);

Matcher _nearOffset(Offset value) =>
    offsetMoreOrLessEquals(value, epsilon: 0.01);

Color _textColor(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text)).text.style!.color!;

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

  group('placement (miuix dropdown rules)', () {
    testWidgets('opens 8dp below an end-aligned trigger, end edges aligned', (
      tester,
    ) async {
      useSize(tester, const Size(393, 800));
      await tester.pumpWidget(_app(home: _topBarPage()));
      await openMenu(tester);

      final trigger = tester.getRect(_trigger);
      final panel = tester.getRect(_primary);
      expect(panel.right, _near(trigger.right));
      expect(panel.top, _near(trigger.bottom + 8));
      expect(panel.width, inInclusiveRange(200, 288));
      final placed = _cascade(tester).primaryPlacement!;
      expect(placed.side, ExpressiveMenuSide.below);
      expect(placed.alignRight, isTrue);
    });

    testWidgets('aligns the start edge to the trigger in right-to-left text', (
      tester,
    ) async {
      useSize(tester, const Size(393, 800));
      await tester.pumpWidget(
        _app(home: _topBarPage(), textDirection: TextDirection.rtl),
      );
      await openMenu(tester);

      final trigger = tester.getRect(_trigger);
      final panel = tester.getRect(_primary);
      // RTL 下“结束边”是左缘。
      expect(panel.left, _near(trigger.left));
      expect(panel.top, _near(trigger.bottom + 8));
    });

    testWidgets('a start-aligned menu lines up with the trigger start edge', (
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
      await openMenu(tester);

      final trigger = tester.getRect(_trigger);
      final panel = tester.getRect(_primary);
      expect(panel.left, _near(trigger.left));
      expect(panel.top, _near(trigger.bottom + 8));
    });

    testWidgets('flips above the trigger near the bottom edge', (tester) async {
      useSize(tester, const Size(393, 800));
      await tester.pumpWidget(
        _app(
          home: _alignedPage(
            Alignment.bottomRight,
            padding: const EdgeInsets.all(16),
          ),
        ),
      );
      await openMenu(tester);

      final trigger = tester.getRect(_trigger);
      final panel = tester.getRect(_primary);
      expect(panel.bottom, _near(trigger.top - 8));
      expect(panel.right, _near(trigger.right));
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
          expect(panel.left, greaterThanOrEqualTo(0), reason: '$alignment');
          expect(panel.right, lessThanOrEqualTo(320), reason: '$alignment');
          expect(panel.top, greaterThanOrEqualTo(8), reason: '$alignment');
          expect(panel.bottom, lessThanOrEqualTo(632), reason: '$alignment');
          expect(panel.width, lessThanOrEqualTo(288));
          expect(tester.takeException(), isNull);
          await tester.tapAt(const Offset(160, 320));
          await tester.pumpAndSettle();
        }
      }
    });

    test('a menu taller than both sides is centred on the anchor', () {
      final placed = placeExpressiveMenu(
        anchor: const Rect.fromLTWH(100, 290, 40, 40),
        size: const Size(200, 500),
        bounds: const Rect.fromLTWH(0, 0, 400, 600),
        placement: ExpressiveMenuPlacement.start,
        textDirection: TextDirection.ltr,
        margin: 8,
      );
      expect(placed.side, ExpressiveMenuSide.middle);
      expect(placed.rect.center.dy, _near(310));
      expect(placed.pivot, Offset(100, placed.rect.center.dy));
    });
  });

  group('motion', () {
    testWidgets('grows from the trigger corner and reveals downward', (
      tester,
    ) async {
      useSize(tester, const Size(393, 800));
      await tester.pumpWidget(_app(home: _topBarPage()));
      await tester.tap(_trigger);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      final trigger = tester.getRect(_trigger);
      final midway = tester.getRect(_primary);
      final opacity = tester
          .widget<FadeTransition>(
            find
                .descendant(of: _primary, matching: find.byType(FadeTransition))
                .first,
          )
          .opacity
          .value;
      await tester.pumpAndSettle();
      final settled = tester.getRect(_primary);
      // 缩放以贴着按钮的右上角为原点：这一角始终在原处。
      expect(midway.width, lessThan(settled.width * 0.9));
      expect(midway.right, _near(trigger.right));
      expect(midway.top, _near(trigger.bottom + 8));
      expect(opacity, inExclusiveRange(0, 1));
    });

    testWidgets('the scale spring overshoots a little before settling', (
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
      expect(widest, lessThan(settled * 1.02));
    });

    testWidgets('dims the screen while open', (tester) async {
      await tester.pumpWidget(_app(home: _topBarPage()));
      expect(_dim, findsNothing);
      await tester.tap(_trigger);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final midway = tester.widget<FadeTransition>(_dim).opacity.value;
      expect(midway, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(tester.widget<FadeTransition>(_dim).opacity.value, 1);
      final color = tester.widget<ColoredBox>(
        find.descendant(of: _dim, matching: find.byType(ColoredBox)),
      );
      expect(color.color.a, _near(0.3, epsilon: 0.01));
    });

    testWidgets('closing fades out in 150ms, then the overlay is removed', (
      tester,
    ) async {
      await tester.pumpWidget(_app(home: _topBarPage()));
      await openMenu(tester);
      await tester.tapAt(const Offset(40, 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_items0, findsNWidgets(2));
      // 收起途中不再响应条目。
      expect(
        tester
            .state<ExpressiveMenuAnchorState>(find.byType(ExpressiveMenuAnchor))
            .interactive,
        isFalse,
      );
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump();
      expect(_items0, findsNothing);
    });

    testWidgets('the panel is opaque over the dim, no blur', (tester) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          _app(home: _topBarPage(), brightness: brightness),
        );
        await openMenu(tester);
        final blur = tester.widget<BackdropFilter>(
          find.descendant(of: _primary, matching: find.byType(BackdropFilter)),
        );
        expect(blur.enabled, isFalse);
        final material = tester.widget<Material>(
          find.descendant(of: _primary, matching: find.byType(Material)).first,
        );
        expect(material.color!.a, 1, reason: '$brightness');
        await tester.tapAt(const Offset(40, 400));
        await tester.pumpAndSettle();
      }
    });

    group('with reduced motion', () {
      tearDown(
        () => TestWidgetsFlutterBinding.instance.platformDispatcher
            .clearAccessibilityFeaturesTestValue(),
      );

      testWidgets('opens and closes instantly', (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        await tester.pumpWidget(_app(home: _topBarPage()));
        await tester.tap(_trigger);
        await tester.pump();

        final trigger = tester.getRect(_trigger);
        final panel = tester.getRect(_primary);
        expect(panel.right, _near(trigger.right));
        expect(panel.width, greaterThanOrEqualTo(200));
        expect(tester.widget<FadeTransition>(_dim).opacity.value, 1);

        await tester.tapAt(const Offset(40, 400));
        await tester.pump();
        expect(_items0, findsNothing);
      });
    });
  });

  group('items', () {
    testWidgets('tapping an item closes the menu and runs the callback once', (
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

    testWidgets('rows follow the miuix metrics', (tester) async {
      useSize(tester, const Size(393, 800));
      await tester.pumpWidget(_app(home: _topBarPage()));
      await openMenu(tester);
      final panel = tester.getRect(_primary);
      final edit = tester.getRect(find.text('Edit'));
      final icon = tester.getRect(_faIcon(FontAwesomeIcons.penToSquare));
      // 首行文字离面板顶边 20（行内 12 + 面板 8），左内边距 20。
      final editRow = tester.getRect(_items0.first);
      expect(editRow.top - panel.top, _near(8));
      expect(icon.center.dx - panel.left, _near(20 + 13));
      expect(edit.left - panel.left, _near(20 + 26 + 12));
      expect(tester.getRect(_items0.last).bottom, _near(panel.bottom - 8));
    });

    testWidgets('a selected item turns primary with a trailing check', (
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
      // 对勾格始终留着：两行文字起点一致，选中不会左右挪动。
      expect(
        tester.getRect(find.text('Newest')).left,
        tester.getRect(find.text('Oldest')).left,
      );
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
      final colors = Theme.of(
        tester.element(find.text('District')),
      ).colorScheme;
      expect(_textColor(tester, 'Hangzhou, Xihu'), colors.onSurfaceVariant);
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

      // 菜单关上后，同一位置的点按照常到达正文。
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
      // 打开菜单不应让顶栏把返回键换成关闭键。
      expect(find.byType(BackButton), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_items0, findsNothing);
      expect(find.text('Page'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Page'), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('escape closes the menu and focus returns to the trigger', (
      tester,
    ) async {
      await tester.pumpWidget(_app(home: _topBarPage()));
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
    });

    testWidgets('enter on a focused item runs it', (tester) async {
      var edits = 0;
      await tester.pumpWidget(
        _app(
          home: _topBarPage(items: _items(onEdit: () => edits++)),
        ),
      );
      await openMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(edits, 1);
      expect(_items0, findsNothing);
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

    testWidgets('the trigger stays held down until the menu is gone', (
      tester,
    ) async {
      await tester.pumpWidget(_app(home: _topBarPage()));
      ExpressiveMenuAnchorState menu() => tester
          .state<ExpressiveMenuAnchorState>(find.byType(ExpressiveMenuAnchor));
      expect(menu().isShowing, isFalse);
      await openMenu(tester);
      expect(menu().isShowing, isTrue);
      await tester.tapAt(const Offset(40, 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      // 收起途中已算“收起”，但按住的底色要等浮层移除才褪去。
      expect(menu().isExpanded, isFalse);
      expect(menu().isShowing, isTrue);
      await tester.pumpAndSettle();
      expect(menu().isShowing, isFalse);
    });
  });

  group('openAt (context menu at a position)', () {
    final anchorKey = GlobalKey<ExpressiveMenuAnchorState>();
    final fieldFocus = FocusNode();
    tearDownAll(fieldFocus.dispose);

    /// 铺满页面的锚点（像一张卡片），另有一个输入框持有打开前的焦点。
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

      final panel = tester.getRect(_primary);
      expect(panel.left, _near(200));
      expect(panel.top, _near(300));
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
      expect(panel.right, lessThanOrEqualTo(800));
    });

    testWidgets('reopening at another point moves the menu', (tester) async {
      useSize(tester, const Size(800, 600));
      await tester.pumpWidget(_app(home: page()));
      anchorKey.currentState!.openAt(const Offset(100, 200));
      await tester.pumpAndSettle();
      anchorKey.currentState!.openAt(const Offset(300, 250));
      await tester.pumpAndSettle();

      expect(_items0, findsNWidgets(2));
      final panel = tester.getRect(_primary);
      expect(panel.topLeft, _nearOffset(const Offset(300, 250)));
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

      // 鼠标打开时焦点停在菜单本身：↓ 进入第一项。
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

    testWidgets('a desktop right-click menu keeps the glass and no dim', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      useSize(tester, const Size(800, 600));
      await tester.pumpWidget(_app(home: page()));
      anchorKey.currentState!.openAt(const Offset(200, 300));
      await tester.pumpAndSettle();
      expect(_dim, findsNothing);
      final blur = tester.widget<BackdropFilter>(
        find.descendant(of: _primary, matching: find.byType(BackdropFilter)),
      );
      expect(blur.enabled, isTrue);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a long-press menu on a phone still dims', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      useSize(tester, const Size(400, 800));
      await tester.pumpWidget(_app(home: page()));
      anchorKey.currentState!.openAt(const Offset(200, 300));
      await tester.pumpAndSettle();
      expect(_dim, findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('submenus (cascading morph)', () {
    List<Widget> nestedItems({
      VoidCallback? onLarge,
      VoidCallback? onPick,
      VoidCallback? onRoot,
      bool sizeFirst = true,
      bool sizeMiddle = false,
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
      if (sizeMiddle) {
        return <Widget>[
          root,
          size,
          ExpressiveMenuItem(onPressed: () {}, child: const Text('After')),
        ];
      }
      return sizeFirst ? <Widget>[size, root] : <Widget>[root, size];
    }

    final header = find.byType(ExpressiveSubmenuHeader);

    Future<void> openSize(WidgetTester tester) async {
      await openMenu(tester);
      await tester.tap(find.text('Size'));
      await tester.pumpAndSettle();
    }

    testWidgets('the trigger row grows into a panel over the shrunk menu', (
      tester,
    ) async {
      useSize(tester, const Size(393, 800));
      await tester.pumpWidget(_app(home: _topBarPage(items: nestedItems())));
      await openMenu(tester);
      final primaryBefore = tester.getRect(_primary);
      final row = tester.getRect(find.byType(ExpressiveSubmenuItem));

      await tester.tap(find.text('Size'));
      await tester.pumpAndSettle();
      expect(_panels, findsNWidgets(2));
      expect(header, findsOneWidget);
      expect(find.byType(ExpressiveMenuDivider), findsOneWidget);
      expect(find.text('Pick'), findsOneWidget);
      // 主菜单仍在原处，缩到 0.95（以贴着按钮的角为原点）。
      final primaryAfter = tester.getRect(_primary);
      expect(primaryAfter.width, _near(primaryBefore.width * 0.95));
      expect(primaryAfter.topRight, _nearOffset(primaryBefore.topRight));
      // 二级菜单从触发行（首行延伸到面板顶边）的位置展开，起始边对齐。
      final cascade = _cascade(tester);
      expect(cascade.submenuAnchorRect!.top, _near(primaryBefore.top));
      expect(cascade.submenuAnchorRect!.bottom, _near(row.bottom));
      final secondary = tester.getRect(_panels.last);
      expect(secondary.top, _near(primaryBefore.top));
      expect(secondary.left, _near(primaryBefore.left));
      expect(secondary.width, greaterThanOrEqualTo(primaryBefore.width));
      // 标题行的 › 转向上方。
      final turns = tester
          .widget<RotationTransition>(
            find.descendant(
              of: header,
              matching: find.byType(RotationTransition),
            ),
          )
          .turns
          .value;
      expect(turns, _near(-0.25, epsilon: 0.01));
    });

    testWidgets('mid-morph the header still matches the trigger row height', (
      tester,
    ) async {
      useSize(tester, const Size(393, 800));
      await tester.pumpWidget(
        _app(home: _topBarPage(items: nestedItems(sizeMiddle: true))),
      );
      await openMenu(tester);
      final row = tester.getRect(find.byType(ExpressiveSubmenuItem));

      await tester.tap(find.text('Size'));
      await tester.pump();
      final start = tester.getSize(header).height;
      await tester.pump(const Duration(milliseconds: 60));
      final mid = tester.getSize(header).height;
      await tester.pumpAndSettle();
      final end = tester.getSize(header).height;
      // 中间行：起点即触发行本身的高度，展开完是上 20、下 12。
      expect(start, _near(row.height, epsilon: 0.5));
      expect(mid, inExclusiveRange(start, end));
      expect(end, _near(row.height + 8));
      // 落点：二级菜单顶边对齐触发行顶边。
      expect(_cascade(tester).submenuRect!.top, _near(row.top));
    });

    testWidgets('tapping the header, the mask or outside collapses it first', (
      tester,
    ) async {
      // Size 在第二行：二级菜单从它往下长，主菜单的首行 Root 露在外面、
      // 被遮罩盖着。
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
        // 再点外部才关掉整个菜单。
        await tester.tapAt(const Offset(40, 500));
        await tester.pumpAndSettle();
        expect(_items0, findsNothing);
      }
    });

    testWidgets('the trigger button collapses the submenu before closing', (
      tester,
    ) async {
      await tester.pumpWidget(_app(home: _topBarPage(items: nestedItems())));
      await openSize(tester);
      await tester.tap(_trigger, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(header, findsNothing);
      expect(find.text('Root'), findsOneWidget);
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

      // 重新展开总是从主菜单开始。
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
      // Root 露在二级菜单上方、盖着遮罩：点它只收回二级菜单。
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
      expect(find.byType(BackButton), findsOneWidget);

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

    testWidgets('closing from a submenu leaves no back interception behind', (
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
      await tester.tap(find.text('Large'));
      await tester.pumpAndSettle();

      // 一次返回就回到上一页，没有残留的局部历史。
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
      // 焦点落到二级菜单的标题行。
      expect(header, findsOneWidget);
      expect(Focus.of(tester.element(find.text('Size').last)).hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(header, findsNothing);
      // 收回后焦点回到入口那一行。
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
      expect(turns, _near(0.25, epsilon: 0.01));
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
      // 首行触发：展开完的标题行（上 20、下 12）与延伸到顶边的触发行等高。
      expect(
        tester.getSize(header).height,
        _near(tester.getSize(find.byType(ExpressiveSubmenuItem)).height + 8),
      );
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
                        // 与“更多 → 设置”一样：点了就切走这个 Tab。
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
      // 下一帧菜单直接关掉，不等收起动画。
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(_items0, findsNothing);

      await tester.tap(find.text('Nav'));
      expect(navTaps, 1);
    });
  });
}

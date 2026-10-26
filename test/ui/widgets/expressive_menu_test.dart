import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu_layout.dart';

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
}) => MaterialApp(
  theme: expressiveTestTheme(Brightness.light),
  builder: (BuildContext context, Widget? child) =>
      Directionality(textDirection: textDirection, child: child!),
  home: home,
);

/// 顶栏右侧的 ⋮ 菜单，正文铺满一个计数按钮，用来检查点外部是否穿透。
Widget _topBarPage({
  List<Widget>? items,
  ExpressiveMenuPlacement placement = ExpressiveMenuPlacement.end,
  VoidCallback? onBodyTap,
}) => Scaffold(
  appBar: AppBar(
    title: const Text('Page'),
    // 与应用顶栏一样在行尾留出边距，菜单不会被安全区边距推开。
    actionsPadding: const EdgeInsetsDirectional.only(end: 16),
    actions: <Widget>[
      ExpressiveMenuButton(
        tooltip: _tooltip,
        icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 18),
        placement: placement,
        items: items ?? _items(),
      ),
    ],
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
      child: ExpressiveMenuButton(
        tooltip: _tooltip,
        icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 18),
        placement: placement,
        items: items ?? _items(),
      ),
    ),
  ),
);

Finder get _trigger => find.byTooltip(_tooltip);

/// 玻璃表面里单独淡入的内容层。
Finder get _contentFade => find
    .descendant(
      of: find.byType(ExpressiveMenuSurface),
      matching: find.byType(FadeTransition),
    )
    .first;

BackdropFilter _blur(WidgetTester tester) => tester.widget<BackdropFilter>(
  find.descendant(
    of: find.byType(ExpressiveMenuSurface),
    matching: find.byType(BackdropFilter),
  ),
);

Finder get _panel => find
    .ancestor(
      of: find.byType(MenuItemButton).first,
      matching: find.byType(Material),
    )
    .first;

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

  testWidgets('opens below an end-aligned trigger with its end edge aligned', (
    tester,
  ) async {
    useSize(tester, const Size(393, 800));
    await tester.pumpWidget(_app(home: _topBarPage()));
    await openMenu(tester);

    final trigger = tester.getRect(_trigger);
    final panel = tester.getRect(_panel);
    expect(panel.right, moreOrLessEquals(trigger.right));
    expect(panel.top, moreOrLessEquals(trigger.bottom + 4));
    expect(panel.width, greaterThanOrEqualTo(176));
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
    final panel = tester.getRect(_panel);
    // RTL 下“结束边”是左缘。
    expect(panel.left, moreOrLessEquals(trigger.left));
    expect(panel.top, moreOrLessEquals(trigger.bottom + 4));
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
    final panel = tester.getRect(_panel);
    expect(panel.left, moreOrLessEquals(trigger.left));
    expect(panel.top, moreOrLessEquals(trigger.bottom + 4));
  });

  testWidgets('scales from the corner that touches the trigger', (
    tester,
  ) async {
    useSize(tester, const Size(393, 800));
    await tester.pumpWidget(_app(home: _topBarPage()));
    await tester.tap(_trigger);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    final trigger = tester.getRect(_trigger);
    final midway = tester.getRect(_panel);
    await tester.pumpAndSettle();
    final settled = tester.getRect(_panel);
    expect(midway.width, lessThan(settled.width));
    expect(midway.right, moreOrLessEquals(trigger.right));
    expect(midway.top, moreOrLessEquals(trigger.bottom + 4));
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
    final panel = tester.getRect(_panel);
    expect(panel.bottom, moreOrLessEquals(trigger.top - 4));
    expect(panel.right, moreOrLessEquals(trigger.right));
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
        final panel = tester.getRect(_panel);
        expect(panel.left, greaterThanOrEqualTo(8), reason: '$alignment');
        expect(panel.right, lessThanOrEqualTo(312), reason: '$alignment');
        expect(panel.top, greaterThanOrEqualTo(8), reason: '$alignment');
        expect(panel.bottom, lessThanOrEqualTo(632), reason: '$alignment');
        expect(panel.width, lessThanOrEqualTo(320 - 32));
        expect(tester.takeException(), isNull);
        await tester.tapAt(const Offset(160, 320));
        await tester.pumpAndSettle();
      }
    }
  });

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
    expect(find.byType(MenuItemButton), findsNothing);
  });

  testWidgets('tapping outside closes without hitting the widget underneath', (
    tester,
  ) async {
    var bodyTaps = 0;
    await tester.pumpWidget(
      _app(home: _topBarPage(onBodyTap: () => bodyTaps++)),
    );
    await openMenu(tester);
    await tester.tapAt(const Offset(40, 400));
    await tester.pumpAndSettle();

    expect(find.byType(MenuItemButton), findsNothing);
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
    expect(find.byType(MenuItemButton), findsNothing);
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
    final firstItem = tester.widget<MenuItemButton>(
      find.byType(MenuItemButton).first,
    );
    expect(firstItem.child, isA<Text>());
    expect(Focus.of(tester.element(find.text('Edit'))).hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    expect(
      Focus.of(tester.element(find.byType(FaIcon).first)).hasFocus,
      isTrue,
    );
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

      final fade = tester.widget<FadeTransition>(_contentFade);
      expect(fade.opacity.value, 1);
      // 减少动画时退回不透明底、不做模糊。
      expect(tester.widget<Material>(_panel).color!.a, 1);
      expect(_blur(tester).enabled, isFalse);
      final trigger = tester.getRect(_trigger);
      final panel = tester.getRect(_panel);
      expect(panel.right, moreOrLessEquals(trigger.right));
      expect(panel.width, greaterThanOrEqualTo(176));

      await tester.tapAt(const Offset(40, 400));
      await tester.pump();
      expect(find.byType(MenuItemButton), findsNothing);
    });
  });

  testWidgets('animates open without reduced motion', (tester) async {
    await tester.pumpWidget(_app(home: _topBarPage()));
    await tester.tap(_trigger);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final fade = tester.widget<FadeTransition>(_contentFade);
    expect(fade.opacity.value, inExclusiveRange(0, 1));
    // 底色随进度变深，而不是把整块玻璃放进透明度层：模糊始终能采到页面。
    final colors = Theme.of(tester.element(_panel)).colorScheme;
    final tint = ExpressiveMenuSurface.tintOf(colors);
    expect(
      tester.widget<Material>(_panel).color!.a,
      inExclusiveRange(0, tint.a),
    );
    expect(_blur(tester).enabled, isTrue);
    // 菜单浮层（定位层以下）到模糊层之间不能有透明度层。
    expect(
      find.ancestor(
        of: find.byType(BackdropFilter),
        matching: find.descendant(
          of: find.byType(ExpressiveMenuPosition),
          matching: find.byType(FadeTransition),
        ),
      ),
      findsNothing,
    );
    await tester.pumpAndSettle();
    expect(fade.opacity.value, 1);
    expect(tester.widget<Material>(_panel).color, tint);
  });

  for (final brightness in Brightness.values) {
    testWidgets('uses the bright glass tint in $brightness', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: expressiveTestTheme(brightness),
          home: _topBarPage(),
        ),
      );
      await openMenu(tester);
      final colors = Theme.of(tester.element(_panel)).colorScheme;
      final material = tester.widget<Material>(_panel);
      expect(
        material.color,
        brightness == Brightness.light
            ? colors.surfaceContainerLowest.withValues(alpha: 0.82)
            : colors.surfaceContainerHighest.withValues(alpha: 0.84),
      );
      expect(material.elevation, 0);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side.color, ExpressiveMenuSurface.borderOf(colors));
    });
  }

  testWidgets('a selected item is filled and marked with a check', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        home: _topBarPage(
          items: <Widget>[
            ExpressiveMenuItem(
              selected: true,
              leadingIcon: const FaIcon(FontAwesomeIcons.arrowDownAZ),
              onPressed: () {},
              child: const Text('By name'),
            ),
            ExpressiveMenuItem(
              selected: false,
              leadingIcon: const FaIcon(FontAwesomeIcons.arrowDownWideShort),
              onPressed: () {},
              child: const Text('Custom'),
            ),
          ],
        ),
      ),
    );
    await openMenu(tester);
    final colors = Theme.of(tester.element(find.text('By name'))).colorScheme;

    final selected = find.widgetWithText(MenuItemButton, 'By name');
    final other = find.widgetWithText(MenuItemButton, 'Custom');
    final fill = tester.widget<Material>(
      find.descendant(of: selected, matching: find.byType(Material)).first,
    );
    expect(fill.color, colors.primaryContainer);
    expect(
      tester.renderObject<RenderParagraph>(find.text('By name')).text.style,
      isA<TextStyle>()
          .having((s) => s.color, 'color', colors.onPrimaryContainer)
          .having((s) => s.fontWeight, 'weight', FontWeight.w600),
    );
    expect(
      find.descendant(
        of: selected,
        matching: find.byIcon(FontAwesomeIcons.check.data),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: other,
        matching: find.byIcon(FontAwesomeIcons.check.data),
      ),
      findsNothing,
    );
    expect(
      tester.getSemantics(selected),
      isSemantics(isSelected: true, hasSelectedState: true),
    );
    expect(
      tester.getSemantics(other),
      isSemantics(isSelected: false, hasSelectedState: true),
    );
  });

  testWidgets('a destructive item uses the error colour, others the accent', (
    tester,
  ) async {
    await tester.pumpWidget(_app(home: _topBarPage()));
    await openMenu(tester);
    final colors = Theme.of(tester.element(find.text('Delete'))).colorScheme;

    final label = tester.renderObject<RenderParagraph>(find.text('Delete'));
    expect(label.text.style?.color, colors.error);
    final icon = find.byIcon(FontAwesomeIcons.trashCan.data);
    expect(IconTheme.of(tester.element(icon)).color, colors.error);
    expect(IconTheme.of(tester.element(icon)).size, 16);

    final edit = tester.renderObject<RenderParagraph>(find.text('Edit'));
    expect(edit.text.style?.color, colors.onSurface);
    final editIcon = find.byIcon(FontAwesomeIcons.penToSquare.data);
    expect(IconTheme.of(tester.element(editIcon)).color, colors.primary);
  });

  testWidgets('a disabled item ignores taps and uses the disabled colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        home: _topBarPage(
          items: const <Widget>[
            ExpressiveMenuItem(onPressed: null, child: Text('Unavailable')),
          ],
        ),
      ),
    );
    await openMenu(tester);
    final colors = Theme.of(
      tester.element(find.text('Unavailable')),
    ).colorScheme;
    final label = tester.renderObject<RenderParagraph>(
      find.text('Unavailable'),
    );
    expect(label.text.style?.color, isNot(colors.onSurface));
    await tester.tap(find.text('Unavailable'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Unavailable'), findsOneWidget);
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

      final panel = tester.getRect(_panel);
      expect(panel.left, moreOrLessEquals(200));
      expect(panel.top, moreOrLessEquals(300));
    });

    testWidgets('flips above the point and stays inside near the corner', (
      tester,
    ) async {
      useSize(tester, const Size(800, 600));
      await tester.pumpWidget(_app(home: page()));
      anchorKey.currentState!.openAt(const Offset(790, 590));
      await tester.pumpAndSettle();

      final panel = tester.getRect(_panel);
      expect(panel.bottom, moreOrLessEquals(590));
      expect(panel.right, lessThanOrEqualTo(800 - 8));
    });

    testWidgets('reopening at another point moves the menu', (tester) async {
      useSize(tester, const Size(800, 600));
      await tester.pumpWidget(_app(home: page()));
      anchorKey.currentState!.openAt(const Offset(100, 200));
      await tester.pumpAndSettle();
      anchorKey.currentState!.openAt(const Offset(300, 250));
      await tester.pumpAndSettle();

      expect(find.byType(MenuItemButton), findsNWidgets(2));
      final panel = tester.getRect(_panel);
      expect(panel.topLeft, offsetMoreOrLessEquals(const Offset(300, 250)));
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
      expect(find.byType(MenuItemButton), findsNothing);
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
      expect(find.byType(MenuItemButton), findsNothing);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu.dart';

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

      final fade = tester.widget<FadeTransition>(
        find.ancestor(of: _panel, matching: find.byType(FadeTransition)).first,
      );
      expect(fade.opacity.value, 1);
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
    final fade = tester.widget<FadeTransition>(
      find.ancestor(of: _panel, matching: find.byType(FadeTransition)).first,
    );
    expect(fade.opacity.value, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(fade.opacity.value, 1);
  });

  testWidgets('a destructive item uses the error colour', (tester) async {
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
    expect(
      IconTheme.of(tester.element(editIcon)).color,
      colors.onSurfaceVariant,
    );
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
}

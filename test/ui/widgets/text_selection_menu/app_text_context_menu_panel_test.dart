import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/widgets/text_selection_menu/app_text_context_menu.dart';

import 'text_selection_menu_test_app.dart';

/// AI 一组 + 剪切 / 复制 / 粘贴 / 全选（带快捷键）+ 一个次要项。
List<AppTextMenuAction> _actions(TextMenuTaps taps) => <AppTextMenuAction>[
  taps.action(
    'AI 写作',
    icon: FontAwesomeIcons.wandMagicSparkles,
    slot: AppTextMenuSlot.lead,
  ),
  for (final (label, type) in <(String, ContextMenuButtonType)>[
    ('剪切', ContextMenuButtonType.cut),
    ('复制', ContextMenuButtonType.copy),
    ('粘贴', ContextMenuButtonType.paste),
    ('全选', ContextMenuButtonType.selectAll),
  ])
    taps.action(
      label,
      icon: appTextMenuIconOf(type),
      shortcut: appTextMenuShortcutOf(type),
    ),
  taps.action(
    '查询',
    icon: FontAwesomeIcons.book,
    slot: AppTextMenuSlot.secondary,
  ),
];

Future<(TextMenuTaps, List<int>)> _pump(
  WidgetTester tester, {
  Offset anchor = const Offset(100, 200),
}) async {
  setTextMenuScreen(tester, const Size(800, 600));
  final taps = TextMenuTaps();
  final dismissed = <int>[];
  await tester.pumpWidget(
    textMenuTestApp(
      AppTextContextMenuPanel(
        anchor: anchor,
        actions: _actions(taps),
        onDismiss: () => dismissed.add(1),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (taps, dismissed);
}

void main() {
  testWidgets('groups lead, primary and secondary actions with dividers', (
    tester,
  ) async {
    await _pump(tester);
    final ys = <double>[
      for (final label in <String>['AI 写作', '剪切', '复制', '粘贴', '全选', '查询'])
        tester.getCenter(find.text(label)).dy,
    ];
    expect(ys, orderedEquals(List<double>.of(ys)..sort()));
    final dividers = find.byType(Divider);
    expect(dividers, findsNWidgets(2));
    final first = tester.getCenter(dividers.first).dy;
    final second = tester.getCenter(dividers.last).dy;
    expect(first, inExclusiveRange(ys[0], ys[1]));
    expect(second, inExclusiveRange(ys[4], ys[5]));
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('opens with its top-left corner at the pointer', (tester) async {
    await _pump(tester);
    final panel = tester.getRect(
      find
          .ancestor(
            of: find.text('AI 写作'),
            matching: find.byType(IntrinsicWidth),
          )
          .first,
    );
    expect(panel.topLeft, const Offset(100, 200));
    expect(panel.width, inInclusiveRange(176, 320));
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('flips above the pointer near the bottom edge', (tester) async {
    await _pump(tester, anchor: const Offset(100, 590));
    final panel = tester.getRect(
      find
          .ancestor(
            of: find.text('AI 写作'),
            matching: find.byType(IntrinsicWidth),
          )
          .first,
    );
    expect(panel.bottom, lessThanOrEqualTo(590));
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('shows Ctrl shortcuts on Linux', (tester) async {
    await _pump(tester);
    expect(find.text('Ctrl+C'), findsOneWidget);
    expect(find.text('Ctrl+X'), findsOneWidget);
    expect(find.text('Ctrl+V'), findsOneWidget);
    expect(find.text('Ctrl+A'), findsOneWidget);
    // 行尾提示与文字在同一行。
    expect(
      tester.getCenter(find.text('Ctrl+C')).dy,
      moreOrLessEquals(tester.getCenter(find.text('复制')).dy, epsilon: 1),
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('shows command shortcuts on macOS', (tester) async {
    await _pump(tester);
    expect(find.text('⌘C'), findsOneWidget);
    expect(find.text('Ctrl+C'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('runs the tapped action', (tester) async {
    final (taps, _) = await _pump(tester);
    await tester.tap(find.text('粘贴'));
    await tester.pump();
    expect(taps.pressed, <String>['粘贴']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('arrow down moves the highlight and Enter runs it', (
    tester,
  ) async {
    final (taps, dismissed) = await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps.pressed, <String>['剪切']);
    expect(dismissed, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('the first arrow up highlights the last action', (tester) async {
    final (taps, _) = await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps.pressed, <String>['查询']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('Enter without a highlight reaches the text field', (
    tester,
  ) async {
    final (taps, _) = await _pump(tester);
    final handled = await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(handled, isFalse);
    expect(taps.pressed, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('Esc calls onDismiss', (tester) async {
    final (_, dismissed) = await _pump(tester);
    final handled = await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(handled, isTrue, reason: 'Esc must not reach the page');
    expect(dismissed, <int>[1]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}

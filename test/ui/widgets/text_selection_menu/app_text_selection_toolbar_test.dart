import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/widgets/text_selection_menu/app_text_context_menu.dart';

import 'text_selection_menu_test_app.dart';

const _middle = TextSelectionToolbarAnchors(
  primaryAnchor: Offset(180, 400),
  secondaryAnchor: Offset(180, 440),
);
const _top = TextSelectionToolbarAnchors(
  primaryAnchor: Offset(180, 30),
  secondaryAnchor: Offset(180, 60),
);

Future<TextMenuTaps> _pump(
  WidgetTester tester, {
  TextSelectionToolbarAnchors anchors = _middle,
  bool withSecondary = true,
  Size screen = const Size(360, 800),
}) async {
  setTextMenuScreen(tester, screen);
  final taps = TextMenuTaps();
  await tester.pumpWidget(
    textMenuTestApp(
      AppTextSelectionToolbar(
        anchors: anchors,
        actions: <AppTextMenuAction>[
          ...taps.editing(),
          if (withSecondary) ...<AppTextMenuAction>[
            taps.action(
              '分享',
              icon: FontAwesomeIcons.shareNodes,
              slot: AppTextMenuSlot.secondary,
            ),
            taps.action(
              '翻译',
              icon: FontAwesomeIcons.arrowUpRightFromSquare,
              slot: AppTextMenuSlot.secondary,
            ),
          ],
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
  return taps;
}

/// 点「更多 / 收起」：两种文字叠在同一个按钮里，点按钮本身而不是某一层文字。
Future<void> _toggleMore(WidgetTester tester) async {
  await tester.tap(
    find.ancestor(of: find.text('更多'), matching: find.byType(TextButton)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lays out primary actions in their original order', (
    tester,
  ) async {
    await _pump(tester);
    final xs = <double>[
      for (final label in <String>['剪切', '复制', '粘贴', '全选', '更多'])
        tester.getCenter(find.text(label)).dx,
    ];
    expect(xs, orderedEquals(List<double>.of(xs)..sort()));
    // 次要项收起时不在树里。
    expect(find.text('分享'), findsNothing);
  });

  testWidgets('places lead actions after the primary ones on the main row', (
    tester,
  ) async {
    setTextMenuScreen(tester);
    final taps = TextMenuTaps();
    await tester.pumpWidget(
      textMenuTestApp(
        AppTextSelectionToolbar(
          anchors: _middle,
          actions: <AppTextMenuAction>[
            // 调用方把 lead 写在最前，主行仍排在编辑类之后。
            taps.action(
              'AI',
              icon: FontAwesomeIcons.wandMagicSparkles,
              slot: AppTextMenuSlot.lead,
            ),
            ...taps.editing(),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final xs = <double>[
      for (final label in <String>['剪切', '复制', '粘贴', '全选', 'AI'])
        tester.getCenter(find.text(label)).dx,
    ];
    expect(xs, orderedEquals(List<double>.of(xs)..sort()));
  });

  testWidgets('moves the lead action into the overflow first when narrow', (
    tester,
  ) async {
    setTextMenuScreen(tester, const Size(320, 800));
    final taps = TextMenuTaps();
    await tester.pumpWidget(
      textMenuTestApp(
        AppTextSelectionToolbar(
          anchors: _middle,
          actions: <AppTextMenuAction>[
            taps.action(
              'AI 写作',
              icon: FontAwesomeIcons.wandMagicSparkles,
              slot: AppTextMenuSlot.lead,
            ),
            ...taps.editing(),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    // 可用宽 320 − 16 = 304：四项编辑类 + 「更多」要 288 放得下，五项全放要
    // 308 以上放不下，最后的 AI 先进「更多」。
    expect(find.text('全选'), findsOneWidget);
    expect(find.text('AI 写作'), findsNothing);
    expect(find.text('更多'), findsOneWidget);
    await _toggleMore(tester);
    expect(find.text('AI 写作'), findsOneWidget);
  });

  testWidgets('shows no more button without secondary actions', (tester) async {
    await _pump(tester, withSecondary: false);
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('更多'), findsNothing);
    expect(find.text('收起'), findsNothing);
  });

  testWidgets('moves trailing primary actions into the overflow when narrow', (
    tester,
  ) async {
    await _pump(
      tester,
      withSecondary: false,
      // 可用宽 230 − 16 = 214：四项不带「更多」要 232，只留得下两项。
      screen: const Size(230, 800),
    );
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('粘贴'), findsNothing);
    expect(find.text('全选'), findsNothing);
    expect(find.text('更多'), findsOneWidget);
    await _toggleMore(tester);
    // 挪出去的项按原顺序排在次要区最前面。
    final paste = tester.getRect(find.text('粘贴'));
    final selectAll = tester.getRect(find.text('全选'));
    expect(paste.left, lessThan(selectAll.left));
  });

  testWidgets('expands and collapses the secondary area', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    expect(
      tester.getSemantics(find.bySemanticsLabel('更多')),
      isSemantics(hasExpandedState: true, isExpanded: false),
    );

    await _toggleMore(tester);
    expect(find.text('分享'), findsOneWidget);
    expect(find.text('翻译'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('收起')),
      isSemantics(hasExpandedState: true, isExpanded: true),
    );

    await _toggleMore(tester);
    expect(find.text('分享'), findsNothing);
    semantics.dispose();
  });

  testWidgets(
    'collapses when the collapse scope changes without replaying the entrance',
    (tester) async {
      setTextMenuScreen(tester);
      final taps = TextMenuTaps();
      Widget toolbar(Object scope) => textMenuTestApp(
        AppTextSelectionToolbar(
          anchors: _middle,
          collapseScope: scope,
          actions: <AppTextMenuAction>[
            ...taps.editing(),
            taps.action(
              '分享',
              icon: FontAwesomeIcons.shareNodes,
              slot: AppTextMenuSlot.secondary,
            ),
          ],
        ),
      );
      await tester.pumpWidget(toolbar(1));
      await tester.pumpAndSettle();
      final state = tester.state(find.byType(AppTextSelectionToolbar));
      await _toggleMore(tester);
      expect(find.text('分享'), findsOneWidget);

      // 同一个范围重建：展开态保留。
      await tester.pumpWidget(toolbar(1));
      await tester.pump();
      expect(find.text('分享'), findsOneWidget);

      // 范围变了：立即收起，胶囊仍是同一个、入场缩放停在 1 不重播。
      await tester.pumpWidget(toolbar(2));
      await tester.pump();
      expect(find.text('分享'), findsNothing);
      expect(find.text('更多'), findsOneWidget);
      expect(tester.state(find.byType(AppTextSelectionToolbar)), same(state));
      final scale = tester.widget<ScaleTransition>(
        find.descendant(
          of: find.byType(AppTextSelectionToolbar),
          matching: find.byType(ScaleTransition),
        ),
      );
      expect(scale.scale.value, 1);
    },
  );

  testWidgets('calls onPressed of the tapped action', (tester) async {
    final taps = await _pump(tester);
    await tester.tap(find.text('复制'));
    await _toggleMore(tester);
    await tester.tap(find.text('分享'));
    expect(taps.pressed, <String>['复制', '分享']);
  });

  testWidgets('grows the secondary area upwards above the selection', (
    tester,
  ) async {
    await _pump(tester);
    final rowBefore = tester.getRect(find.text('复制'));
    await _toggleMore(tester);
    final row = tester.getRect(find.text('复制'));
    // 主行原地不动，次要区在主行之上，整张卡片仍在选区上方。
    expect(row.top, rowBefore.top);
    expect(tester.getRect(find.text('分享')).bottom, lessThan(row.top));
    expect(row.bottom, lessThan(_middle.primaryAnchor.dy));
  });

  testWidgets('grows the secondary area downwards below the selection', (
    tester,
  ) async {
    await _pump(tester, anchors: _top);
    final rowBefore = tester.getRect(find.text('复制'));
    expect(rowBefore.top, greaterThan(_top.secondaryAnchor!.dy));
    await _toggleMore(tester);
    final row = tester.getRect(find.text('复制'));
    expect(row.top, rowBefore.top);
    expect(tester.getRect(find.text('分享')).top, greaterThan(row.bottom));
  });

  testWidgets('renders nothing without actions', (tester) async {
    setTextMenuScreen(tester);
    await tester.pumpWidget(
      textMenuTestApp(
        const AppTextSelectionToolbar(
          anchors: _middle,
          actions: <AppTextMenuAction>[],
        ),
      ),
    );
    expect(find.byType(TextButton), findsNothing);
  });
}

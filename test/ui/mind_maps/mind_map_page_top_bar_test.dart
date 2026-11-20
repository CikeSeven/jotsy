import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/mind_map/mind_map_document.dart';
import 'package:node_diary/core/database/mind_map/mind_map_text.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/mind_maps/pages/mind_map_editor_page.dart';
import 'package:node_diary/ui/mind_maps/pages/mind_map_viewer_page.dart';
import 'package:node_diary/ui/mind_maps/widgets/mind_map_canvas.dart';
import 'package:node_diary/ui/mind_maps/widgets/mind_map_outline_view.dart';
import 'package:node_diary/ui/mind_maps/widgets/mind_map_view_switch.dart';
import 'package:node_diary/ui/widgets/floating_top_bar/floating_action_island.dart';
import 'package:node_diary/ui/widgets/floating_top_bar/floating_island.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';

/// 导图页的浮岛顶栏：不显示导图名，中间是“画布 / 大纲”两个图标的切换岛；
/// 拖动画布时顶栏收起、点空白处浮出；窄到中间放不下切换岛时改进“更多”。
void main() {
  final map = MindMapDocument.blank().copyWith(
    root: mindMapNodeFromOutline('Plan\n  Work\n  Rest')!,
  );

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    double width = 400,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget editor() => MindMapEditorPage(document: map, onChanged: (_) {});

  /// 返回岛的上沿：收起时整行移出屏幕（< 0）。
  double backIslandTop(WidgetTester tester) =>
      tester.getTopLeft(find.byType(FloatingBackIsland)).dy;

  testWidgets('the top bar has a two-icon view switch and no map title', (
    tester,
  ) async {
    await pumpPage(tester, editor());
    expect(find.byType(MindMapViewSwitch), findsOneWidget);
    // 岛就是两格的宽度，不被中间的空位撑开。
    expect(
      tester.getSize(find.byType(MindMapViewSwitch)).width,
      MindMapViewSwitch.width,
    );
    // 与右边的动作胶囊之间留着空隙，不贴在一起。
    expect(
      tester.getTopLeft(find.byType(FloatingActionIsland)).dx -
          tester.getTopRight(find.byType(MindMapViewSwitch)).dx,
      greaterThanOrEqualTo(8),
    );
    expect(find.byType(FloatingIslandLabel), findsNothing);
    // 导图名（中心主题）不再以文字出现在顶栏里（画布上的字是画出来的）。
    expect(find.text('Plan'), findsNothing);
    expect(find.byType(MindMapCanvas), findsOneWidget);

    await tester.tap(find.byTooltip('Outline'));
    await tester.pumpAndSettle();
    expect(find.byType(MindMapOutlineView), findsOneWidget);
    expect(find.byType(MindMapCanvas), findsNothing);

    await tester.tap(find.byTooltip('Map'));
    await tester.pumpAndSettle();
    expect(find.byType(MindMapCanvas), findsOneWidget);
  });

  testWidgets('dragging the canvas hides the top bar and tapping blank space '
      'brings it back', (tester) async {
    await pumpPage(tester, editor());
    expect(backIslandTop(tester), greaterThan(0));

    await tester.drag(find.byType(MindMapCanvas), const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(backIslandTop(tester), lessThan(0));

    // 左边缘、画面中部：导图在中间往右长，这里是空白。
    await tester.tapAt(const Offset(16, 300));
    await tester.pumpAndSettle();
    expect(backIslandTop(tester), greaterThan(0));
  });

  testWidgets('the read-only viewer has the switch but no undo or redo', (
    tester,
  ) async {
    await pumpPage(tester, MindMapViewerPage(document: map));
    expect(find.byType(MindMapViewSwitch), findsOneWidget);
    expect(find.byTooltip('Undo'), findsNothing);
  });

  testWidgets('a bar too narrow for the switch moves it into the more menu', (
    tester,
  ) async {
    await pumpPage(tester, editor(), width: 300);
    expect(find.byType(MindMapViewSwitch), findsNothing);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Outline'));
    await tester.pumpAndSettle();
    expect(find.byType(MindMapOutlineView), findsOneWidget);

    // 菜单里那一项跟着当前视图变成“回到画布”。
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Outline'), findsNothing);
    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expect(find.byType(MindMapCanvas), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/mind_map/mind_map_document.dart';
import 'package:node_diary/core/database/mind_map/mind_map_ops.dart';
import 'package:node_diary/core/database/mind_map/mind_map_schema.dart';
import 'package:node_diary/core/database/mind_map/mind_map_text.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/mind_maps/controllers/mind_map_editing_controller.dart';
import 'package:node_diary/ui/mind_maps/models/mind_map_options.dart';
import 'package:node_diary/ui/mind_maps/widgets/mind_map_workspace.dart';

import '../../support/expressive_test_theme.dart';

/// 平衡结构里指定分支在哪一侧：选中中心主题时工具坞与键盘附件条的子主题 /
/// 同级换成向左 / 向右添加，加的时候已有分支按画布上的位置固定、不换边；
/// 其他结构与其他主题照旧是子主题 / 同级。
void main() {
  /// 中心主题下四个一样高的分支：自动分配时 A、B 在右，C、D 在左。
  MindMapDocument fourBranches({MindMapStructure? structure}) {
    final document = MindMapOps.replaceRoot(
      MindMapDocument.blank(),
      mindMapNodeFromOutline('Plan\n  A\n  B\n  C\n  D')!,
    );
    return structure == null
        ? document
        : document.copyWith(structure: structure.id);
  }

  Future<void> pumpHost(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pump();
  }

  Map<String, String?> sidesByText(MindMapDocument document) =>
      <String, String?>{
        for (final child in document.root.children) child.text: child.side,
      };

  testWidgets('with the central topic selected the dock adds a branch on the '
      'chosen side and every existing branch stays where it was', (
    tester,
  ) async {
    final controller = MindMapEditingController(fourBranches());
    addTearDown(controller.dispose);
    await pumpHost(tester, MindMapWorkspace(controller: controller));

    controller.select(controller.document.root.id);
    await tester.pumpAndSettle();
    expect(find.text('Add left'), findsOneWidget);
    expect(find.text('Add right'), findsOneWidget);
    expect(find.text('Subtopic'), findsNothing);
    expect(find.text('Sibling'), findsNothing);

    await tester.tap(find.text('Add left'));
    await tester.pump();
    final added = controller.selectedId!;
    expect(controller.editingId, added);
    expect(controller.document.index.parentOf(added), 'root');
    expect(controller.document.index[added]!.side, kMindMapSideLeft);
    // 已有分支按画布上的位置固定下来，不会被新分支挤到另一边。
    expect(sidesByText(controller.document), <String, String?>{
      'A': kMindMapSideRight,
      'B': kMindMapSideRight,
      'C': kMindMapSideLeft,
      'D': kMindMapSideLeft,
      '': kMindMapSideLeft,
    });
  });

  testWidgets('editing the central topic, the keyboard bar offers both sides; '
      'other topics keep subtopic and sibling', (tester) async {
    final controller = MindMapEditingController(fourBranches());
    addTearDown(controller.dispose);
    await pumpHost(tester, MindMapWorkspace(controller: controller));

    controller.startEditing(controller.document.root.id);
    await tester.pump();
    await tester.pump();
    expect(find.text('Add left'), findsOneWidget);
    await tester.tap(find.text('Add right'));
    await tester.pump();
    await tester.pump();
    final added = controller.editingId!;
    expect(controller.document.index[added]!.side, kMindMapSideRight);
    // 正在编辑的已是新分支（不是中心主题）：回到子主题 / 同级。
    expect(find.text('Add right'), findsNothing);
    expect(find.text('Subtopic'), findsOneWidget);
    expect(find.text('Sibling'), findsOneWidget);
  });

  testWidgets('the outline has no left or right, so the central topic keeps '
      'subtopic and sibling there', (tester) async {
    final controller = MindMapEditingController(fourBranches());
    addTearDown(controller.dispose);
    await pumpHost(tester, MindMapWorkspace(controller: controller));

    controller.outlineView = true;
    controller.select(controller.document.root.id);
    await tester.pumpAndSettle();
    expect(find.text('Add left'), findsNothing);
    expect(find.text('Subtopic'), findsOneWidget);
    expect(find.text('Sibling'), findsOneWidget);
  });

  testWidgets('other structures keep subtopic and sibling on the central '
      'topic', (tester) async {
    final controller = MindMapEditingController(
      fourBranches(structure: MindMapStructure.logicRight),
    );
    addTearDown(controller.dispose);
    await pumpHost(tester, MindMapWorkspace(controller: controller));

    controller.select(controller.document.root.id);
    await tester.pumpAndSettle();
    expect(find.text('Add left'), findsNothing);
    expect(find.text('Subtopic'), findsOneWidget);
    await tester.tap(find.text('Subtopic'));
    await tester.pump();
    // 不是平衡结构：不固定任何一侧。
    expect(
      controller.document.root.children.every((node) => node.side == null),
      isTrue,
    );
  });
}

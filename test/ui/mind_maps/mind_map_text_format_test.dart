import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/mind_map/mind_map_document.dart';
import 'package:node_diary/core/database/mind_map/mind_map_ops.dart';
import 'package:node_diary/core/database/mind_map/mind_map_rich_text.dart';
import 'package:node_diary/core/database/mind_map/mind_map_text.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_panel.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_swatch.dart';
import 'package:node_diary/ui/mind_maps/controllers/mind_map_editing_controller.dart';
import 'package:node_diary/ui/mind_maps/layout/mind_map_layout.dart';
import 'package:node_diary/ui/mind_maps/layout/mind_map_text_cache.dart';
import 'package:node_diary/ui/mind_maps/models/mind_map_options.dart';
import 'package:node_diary/ui/mind_maps/models/mind_map_themes.dart';
import 'package:node_diary/ui/mind_maps/sections/mind_map_node_sheets.dart';
import 'package:node_diary/ui/mind_maps/viewmodels/mind_map_palette.dart';
import 'package:node_diary/ui/mind_maps/viewmodels/mind_map_visuals.dart';
import 'package:node_diary/ui/mind_maps/widgets/mind_map_dock.dart';
import 'package:node_diary/ui/mind_maps/widgets/mind_map_format_bar.dart';
import 'package:node_diary/ui/mind_maps/widgets/mind_map_outline_view.dart';
import 'package:node_diary/ui/mind_maps/widgets/mind_map_workspace.dart';

import '../../support/expressive_test_theme.dart';

/// 主题文字的局部样式与键盘附件条：格式条按选区设粗体 / 颜色、没选字时设
/// 接下来打的字、附件条删除主题、主题样式面板的下划线与高亮、大纲里改字
/// 样式不错位、桌面快捷键与格式条替换工具坞，以及排版按局部样式测量。
void main() {
  MindMapDocument tree() => MindMapOps.replaceRoot(
    MindMapDocument.blank(),
    // 一级主题本身就是半粗（w600，格式条按“已是粗体”算），局部样式的
    // 例子都放在二级主题上。
    mindMapNodeFromOutline('Plan\n  Topic\n    Alpha Beta\n    Gamma')!,
  );

  String idOf(MindMapDocument document, String text) => document.index.preorder
      .firstWhere((id) => document.index[id]!.text == text);

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
  }

  Future<String> startEditing(
    WidgetTester tester,
    MindMapEditingController controller,
    String text,
  ) async {
    final id = idOf(controller.document, text);
    controller.startEditing(id);
    await tester.pump();
    await tester.pump();
    expect(controller.textSession.current, isNotNull);
    return id;
  }

  Finder tooltip(String message) => find.byTooltip(message);

  testWidgets('selected characters get bold from the format bar; tapping '
      'again turns it off', (tester) async {
    final controller = MindMapEditingController(tree());
    addTearDown(controller.dispose);
    await pumpHost(tester, MindMapWorkspace(controller: controller));
    final id = await startEditing(tester, controller, 'Alpha Beta');
    expect(find.byType(MindMapFormatBar), findsOneWidget);

    controller.textSession.current!.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 5,
    );
    await tester.pump();
    await tester.tap(tooltip('Bold'));
    await tester.pump();
    expect(mindMapRunsOf(controller.document.index[id]!), <MindMapTextRun>[
      const MindMapTextRun('Alpha', MindMapTextMarks(bold: true)),
      const MindMapTextRun(' Beta'),
    ]);
    expect(controller.editingId, id);

    await tester.tap(tooltip('Bold'));
    await tester.pump();
    expect(controller.document.index[id]!.delta, isNull);
  });

  testWidgets('with only a caret the format applies to what is typed next', (
    tester,
  ) async {
    final controller = MindMapEditingController(tree());
    addTearDown(controller.dispose);
    await pumpHost(tester, MindMapWorkspace(controller: controller));
    final id = await startEditing(tester, controller, 'Gamma');
    await tester.tap(tooltip('Underline'));
    await tester.pump();
    expect(controller.document.index[id]!.delta, isNull);

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Gamma!',
        selection: TextSelection.collapsed(offset: 6),
      ),
    );
    await tester.pump();
    expect(
      mindMapRunsOf(controller.document.index[id]!).last,
      const MindMapTextRun('!', MindMapTextMarks(underline: true)),
    );
  });

  testWidgets('text color opens the same color panel as the diary editor; '
      'a preset colors the selection and the custom code keeps editing', (
    tester,
  ) async {
    final controller = MindMapEditingController(tree());
    addTearDown(controller.dispose);
    await pumpHost(tester, MindMapWorkspace(controller: controller));
    final id = await startEditing(tester, controller, 'Alpha Beta');
    controller.textSession.current!.selection = const TextSelection(
      baseOffset: 6,
      extentOffset: 10,
    );
    await tester.pump();
    await tester.tap(tooltip('Text color'));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryColorPanel), findsOneWidget);
    expect(controller.textSession.panelExtent.value, greaterThan(0));
    final swatches = find.descendant(
      of: find.byType(DiaryColorPanel),
      matching: find.byType(DiaryColorSwatch),
    );
    // 默认 + 全部预设 + 我的颜色一行的格子。
    expect(
      swatches.evaluate().length,
      greaterThan(DiaryColorPreset.values.length),
    );
    await tester.tap(swatches.at(1));
    await tester.pump();
    var runs = mindMapRunsOf(controller.document.index[id]!);
    expect(runs.last.text, 'Beta');
    expect(
      runs.last.marks.color,
      encodeDiaryColor(
        DiaryColorPreset.values.first.colorFor(DiaryColorTarget.text),
      ),
    );
    expect(controller.editingId, id);
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byType(MindMapWorkspace),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.controller == controller.textSession.current,
        ),
      ),
    );
    expect(field.focusNode!.hasFocus, isTrue);

    // 自定义页的颜色代码输入框拿走焦点时不结束编辑，应用后焦点回到主题。
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    final hex = find.descendant(
      of: find.byType(DiaryColorPanel),
      matching: find.byType(TextField),
    );
    await tester.tap(hex);
    await tester.pump();
    expect(controller.editingId, id);
    await tester.enterText(hex, '00897B');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    runs = mindMapRunsOf(controller.document.index[id]!);
    expect(runs.last.marks.color, '#FF00897B');
    expect(controller.editingId, id);

    // 再点一次收起面板。
    await tester.tap(tooltip('Text color'));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryColorPanel), findsNothing);
    expect(controller.textSession.panelExtent.value, 0);
  });

  testWidgets('the keyboard bar deletes the topic being edited and goes on '
      'editing the next one without hiding the keyboard; the central topic '
      'cannot be deleted', (tester) async {
    final controller = MindMapEditingController(tree());
    addTearDown(controller.dispose);
    await pumpHost(tester, MindMapWorkspace(controller: controller));
    final gamma = await startEditing(tester, controller, 'Gamma');
    expect(tester.testTextInput.isVisible, isTrue);
    tester.testTextInput.log.clear();
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump();
    expect(controller.document.index.contains(gamma), isFalse);
    final alpha = idOf(controller.document, 'Alpha Beta');
    expect(controller.selectedId, alpha);
    expect(controller.editingId, alpha);
    expect(controller.textSession.current?.text, 'Alpha Beta');
    expect(
      tester.testTextInput.log.map((call) => call.method),
      isNot(contains('TextInput.hide')),
    );
    expect(tester.testTextInput.isVisible, isTrue);

    controller.startEditing(controller.document.root.id);
    await tester.pump();
    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(controller.document.index.length, 3);
    expect(controller.editingId, controller.document.root.id);

    // 撤销把删掉的主题找回来。
    controller.undo();
    expect(controller.document.index.contains(gamma), isTrue);
  });

  testWidgets('the outline bar can delete too and outline edits keep marks '
      'on their characters', (tester) async {
    var document = tree();
    final alpha = idOf(document, 'Alpha Beta');
    document = MindMapOps.formatText(
      document,
      alpha,
      0,
      5,
      (marks) => marks.withFlag(MindMapMark.bold, true),
    );
    final controller = MindMapEditingController(document);
    addTearDown(controller.dispose);
    await pumpHost(tester, MindMapOutlineView(controller: controller));
    final rich = tester.widget<RichText>(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText() == 'Alpha Beta',
      ),
    );
    TextSpan? bold;
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text == 'Alpha') bold = span;
      return bold == null;
    });
    expect(bold?.style?.fontWeight, FontWeight.w700);

    await tester.tap(find.text('Alpha Beta'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Alpha Beta Delta');
    await tester.pump();
    expect(mindMapRunsOf(controller.document.index[alpha]!), <MindMapTextRun>[
      const MindMapTextRun('Alpha', MindMapTextMarks(bold: true)),
      const MindMapTextRun(' Beta Delta'),
    ]);
  });

  testWidgets('topic style sheet: underline and highlight cover the whole '
      'topic and drop the same local marks', (tester) async {
    var document = tree();
    final alpha = idOf(document, 'Alpha Beta');
    document = MindMapOps.formatText(
      document,
      alpha,
      0,
      5,
      (marks) => marks
          .withFlag(MindMapMark.underline, true)
          .withFlag(MindMapMark.bold, true),
    );
    final controller = MindMapEditingController(document);
    addTearDown(controller.dispose);
    final spec = MindMapThemeSpec.of(MindMapThemeId.follow);
    final palette = MindMapPalette.of(
      spec,
      ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
    );
    await pumpHost(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              showMindMapNodeStyleSheet(context, controller, alpha, palette),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(tooltip('Underline'));
    await tester.pumpAndSettle();
    await tester.tap(tooltip('Underline'));
    await tester.pump();
    var node = controller.document.index[alpha]!;
    expect(node.style['underline'], isTrue);
    expect(mindMapRunsOf(node).first.marks, const MindMapTextMarks(bold: true));

    // 文字高亮：切到“高亮”再点第一个预设，整条生效。
    await tester.ensureVisible(find.text('Highlight'));
    await tester.tap(find.text('Highlight'));
    await tester.pumpAndSettle();
    final swatches = find.descendant(
      of: find.byType(DiaryColorPanel),
      matching: find.byType(DiaryColorSwatch),
    );
    await tester.ensureVisible(swatches.at(1));
    await tester.tap(swatches.at(1));
    await tester.pump();
    node = controller.document.index[alpha]!;
    expect(
      node.style['highlight'],
      encodeDiaryColor(
        DiaryColorPreset.values.first.colorFor(DiaryColorTarget.background),
      ),
    );
  });

  testWidgets('desktop: Ctrl + B bolds the selection and the format bar '
      'takes the dock\'s place while editing', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final controller = MindMapEditingController(tree());
    addTearDown(controller.dispose);
    await pumpHost(tester, MindMapWorkspace(controller: controller));
    expect(find.byType(MindMapDock), findsOneWidget);
    final id = await startEditing(tester, controller, 'Gamma');
    expect(find.byType(MindMapDock), findsNothing);
    expect(find.byType(MindMapFormatBar), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    // 桌面上进入编辑时全选：整段加粗。
    expect(mindMapRunsOf(controller.document.index[id]!), <MindMapTextRun>[
      const MindMapTextRun('Gamma', MindMapTextMarks(bold: true)),
    ]);
    expect(controller.editingId, id);
    debugDefaultTargetPlatformOverride = null;
  });

  test('layout lays out local marks as styled runs and strikes a done task '
      'through as a whole', () {
    final texts = MindMapTextCache();
    addTearDown(texts.dispose);
    final spec = MindMapThemeSpec.of(MindMapThemeId.follow);
    final config = MindMapLayoutConfig(
      structure: MindMapStructure.logicRight,
      spacing: MindMapSpacing.standard,
      line: MindMapLineStyle.curve,
      styles: MindMapStyleResolver(
        spec: spec,
        palette: MindMapPalette.of(
          spec,
          ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
        ),
        rainbow: false,
        baseText: const TextStyle(fontSize: 14),
      ),
      texts: texts,
      rootPlaceholder: 'Central',
      nodePlaceholder: 'Topic',
    );
    var document = tree();
    final gamma = idOf(document, 'Gamma');
    final plain = layoutMindMap(document, config).byId[gamma]!;
    document = MindMapOps.formatText(
      document,
      gamma,
      0,
      5,
      (marks) => marks.withFlag(MindMapMark.bold, true),
    );
    final bold = layoutMindMap(document, config).byId[gamma]!;
    // 测试字体里粗体不变宽：比的是排版用的片段，而不是宽度。
    expect((plain.text.text! as TextSpan).children, isNull);
    final boldRun = (bold.text.text! as TextSpan).children!.single as TextSpan;
    expect(boldRun.style!.fontWeight, FontWeight.w700);

    document = MindMapOps.updateNode(
      document,
      gamma,
      (node) => node.copyWith(task: <String, Object?>{'done': true}),
    );
    final done = layoutMindMap(document, config).byId[gamma]!;
    final span = done.text.text! as TextSpan;
    expect(
      span.style!.decoration!.contains(TextDecoration.lineThrough),
      isTrue,
    );
    final run = span.children!.single as TextSpan;
    expect(
      run.style!.decoration?.contains(TextDecoration.lineThrough) ?? true,
      isTrue,
    );
  });
}

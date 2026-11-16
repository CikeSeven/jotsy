import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/mind_map/mind_map_document.dart';
import 'package:node_diary/core/database/mind_map/mind_map_ops.dart';
import 'package:node_diary/core/database/mind_map/mind_map_text.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/mind_maps/controllers/mind_map_clipboard.dart';
import 'package:node_diary/ui/mind_maps/controllers/mind_map_editing_controller.dart';
import 'package:node_diary/ui/mind_maps/layout/mind_map_layout.dart';
import 'package:node_diary/ui/mind_maps/layout/mind_map_node_content.dart';
import 'package:node_diary/ui/mind_maps/layout/mind_map_text_cache.dart';
import 'package:node_diary/ui/mind_maps/models/mind_map_markers.dart';
import 'package:node_diary/ui/mind_maps/models/mind_map_options.dart';
import 'package:node_diary/ui/mind_maps/models/mind_map_themes.dart';
import 'package:node_diary/ui/mind_maps/viewmodels/mind_map_frame.dart';
import 'package:node_diary/ui/mind_maps/viewmodels/mind_map_hit_test.dart';
import 'package:node_diary/ui/mind_maps/viewmodels/mind_map_palette.dart';
import 'package:node_diary/ui/mind_maps/viewmodels/mind_map_visuals.dart';
import 'package:node_diary/ui/mind_maps/widgets/mind_map_outline_view.dart';

import '../../support/expressive_test_theme.dart';

/// 富节点与大纲：贴纸的同组互斥、节点内容排版与可点的部件、待办与进度、
/// 缩进 / 取消缩进 / 上下移、复制粘贴，以及大纲视图的编辑。
void main() {
  MindMapDocument tree() => MindMapOps.replaceRoot(
    MindMapDocument.blank(),
    mindMapNodeFromOutline('Plan\n  A\n    A1\n    A2\n  B\n  C')!,
  );

  String idOf(MindMapDocument document, String text) => document.index.preorder
      .firstWhere((id) => document.index[id]!.text == text);

  group('outline operations', () {
    test('indent, outdent and shift keep everything else in place', () {
      final document = tree();
      final b = idOf(document, 'B');
      final indented = MindMapOps.indent(document, b);
      expect(indented.index.parentOf(b), idOf(document, 'A'));
      expect(indented.index.positionOf(b), 2);
      final back = MindMapOps.outdent(indented, b);
      expect(back.index.parentOf(b), back.root.id);
      expect(back.index.positionOf(b), 1);
      // 第一个子主题没有前一个同级：缩进不动；根下的主题不能取消缩进。
      final a1 = idOf(document, 'A1');
      expect(identical(MindMapOps.indent(document, a1), document), isTrue);
      expect(identical(MindMapOps.outdent(document, b), document), isTrue);
      final down = MindMapOps.shift(document, b, up: false);
      expect(down.root.children.map((n) => n.text), ['A', 'C', 'B']);
      final up = MindMapOps.shift(document, b, up: true);
      expect(up.root.children.map((n) => n.text), ['B', 'A', 'C']);
    });

    test('pasted lines become sibling subtrees at the shallowest indent', () {
      final nodes = mindMapNodesFromOutline('One\n  Two\nThree\n\n- Four');
      expect(nodes.map((n) => n.text), ['One', 'Three', 'Four']);
      expect(nodes.first.children.single.text, 'Two');
      final document = tree();
      final outline = mindMapSubtreeOutline(
        document.index[idOf(document, 'A')]!,
      );
      expect(outline, 'A\n- A1\n- A2');
    });
  });

  group('stickers', () {
    test('one per group, toggling again removes it, emojis can repeat', () {
      final p1 = MindMapMarker.parse('priority:1')!;
      final p2 = MindMapMarker.parse('priority:2')!;
      final flag = MindMapMarker.parse('flag:red')!;
      var icons = MindMapMarker.toggle(const <String>[], p1);
      icons = MindMapMarker.toggle(icons, flag);
      icons = MindMapMarker.toggle(icons, p2);
      expect(icons, ['flag:red', 'priority:2']);
      icons = MindMapMarker.toggle(icons, p2);
      expect(icons, ['flag:red']);
      final smile = MindMapMarker.parse('emoji:🙂')!;
      final party = MindMapMarker.parse('emoji:🎉')!;
      icons = MindMapMarker.toggle(MindMapMarker.toggle(icons, smile), party);
      expect(icons, ['flag:red', 'emoji:🙂', 'emoji:🎉']);
      expect(MindMapMarker.parse('nope'), isNull);
      expect(MindMapMarker.parse('flag:pink'), isNull);
    });
  });

  group('node content', () {
    final texts = MindMapTextCache();
    tearDownAll(texts.dispose);

    MindMapLayoutConfig config() {
      final spec = MindMapThemeSpec.of(MindMapThemeId.follow);
      return MindMapLayoutConfig(
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
    }

    test('checkbox, stickers, note, link and labels get their own room '
        'and can be hit', () {
      var document = tree();
      final a1 = idOf(document, 'A1');
      final a2 = idOf(document, 'A2');
      final plain = layoutMindMap(document, config()).byId[a1]!;
      document = MindMapOps.updateNode(
        document,
        a1,
        (n) => n.copyWith(
          task: <String, Object?>{'done': true},
          icons: <String>['priority:1', 'star:blue'],
          note: 'call',
          href: 'https://example.com',
          labels: <String>['now'],
        ),
      );
      document = MindMapOps.updateNode(
        document,
        a2,
        (n) => n.copyWith(task: <String, Object?>{'done': false}),
      );
      final scene = layoutMindMap(document, config());
      final rich = scene.byId[a1]!;
      final content = rich.content;
      expect(rich.rect.width, greaterThan(plain.rect.width));
      expect(rich.rect.height, greaterThan(plain.rect.height));
      expect(content.checkbox, isNotNull);
      expect(content.markers, hasLength(2));
      expect(content.note, isNotNull);
      expect(content.link, isNotNull);
      expect(content.labels, hasLength(1));
      expect(content.taskDone, isTrue);
      // 父主题显示子孙待办的完成情况。
      final parent = scene.byId[idOf(document, 'A')]!.content.progress;
      expect((parent?.done, parent?.total), (1, 2));
      final frame = MindMapFrame.still(scene);
      expect(
        hitTestMindMap(frame, rich.rect.topLeft + content.checkbox!.center),
        isA<MindMapPartHit>().having(
          (hit) => hit.part,
          'part',
          MindMapNodePart.checkbox,
        ),
      );
      expect(
        hitTestMindMap(frame, rich.rect.topLeft + content.note!.center),
        isA<MindMapPartHit>().having(
          (hit) => hit.part,
          'part',
          MindMapNodePart.note,
        ),
      );
      expect(
        hitTestMindMap(frame, rich.rect.topLeft + content.textRect.center),
        isA<MindMapNodeHit>(),
      );
    });

    test('toggling a task and coalescing a note edit', () {
      final controller = MindMapEditingController(tree());
      final b = idOf(controller.document, 'B');
      controller.updateNode(
        b,
        (n) => n.copyWith(task: <String, Object?>{'done': false}),
      );
      controller.toggleTask(b);
      expect(controller.document.index[b]!.taskDone, isTrue);
      controller.updateNode(b, (n) => n.copyWith(note: 'a'), coalesce: 'n');
      controller.updateNode(b, (n) => n.copyWith(note: 'ab'), coalesce: 'n');
      controller.undo();
      expect(controller.document.index[b]!.note, isNull);
      expect(controller.document.index[b]!.taskDone, isTrue);
      controller.dispose();
    });
  });

  test('copy and paste bring back the whole subtree; foreign text becomes '
      'topics', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    String? clip;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clip = (call.arguments as Map)['text'] as String?;
            return null;
          }
          if (call.method == 'Clipboard.getData') {
            return <String, Object?>{'text': clip};
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    var document = tree();
    final a = idOf(document, 'A');
    document = MindMapOps.updateNode(
      document,
      a,
      (n) => n.copyWith(icons: <String>['star:red']),
    );
    final controller = MindMapEditingController(document);
    await MindMapClipboard.copy(controller.document, a);
    expect(clip, 'A\n- A1\n- A2');
    controller.select(idOf(controller.document, 'C'));
    expect(await MindMapClipboard.paste(controller), isTrue);
    final pasted = controller.document.index[controller.selectedId!]!;
    expect(pasted.icons, ['star:red']);
    expect(pasted.children.map((n) => n.text), ['A1', 'A2']);
    clip = 'X\nY';
    controller.select(controller.document.root.id);
    expect(await MindMapClipboard.paste(controller), isTrue);
    expect(controller.document.root.children.map((n) => n.text), [
      'A',
      'B',
      'C',
      'X',
      'Y',
    ]);
    controller.dispose();
  });

  testWidgets('outline view: tap edits a row, Enter adds a sibling, '
      'collapsing hides children', (tester) async {
    final controller = MindMapEditingController(tree());
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MindMapOutlineView(controller: controller)),
        ),
      ),
    );
    expect(find.text('A1'), findsOneWidget);
    await tester.tap(find.text('B'));
    await tester.pump();
    final b = idOf(controller.document, 'B');
    expect(controller.editingId, b);
    await tester.enterText(find.byType(TextField), 'Bee');
    await tester.pump();
    expect(controller.document.index[b]!.text, 'Bee');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(controller.document.root.children.map((n) => n.text), [
      'A',
      'Bee',
      '',
      'C',
    ]);
    controller.stopEditing();
    controller.toggleCollapsed(idOf(controller.document, 'A'));
    await tester.pump();
    expect(find.text('A1'), findsNothing);
  });
}

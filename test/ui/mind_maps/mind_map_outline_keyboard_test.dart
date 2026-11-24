import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/mind_map/mind_map_document.dart';
import 'package:node_diary/core/database/mind_map/mind_map_ops.dart';
import 'package:node_diary/core/database/mind_map/mind_map_text.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/mind_maps/controllers/mind_map_editing_controller.dart';
import 'package:node_diary/ui/mind_maps/widgets/mind_map_accessory_bars.dart';
import 'package:node_diary/ui/mind_maps/widgets/mind_map_outline_view.dart';
import 'package:node_diary/ui/mind_maps/widgets/mind_map_workspace.dart';

import '../../support/expressive_test_theme.dart';

/// 大纲视图与软键盘：导图页不随键盘缩，大纲的视口要让到键盘与附件条之上，
/// 靠下的主题编辑时露在附件条上面，键盘升着也能滚到最后几行。
void main() {
  const keyboard = 300.0;
  const topicCount = 30;

  MindMapDocument tree() => MindMapOps.replaceRoot(
    MindMapDocument.blank(),
    mindMapNodeFromOutline(
      'Plan\n${[for (var i = 1; i <= topicCount; i++) '  T$i'].join('\n')}',
    )!,
  );

  Future<MindMapEditingController> pumpOutline(
    WidgetTester tester, {
    double topInset = 0,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // 视图切换在宿主顶栏里，这里直接从大纲开始。
    final controller = MindMapEditingController(tree())..outlineView = true;
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // 与 MindMapPageScaffold 一样不随键盘缩。
          home: Scaffold(
            resizeToAvoidBottomInset: false,
            body: MindMapWorkspace(controller: controller, topInset: topInset),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MindMapOutlineView), findsOneWidget);
    return controller;
  }

  Finder outlineScrollable() => find
      .descendant(
        of: find.byType(MindMapOutlineView),
        matching: find.byType(Scrollable),
      )
      .first;

  /// 键盘分几步升起（真机上 viewInsets 逐帧变大）。
  Future<void> raiseKeyboard(WidgetTester tester) async {
    for (final inset in <double>[100, 200, keyboard]) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
  }

  double accessoryTop(WidgetTester tester) =>
      tester.getTopLeft(find.byType(MindMapOutlineAccessoryBar)).dy;

  testWidgets('editing the last topic keeps it above the keyboard and the '
      'accessory bar', (tester) async {
    final controller = await pumpOutline(tester);
    await tester.scrollUntilVisible(
      find.text('T$topicCount'),
      200,
      scrollable: outlineScrollable(),
    );
    await tester.pump();
    await tester.tap(find.text('T$topicCount'));
    await tester.pump();
    await tester.pump();
    expect(controller.editingId, isNotNull);

    await raiseKeyboard(tester);
    final top = accessoryTop(tester);
    expect(top, lessThanOrEqualTo(800 - keyboard - 50));
    expect(
      tester.getRect(find.byType(TextField)).bottom,
      lessThanOrEqualTo(top),
    );
  });

  testWidgets('with the keyboard up the outline still scrolls the last '
      'topic above the accessory bar', (tester) async {
    final controller = await pumpOutline(tester);
    await tester.tap(find.text('T5'));
    await tester.pump();
    await tester.pump();
    final editing = controller.editingId;
    expect(editing, isNotNull);
    await raiseKeyboard(tester);

    // 从中心主题那一行往上拖到底，看下面的内容。
    await tester.dragFrom(const Offset(200, 70), const Offset(0, -3000));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final last = find.text('T$topicCount');
    expect(last, findsOneWidget);
    expect(
      tester.getRect(last).bottom,
      lessThanOrEqualTo(accessoryTop(tester)),
    );
    // 滚开时仍在编辑原来的主题：那一行的输入框保活，输入连接不断、键盘不掉。
    expect(controller.editingId, editing);
    expect(find.byType(TextField, skipOffstage: false), findsOneWidget);
    expect(tester.testTextInput.hasAnyClients, isTrue);
  });

  testWidgets('tapping a row that is already in view keeps it where it is, '
      'with or without the keyboard', (tester) async {
    final controller = await pumpOutline(tester);
    Finder row(String text) {
      final document = controller.document;
      final id = document.index.preorder.firstWhere(
        (id) => document.index[id]!.text == text,
      );
      return find.byKey(ValueKey<String>('outline-$id'));
    }

    final before = tester.getTopLeft(row('T4')).dy;
    await tester.tap(find.text('T4'));
    await tester.pumpAndSettle();
    expect(controller.editingId, isNotNull);
    expect(tester.getTopLeft(row('T4')).dy, closeTo(before, 1));

    await raiseKeyboard(tester);
    final t6 = tester.getRect(row('T6'));
    expect(t6.bottom, lessThan(accessoryTop(tester)));
    await tester.tap(find.text('T6'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(row('T6')).dy, closeTo(t6.top, 1));
  });

  testWidgets('Enter near the accessory bar reveals the new topic just above '
      'it instead of jumping it to the top', (tester) async {
    final controller = await pumpOutline(tester);
    await tester.tap(find.text('T5'));
    await tester.pump();
    await tester.pump();
    await raiseKeyboard(tester);
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final field = tester.getRect(find.byType(TextField));
      final top = accessoryTop(tester);
      expect(field.bottom, lessThanOrEqualTo(top), reason: 'enter #$i');
      expect(field.top, greaterThan(top - 120), reason: 'enter #$i');
    }
    expect(controller.document.root.children.length, topicCount + 6);
  });

  testWidgets('the soft keyboard Enter adds a sibling below and keeps '
      'editing with the keyboard up', (tester) async {
    final controller = await pumpOutline(tester);
    await tester.tap(find.text('T5'));
    await tester.pump();
    await tester.pump();
    await raiseKeyboard(tester);

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    final children = controller.document.root.children;
    expect(children.length, topicCount + 1);
    expect(children[4].text, 'T5');
    final added = children[5];
    expect(added.text, isEmpty);
    expect(controller.editingId, added.id);
    expect(tester.testTextInput.isVisible, isTrue);

    // 接着打字写进新主题。
    tester.testTextInput.enterText('T5b');
    await tester.pump();
    expect(controller.document.index[added.id]!.text, 'T5b');
  });

  testWidgets('the soft keyboard Enter at the start of a topic adds the '
      'sibling before it', (tester) async {
    final controller = await pumpOutline(tester);
    await tester.tap(find.text('T5'));
    await tester.pump();
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'T5',
        selection: TextSelection.collapsed(offset: 0),
      ),
    );
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    final children = controller.document.root.children;
    expect(children[4].text, isEmpty);
    expect(children[5].text, 'T5');
    expect(controller.editingId, children[4].id);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('Enter on the central topic of a long outline brings the new '
      'child, built far below, into view and keeps the keyboard', (
    tester,
  ) async {
    final controller = await pumpOutline(tester);
    await tester.tap(find.text('Plan'));
    await tester.pump();
    await tester.pump();
    await raiseKeyboard(tester);

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    final children = controller.document.root.children;
    expect(children.length, topicCount + 1);
    // 子主题排在最后，原本在已构建的范围之外。
    expect(controller.editingId, children.last.id);
    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    expect(
      tester.getRect(field).bottom,
      lessThanOrEqualTo(accessoryTop(tester)),
    );
    expect(tester.getRect(field).top, greaterThanOrEqualTo(0));
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('a topic under the top bar is revealed below it', (tester) async {
    // 宿主的浮岛顶栏盖住顶上这一截（状态栏 + 浮岛那一行）。
    const topBar = 56.0;
    final controller = await pumpOutline(tester, topInset: topBar);
    await tester.drag(outlineScrollable(), const Offset(0, -110));
    await tester.pumpAndSettle();
    // 顶上被浮岛顶栏盖住一半的那一行。
    final hidden = controller.document.root.children.firstWhere((node) {
      final finder = find.text(node.text);
      if (finder.evaluate().isEmpty) return false;
      final rect = tester.getRect(finder);
      return rect.top < topBar && rect.bottom > topBar;
    });
    controller.startEditing(hidden.id);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(TextField)).dy, greaterThan(topBar));
  });

  testWidgets('without the keyboard the outline keeps the full height', (
    tester,
  ) async {
    await pumpOutline(tester);
    final viewport = tester.getRect(outlineScrollable());
    expect(viewport.bottom, 800);
  });
}

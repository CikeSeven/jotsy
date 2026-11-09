import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_preferences.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_block_actions/diary_block_action_bar.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_block_handle.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_editor.dart';
import 'package:node_diary/ui/diaries/widgets/diary_floating_toolbar.dart';

import '../../../support/expressive_test_theme.dart';

class _CodeStyle extends DiaryCodeBlockStyleNotifier {
  @override
  DiaryCodeBlockStyle build() => DiaryCodeBlockStyle.defaults;
}

/// 正文（16dp 页边距）+ 下方的悬浮工具栏（段落选择模式里换成段落操作栏）。
Future<void> _pump(
  WidgetTester tester,
  DiaryEditorController controller,
  FocusNode focus,
) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [diaryCodeBlockStyleProvider.overrideWith(() => _CodeStyle())],
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('zh'),
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          af.AppFlowyEditorLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: DiaryEditor(
                  controller: controller,
                  appearance: const DiaryTextAppearance(
                    typography: DiaryTypography(),
                  ),
                  focusNode: focus,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
              DiaryFloatingToolbar(
                controller: controller,
                order: const [DiaryToolbarItem.bold],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _frames(WidgetTester tester, [int count = 6]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// 光标放进第 [index] 块、正文取得焦点，把手出现后点它进入段落选择模式。
Future<void> _enterAt(
  WidgetTester tester,
  DiaryEditorController controller,
  FocusNode focus,
  int index,
) async {
  controller.select(af.Selection.collapsed(af.Position(path: [index])));
  focus.requestFocus();
  await _frames(tester, 4);
  await tester.tap(find.byType(DiaryBlockHandle));
  await _frames(tester);
}

Finder get _blocks => find.byType(af.ParagraphBlockComponentWidget);

String _order(DiaryEditorController controller) => [
  for (final node in controller.document.root.children)
    node.delta!.toPlainText(),
].join(',');

Future<void> _dispose(
  WidgetTester tester,
  DiaryEditorController controller,
  FocusNode focus,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
  controller.dispose();
  focus.dispose();
}

void main() {
  testWidgets('tapping the handle selects its block and swaps the toolbar for '
      'the block action bar; Done puts the caret back', (tester) async {
    final focus = FocusNode();
    final controller = DiaryEditorController.fromContent('one\ntwo\nthree');
    await _pump(tester, controller, focus);
    await _enterAt(tester, controller, focus, 1);

    final selection = controller.blockSelection;
    expect(selection.isActive, isTrue);
    expect(selection.roots.map((node) => node.path), [
      [1],
    ]);
    // 正文没有选区（键盘收起），把手隐去，工具栏换成段落操作栏。
    expect(controller.state.selection, isNull);
    expect(find.byType(DiaryBlockHandle), findsNothing);
    expect(find.byType(DiaryBlockActionBar), findsOneWidget);
    expect(find.text('已选 1 段'), findsOneWidget);

    await tester.tap(find.text('完成'));
    await _frames(tester);
    expect(selection.isActive, isFalse);
    expect(find.byType(DiaryBlockActionBar), findsNothing);
    expect(
      controller.state.selection,
      af.Selection.collapsed(af.Position(path: [1], offset: 3)),
    );
    await _dispose(tester, controller, focus);
  });

  testWidgets('taps toggle blocks without placing a caret, '
      'and Up / Down can be pressed again and again', (tester) async {
    final focus = FocusNode();
    final controller = DiaryEditorController.fromContent('a\nb\nc\nd');
    await _pump(tester, controller, focus);
    await _enterAt(tester, controller, focus, 0);
    final selection = controller.blockSelection;

    // 点第三块：加进选择；再点第一块：取消它。
    await tester.tap(_blocks.at(2));
    await _frames(tester, 2);
    expect(selection.roots.map((node) => node.delta!.toPlainText()), [
      'a',
      'c',
    ]);
    expect(find.text('已选 2 段'), findsOneWidget);
    await tester.tap(_blocks.at(0));
    await _frames(tester, 2);
    expect(selection.roots.single.delta!.toPlainText(), 'c');
    expect(controller.state.selection, isNull);

    // 上移连点两次，留在模式里。
    final up = find.byTooltip('上移段落');
    await tester.tap(up);
    await _frames(tester, 2);
    await tester.tap(up);
    await _frames(tester, 2);
    expect(_order(controller), 'c,a,b,d');
    expect(selection.isActive, isTrue);
    expect(selection.roots.single.path, [0]);
    // 已在文首：上移停用。
    expect(
      tester
          .widget<IconButton>(
            find
                .ancestor(
                  of: find.byTooltip('上移段落'),
                  matching: find.byType(IconButton),
                )
                .first,
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('下移段落'));
    await _frames(tester, 2);
    expect(_order(controller), 'a,c,b,d');
    // 每次移动一步撤销。
    controller.undo();
    expect(_order(controller), 'c,a,b,d');
    await _dispose(tester, controller, focus);
  });

  testWidgets(
    'select all, delete with undo, and the bar leaves with the mode',
    (tester) async {
      final focus = FocusNode();
      final controller = DiaryEditorController.fromContent('a\nb\nc');
      await _pump(tester, controller, focus);
      await _enterAt(tester, controller, focus, 0);

      await tester.tap(find.text('全选'));
      await _frames(tester, 2);
      expect(find.text('已选 3 段'), findsOneWidget);
      expect(find.text('取消全选'), findsOneWidget);

      await tester.tap(find.byTooltip('删除'));
      await _frames(tester);
      // 全删补一个空段落，退出模式，提示条带撤销。
      expect(controller.document.root.children, hasLength(1));
      expect(controller.plainText, '');
      expect(controller.blockSelection.isActive, isFalse);
      expect(find.text('已删除 3 段'), findsOneWidget);
      await tester.tap(find.text('撤销'));
      await _frames(tester);
      expect(_order(controller), 'a,b,c');
      await _dispose(tester, controller, focus);
    },
  );

  testWidgets('More moves the selection to the bottom, duplicates it and '
      'copies it with formatting', (tester) async {
    final clipboard = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final focus = FocusNode();
    final controller = DiaryEditorController.fromContent('a\nb\nc');
    await _pump(tester, controller, focus);
    await _enterAt(tester, controller, focus, 0);

    await tester.tap(find.byTooltip('更多'));
    await _frames(tester);
    await tester.tap(find.text('移到末尾'));
    await _frames(tester, 2);
    expect(_order(controller), 'b,c,a');
    await tester.tap(find.text('创建副本'));
    await _frames(tester, 2);
    expect(_order(controller), 'b,c,a,a');
    // 选择换到副本上。
    expect(controller.blockSelection.roots.single.path, [3]);

    await tester.tap(find.byTooltip('复制'));
    await _frames(tester);
    expect(clipboard, ['a']);
    expect(find.text('已复制 1 段'), findsOneWidget);
    expect(controller.blockSelection.isActive, isTrue);
    await _dispose(tester, controller, focus);
  });

  testWidgets('Turn into and Style format every selected block at once', (
    tester,
  ) async {
    final focus = FocusNode();
    final controller = DiaryEditorController.fromContent('a\nb\nc');
    await _pump(tester, controller, focus);
    await _enterAt(tester, controller, focus, 0);
    await tester.tap(find.text('全选'));
    await _frames(tester, 2);

    await tester.tap(find.byTooltip('转换为'));
    await _frames(tester);
    await tester.tap(find.text('待办列表'));
    await _frames(tester, 2);
    expect(
      controller.document.root.children.map((node) => node.type),
      everyElement('todo_list'),
    );
    // 换了类型仍全选着，面板保持打开。
    expect(controller.blockSelection.count, 3);
    expect(find.text('待办列表'), findsOneWidget);

    await tester.tap(find.byTooltip('样式'));
    await _frames(tester);
    await tester.tap(find.text('加粗'));
    await _frames(tester, 2);
    for (final node in controller.document.root.children) {
      expect(node.delta!.toJson().single['attributes'], {'bold': true});
    }
    await tester.tap(find.text('居中'));
    await _frames(tester, 2);
    expect(
      controller.document.root.children.map((node) => node.attributes['align']),
      everyElement('center'),
    );
    await _dispose(tester, controller, focus);
  });

  testWidgets('sliding along the selection circles selects a run, sliding '
      'back restores it', (tester) async {
    final focus = FocusNode();
    final controller = DiaryEditorController.fromContent('a\nb\nc\nd\ne');
    await _pump(tester, controller, focus);
    await _enterAt(tester, controller, focus, 4);
    final selection = controller.blockSelection;
    double rowY(int index) => tester.getCenter(_blocks.at(index)).dy;

    final gesture = await tester.startGesture(Offset(8, rowY(0)));
    for (var step = 1; step <= 6; step++) {
      await gesture.moveTo(Offset(8, rowY(0) + (rowY(2) - rowY(0)) * step / 6));
      await tester.pump();
    }
    expect(selection.roots.map((node) => node.delta!.toPlainText()), [
      'a',
      'b',
      'c',
      'e',
    ]);
    // 滑回第二块：第三块恢复原状（没选）。
    await gesture.moveTo(Offset(8, rowY(1)));
    await tester.pump();
    await tester.pump();
    expect(selection.roots.map((node) => node.delta!.toPlainText()), [
      'a',
      'b',
      'e',
    ]);
    await gesture.up();
    await tester.pump();
    // 点按选择圈切换。
    await tester.tapAt(Offset(8, rowY(4)));
    await _frames(tester, 2);
    expect(selection.roots.map((node) => node.delta!.toPlainText()), [
      'a',
      'b',
    ]);
    await _dispose(tester, controller, focus);
  });

  testWidgets('holding a block in the mode drags the whole scattered group', (
    tester,
  ) async {
    final focus = FocusNode();
    final controller = DiaryEditorController.fromContent('a\nb\nc\nd');
    await _pump(tester, controller, focus);
    await _enterAt(tester, controller, focus, 0);
    await tester.tap(_blocks.at(2));
    await _frames(tester, 2);

    final start = tester.getCenter(_blocks.at(2));
    final target = tester.getBottomLeft(_blocks.at(3)) + const Offset(100, -2);
    final gesture = await tester.startGesture(start);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    for (var step = 1; step <= 6; step++) {
      await gesture.moveTo(start + (target - start) * (step / 6));
      await tester.pump();
      await tester.pump();
    }
    expect(controller.hasUndo, isFalse);
    await gesture.up();
    await tester.pump();
    expect(_order(controller), 'b,d,a,c');
    expect(controller.blockSelection.isActive, isTrue);
    expect(controller.state.selection, isNull);
    controller.undo();
    expect(_order(controller), 'a,b,c,d');
    await _dispose(tester, controller, focus);
  });

  testWidgets(
    'hardware keys: Ctrl+A, Escape, Delete, and Shift+click a range',
    (tester) async {
      final focus = FocusNode();
      final controller = DiaryEditorController.fromContent('a\nb\nc\nd');
      await _pump(tester, controller, focus);
      await _enterAt(tester, controller, focus, 0);
      final selection = controller.blockSelection;

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(_blocks.at(2));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await _frames(tester, 2);
      expect(selection.count, 3);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _frames(tester, 2);
      expect(selection.count, 4);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _frames(tester);
      expect(selection.isActive, isFalse);
      expect(controller.state.selection!.end.path, [0]);

      await _enterAt(tester, controller, focus, 3);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await _frames(tester);
      expect(_order(controller), 'a,b,c');
      expect(selection.isActive, isFalse);
      await _dispose(tester, controller, focus);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets('tapping the blank space below the last block finishes', (
    tester,
  ) async {
    final focus = FocusNode();
    final controller = DiaryEditorController.fromContent('a\nb');
    await _pump(tester, controller, focus);
    await _enterAt(tester, controller, focus, 1);
    await tester.tapAt(
      tester.getBottomLeft(_blocks.at(1)) + const Offset(80, 60),
    );
    await _frames(tester);
    expect(controller.blockSelection.isActive, isFalse);
    expect(controller.state.selection!.end.path, [1]);
    await _dispose(tester, controller, focus);
  });
}

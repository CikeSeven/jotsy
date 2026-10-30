import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final caret = Selection.single(path: [0], startOffset: 3);

  DiaryEditorController controllerAtCaret() {
    final controller = DiaryEditorController.fromContent('body text');
    addTearDown(controller.dispose);
    controller.select(caret);
    controller.format('bold', true);
    controller.format('font_color', '#FF336699');
    return controller;
  }

  test('returning to the same caret restores pending input formatting', () {
    final controller = controllerAtCaret();

    // 模拟上游键盘服务的失焦处理：可见选区消失，原插入点仍可用于续写。
    controller.state.selection = null;
    expect(controller.state.selection, isNull);
    expect(controller.selection, caret);
    controller.select(caret);

    expect(controller.selectionAttributes['bold'], isTrue);
    expect(controller.selectionAttributes['font_color'], '#FF336699');
    expect(controller.plainText, 'body text');
  });

  test(
    'colors chosen while unfocused override only that pending attribute',
    () {
      final controller = controllerAtCaret();
      controller.state.selection = null;

      controller.format('font_color', '#FF993366');
      controller.select(caret);

      expect(controller.selectionAttributes['bold'], isTrue);
      expect(controller.selectionAttributes['font_color'], '#FF993366');
    },
  );

  test('moving to another caret clears formatting from the old caret', () {
    final controller = controllerAtCaret();
    controller.state.selection = null;
    final otherCaret = Selection.single(path: [0], startOffset: 1);

    controller.select(otherCaret);
    expect(controller.selectionAttributes['bold'], isNull);
    expect(controller.selectionAttributes['font_color'], isNull);

    // 新插入点已经取代旧快照，再次交接焦点不能复活更早的格式。
    controller.state.selection = null;
    controller.select(otherCaret);
    expect(controller.selectionAttributes['bold'], isNull);
    expect(controller.selectionAttributes['font_color'], isNull);
  });
}

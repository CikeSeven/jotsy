import 'package:flutter_test/flutter_test.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';

void main() {
  test(
    'save listeners see the current native transaction, undo and redo',
    () async {
      final controller = DiaryEditorController.fromContent('第一段\nsecond line');
      addTearDown(controller.dispose);
      final original = controller.contentJson;
      final observed = <String>[];
      controller.addListener(() {
        final tree = controller.document.toJson();
        expect(controller.contentJson, encodeDiaryBlocks(tree));
        expect(controller.plainText, diaryBlocksPlainText(tree));
        observed.add(controller.contentJson);
      });

      // 原生输入直接经过 EditorState，不经过包装控制器的 apply。
      final af.Node first = controller.document.nodeAtPath([0])!;
      await controller.state.apply(
        controller.state.transaction..insertText(first, 0, '新增'),
        skipHistoryDebounce: true,
      );
      final edited = controller.contentJson;
      expect(controller.plainText, '新增第一段\nsecond line');
      expect(edited, isNot(original));
      controller.undo();
      expect(controller.contentJson, original);
      controller.redo();
      expect(controller.contentJson, edited);
      expect(observed, containsAll([original, edited]));
    },
  );

  test(
    'selection and pending styles reuse content but restore replaces it',
    () {
      final controller = DiaryEditorController.fromContent('hello world');
      addTearDown(controller.dispose);
      final json = controller.contentJson;
      final text = controller.plainText;
      controller.select(Selection.single(path: [0], startOffset: 3));
      controller.format('bold', true);
      expect(identical(controller.contentJson, json), isTrue);
      expect(identical(controller.plainText, text), isTrue);
      expect(controller.revision, 0);

      controller.restoreContent('恢复的正文');
      expect(controller.plainText, '恢复的正文');
      expect(controller.contentJson, isNot(json));
      expect(controller.hasUndo, isFalse);
    },
  );
}

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import '../controllers/diary_editor_controller.dart';
import '../controllers/diary_editor_insert.dart';

/// 图片独占块，替换所选文字；文件已由媒体服务复制，这里只改原生文档。
void insertDiaryImages({
  required DiaryEditorController controller,
  required List<String> imagePaths,
  af.Selection? selection,
}) {
  insertDiaryEditorNodes(
    controller: controller,
    selection: selection,
    replaceSelection: true,
    nodes: [
      for (final path in imagePaths)
        if (path.trim().isNotEmpty)
          af.Node(type: 'image', attributes: {'url': path}),
    ],
  );
}

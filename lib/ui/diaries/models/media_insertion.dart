import 'package:appflowy_editor/appflowy_editor.dart' as af;
import '../controllers/diary_editor_controller.dart';
import '../controllers/diary_editor_insert.dart';

/// 视频与附件保留选中文字，插在选区末端，结束后回到可编辑的普通段落。
void insertDiaryMediaBlocks({
  required DiaryEditorController controller,
  required List<af.Node> embeds,
  af.Selection? selection,
}) => insertDiaryEditorNodes(
  controller: controller,
  nodes: embeds,
  selection: selection,
);

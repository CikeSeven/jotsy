import 'package:appflowy_editor/appflowy_editor.dart' as af;

import 'diary_editor_controller.dart';

/// 移动整棵子树。目标路径按移动前的树解释，原生事务负责删除后的路径变换；
/// 同时换算新选区，避免光标仍指向被挤走的相邻段落。禁止把块拖进自己的子树。
///
/// 移动后光标落在被移动块的末尾（媒体块为块本身），可以接着写；不选中
/// 整块——块选区会弹出系统选区菜单，打断书写。
bool moveDiaryEditorBlock(
  DiaryEditorController controller,
  af.Node node,
  af.Path destination,
) {
  if (controller.readOnly || node.parent == null || destination.isEmpty) {
    return false;
  }
  final source = node.path;
  if (destination.length > source.length &&
      destination.sublist(0, source.length).equals(source)) {
    return false;
  }
  final after = List<int>.of(destination);
  if (after.length >= source.length &&
      after.sublist(0, source.length - 1).equals(source.parent) &&
      after[source.length - 1] > source.last) {
    after[source.length - 1]--;
  }
  if (source.equals(after)) return false;
  final transaction = controller.state.transaction
    ..moveNode(destination, node)
    ..afterSelection = af.Selection.collapsed(
      af.Position(path: after, offset: node.delta?.length ?? 0),
    );
  controller.apply(transaction);
  return true;
}

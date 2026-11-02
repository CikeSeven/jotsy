import 'package:appflowy_editor/appflowy_editor.dart' as af;

import 'diary_editor_controller.dart';
import 'diary_table_editing.dart';

/// 选区暂时不存在时使用正文末尾；媒体工具保留选中文字，插在选区末端。
af.Selection diaryEditorInsertionSelection(
  DiaryEditorController controller, [
  af.Selection? selection,
]) {
  selection ??= controller.selection;
  if (selection != null &&
      controller.document.nodeAtPath(selection.end.path) != null) {
    return selection;
  }
  final last = walkDiaryEditorNodes(controller.document).last;
  return af.Selection.collapsed(
    af.Position(path: last.path, offset: last.delta?.length ?? 1),
  );
}

/// 在当前块中拆开前后文字，一次事务插入媒体与末尾可编辑段落。
/// 子树留在原父块中，媒体作为同级块插入；撤销同时恢复文字、媒体与选区。
/// 光标在表格的格子里时不拆格内文字：格子只能放段落，整组插到表格后面，
/// 光标落到后面的空段落。
void insertDiaryEditorNodes({
  required DiaryEditorController controller,
  required List<af.Node> nodes,
  af.Selection? selection,
  bool replaceSelection = false,
}) {
  if (nodes.isEmpty || controller.readOnly) return;
  final target = diaryEditorInsertionSelection(
    controller,
    selection,
  ).normalized;
  final current = controller.document.nodeAtPath(target.end.path);
  if (current == null) return;
  final delta = current.delta;
  final transaction = controller.state.transaction;
  af.Node? replaced;
  final af.Path insertPath;
  af.Node trailing;
  final table = diaryTableOf(current);
  if (table != null) {
    insertPath = table.path.next;
    trailing = af.paragraphNode();
  } else if (delta == null) {
    insertPath = current.path.next;
    trailing = af.paragraphNode();
  } else {
    final offset = target.end.offset.clamp(0, delta.length);
    final before = delta.slice(
      0,
      replaceSelection && target.isSingle
          ? target.start.offset.clamp(0, offset)
          : offset,
    );
    final after = delta.slice(offset);
    trailing = after.isEmpty
        ? af.paragraphNode()
        : current.copyWith(
            attributes: {...current.attributes, 'delta': after.toJson()},
            children: [],
          );
    if (before.isEmpty &&
        current.children.isEmpty &&
        current.type == 'paragraph') {
      insertPath = current.path;
      replaced = current;
    } else {
      insertPath = current.path.next;
      transaction.updateNode(current, {'delta': before.toJson()});
    }
  }
  transaction.insertNodes(insertPath, [...nodes, trailing]);
  // 先插后删：AppFlowy 会把“先删同一路径、再插”的路径变换成 -1，空文档中
  // 会反转节点顺序。原节点的删除路径由前面的插入自动向后平移。
  if (replaced != null) transaction.deleteNode(replaced);
  transaction.afterSelection = af.Selection.collapsed(
    af.Position(path: insertPath.nextNPath(nodes.length), offset: 0),
  );
  controller.apply(transaction);
}

/// 在光标处插入一条分隔线：工具栏「分隔线」工具与 `/` 菜单共用这一条。
///
/// 分隔线和媒体一样是不带文字的整块，所以直接走 [insertDiaryEditorNodes]
/// 的口径而不另写：光标在段落中间时拆开前后文字，分隔线后面接上后半段
/// （没有后半段时补一个空段落，光标落在那里，可以接着写）；在空段落上时
/// 取代它；在表格格子里时插到表格后面；在代码块里与插图片一样在光标处
/// 拆开代码块。保留选中的文字、插在选区末端。一次事务，一步撤销。
void insertDiaryDivider(DiaryEditorController controller) =>
    insertDiaryEditorNodes(controller: controller, nodes: [af.dividerNode()]);

/// 替换选区文字由 AppFlowy 自身处理跨块合并，保留它的 Unicode 与树结构规则。
Future<void> insertDiaryEditorText(
  DiaryEditorController controller,
  String text,
) async {
  if (controller.readOnly || text.isEmpty) return;
  final selection = diaryEditorInsertionSelection(controller);
  controller.select(selection);
  if (!selection.isCollapsed) await controller.state.deleteSelection(selection);
  if (controller.state.isDisposed) return;
  await controller.state.insertTextAtCurrentSelection(text);
}

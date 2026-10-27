import 'package:appflowy_editor/appflowy_editor.dart' as af;

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../core/database/diary_blocks/diary_list_style.dart';
import 'diary_editor_controller.dart';

/// 编辑器里的列表样式：读出一个列表块实际显示的样式，以及工具栏列表面板
/// 改写样式。规则（一段列表共用、段内沿用、未选过按层级轮换）只在
/// `diary_list_style.dart`，这里只把编辑器节点接上去。

/// 同类型祖先的个数：未选过样式时据此轮换（与改版前的标记一致）。
int diaryListLevel(af.Node node) {
  var level = 0;
  for (var parent = node.parent; parent != null; parent = parent.parent) {
    if (parent.type == node.type) level++;
  }
  return level;
}

/// [node] 所在那一段列表写着的样式值（见 [resolveDiaryListStyleId]）；
/// 整段都没选过为 null。
String? diaryListStyleIdOf(af.Node node) {
  final parent = node.parent;
  if (parent == null) {
    final value = node.attributes[kDiaryListStyleKey];
    return value is String ? value : null;
  }
  return resolveDiaryListStyleId(
    parent.children,
    node.path.last,
    typeOf: (node) => node.type,
    styleOf: (node) => node.attributes[kDiaryListStyleKey],
  );
}

DiaryOrderedListStyle diaryOrderedListStyleOf(af.Node node) =>
    DiaryOrderedListStyle.fromId(diaryListStyleIdOf(node)) ??
    DiaryOrderedListStyle.auto(diaryListLevel(node));

DiaryBulletListStyle diaryBulletListStyleOf(af.Node node) =>
    DiaryBulletListStyle.fromId(diaryListStyleIdOf(node)) ??
    DiaryBulletListStyle.auto(diaryListLevel(node));

/// 选区里的文字块都是同一种列表（有序或无序）时返回它的块类型，否则为
/// null。工具栏据此决定点按列表工具是“转为列表”还是打开列表面板，面板开着
/// 时据此判断该收起还是换成另一种列表的样式。与列表按钮的选中态同一口径。
String? diarySelectionListType(DiaryEditorController controller) {
  final nodes = [
    for (final node in controller.selectedNodes)
      if (node.delta != null) node,
  ];
  if (nodes.isEmpty) return null;
  final type = nodes.first.type;
  if (type != kDiaryBlockNumberedList && type != kDiaryBlockBulletedList) {
    return null;
  }
  return nodes.every((node) => node.type == type) ? type : null;
}

/// 选区触及的 [type] 列表，各自扩展到整段（相邻的同类型兄弟块），按文档
/// 顺序、不重复。
List<af.Node> selectedDiaryListRuns(
  DiaryEditorController controller,
  String type,
) {
  final seen = <af.Node>{};
  final result = <af.Node>[];
  for (final node in controller.selectedNodes) {
    if (node.type != type || seen.contains(node)) continue;
    var first = node;
    while (first.previous?.type == type) {
      first = first.previous!;
    }
    for (af.Node? item = first; item != null && item.type == type;) {
      if (seen.add(item)) result.add(item);
      item = item.next;
    }
  }
  return result;
}

/// 选区触及的各段 [type] 列表共同的样式值：都没选过为 `(id: null)`，各段
/// 不一样时整个结果为 null（面板不选中任何一项）。
({String? id})? selectedDiaryListStyle(
  DiaryEditorController controller,
  String type,
) {
  final ids = {
    for (final node in selectedDiaryListRuns(controller, type))
      diaryListStyleIdOf(node),
  };
  return ids.length == 1 ? (id: ids.single) : null;
}

/// 把选区触及的各段 [type] 列表整段改成样式 [id]（null 为回到按层级轮换）。
/// 一次事务、一步撤销；选区不动。
void setDiaryListStyle(
  DiaryEditorController controller,
  String type,
  String? id,
) {
  final runs = selectedDiaryListRuns(controller, type);
  if (runs.isEmpty) return;
  final transaction = controller.state.transaction;
  for (final node in runs) {
    // updateNode 合并属性，null 即删除这个键。
    transaction.updateNode(node, {kDiaryListStyleKey: id});
  }
  transaction.afterSelection = controller.selection;
  controller.apply(transaction);
}

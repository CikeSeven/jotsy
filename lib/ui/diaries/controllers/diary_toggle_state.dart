import 'package:appflowy_editor/appflowy_editor.dart' as af;

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';

/// 折叠块（`toggle_list`）的收起状态与“被收起的内容”判断，编辑器渲染、
/// 段落拖动的落点与选区监听共用；只读文档，不写正文（自动展开见
/// [expandDiaryTogglesAroundSelection]）。
///
/// - 文档里的收起状态只有 `data.collapsed == true` 一种写法，缺省、false 或
///   认不出的值都按展开（[isDiaryToggleCollapsed]）；
/// - 只读正文（预览、模板预览）点按标记只改本地的显示状态，从不写文档：
///   按节点记在 [diaryToggleViewCollapsed] 里，块组件随滚动卸载再建时仍
///   保留，节点随会话释放而回收；
/// - 被收起的内容不建组件、没有几何（`node.rect` 为 `Rect.zero`），拖动段落
///   时不能落进去、也不参与测量（见 `DiaryBlockGaps`）。

/// 节点是不是文档里已收起的折叠块。
bool isDiaryToggleCollapsed(af.Node node) =>
    node.type == kDiaryBlockToggleList &&
    node.attributes[kDiaryToggleCollapsedKey] == true;

/// 只读正文里各折叠块的显示状态（true 为收起）。没有记录时按文档里的
/// 收起状态。
final Expando<bool> _readOnlyCollapsed = Expando('diary toggle view');

/// 只读正文里 [node] 当前是否收起：用户点过按点过的，否则按文档。
bool diaryToggleViewCollapsed(af.Node node) =>
    _readOnlyCollapsed[node] ?? isDiaryToggleCollapsed(node);

/// 只读正文里改 [node] 的显示状态（不写文档）。
void setDiaryToggleViewCollapsed(af.Node node, bool collapsed) =>
    _readOnlyCollapsed[node] = collapsed;

/// [node] 是不是某个已收起的折叠块里的内容（自身是折叠块不算）。
bool isDiaryNodeHiddenByToggle(af.Node node) =>
    collapsedDiaryTogglesAbove(node).isNotEmpty;

/// [node] 的祖先里所有已收起的折叠块，由内到外。
List<af.Node> collapsedDiaryTogglesAbove(af.Node node) => [
  for (var parent = node.parent; parent != null; parent = parent.parent)
    if (isDiaryToggleCollapsed(parent)) parent,
];

/// 选区（任一端）落进已收起的折叠块里时，把它所在的每一层收起的折叠块
/// 展开；不需要展开时返回 false、什么都不做。
///
/// 触发：撤销 / 重做恢复的选区、程序设的选区、方向键越过标题末尾、Tab 把
/// 段落缩进到收起的折叠块里、退格并进被收起的最后一段等，光标都可能停在
/// 看不见的内容里——画不出光标，打字也不知道写到了哪里。全选
/// （[af.SelectionUpdateReason.selectAll]）例外：选区末端常落在文末收起的
/// 内容里，全选不应改动文档。
///
/// 撤销：展开以 [af.TransactionSource.none] 应用，不进撤销栈、也不清空重做
/// 栈——它只是让光标所在的内容显示出来，不算一次编辑：撤销把光标带进
/// 收起的内容时，展开不会多出一步“撤销展开”，撤销 / 重做的步数与用户的
/// 编辑一一对应。这样做是安全的：展开只是一个属性更新（UpdateOperation），
/// 不改变树形与路径，栈里已有操作的逆操作只按自己记下的新旧值改写，与
/// 这次展开互不影响。展开会照常经事务流通知监听者，编辑页随自动保存把
/// 展开状态写进日记。选区不动（`withUpdateSelection: false`）。
bool expandDiaryTogglesAroundSelection(af.EditorState state) {
  final selection = state.selection;
  if (state.isDisposed ||
      !state.editable ||
      selection == null ||
      state.selectionUpdateReason == af.SelectionUpdateReason.selectAll) {
    return false;
  }
  final toggles = <af.Node>{
    for (final position in {selection.start, selection.end})
      if (state.document.nodeAtPath(position.path) case final node?)
        ...collapsedDiaryTogglesAbove(node),
  };
  if (toggles.isEmpty) return false;
  final transaction = state.transaction;
  for (final toggle in toggles) {
    transaction.updateNode(toggle, {kDiaryToggleCollapsedKey: null});
  }
  state.apply(
    transaction,
    options: const af.ApplyOptions(source: af.TransactionSource.none),
    withUpdateSelection: false,
  );
  return true;
}

/// 选区是否有一端落在已收起的折叠块里（[expandDiaryTogglesAroundSelection]
/// 的廉价预检，选区监听里每次都要判断）。
bool diarySelectionInsideCollapsedToggle(af.EditorState state) {
  final selection = state.selection;
  if (selection == null) return false;
  for (final position in [selection.start, selection.end]) {
    final node = state.document.nodeAtPath(position.path);
    if (node != null && isDiaryNodeHiddenByToggle(node)) return true;
  }
  return false;
}

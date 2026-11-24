import 'package:flutter/foundation.dart';

import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../core/database/mind_map/mind_map_ops.dart';
import '../../../core/database/mind_map/mind_map_rich_text.dart';
import '../models/mind_map_options.dart';
import '../viewmodels/mind_map_drop_planner.dart';
import 'mind_map_text_session.dart';

/// 导图编辑会话：当前文档、选中与正在编辑的节点、撤销 / 重做、画布或大纲。
///
/// 职责边界：只持有内存里的文档并经 [MindMapOps] 改它，不写库、不碰路由。
/// 改动后先通知 [onChanged]（宿主据此写回日记正文，自动保存照常经日记的
/// 链路），再 `notifyListeners` 让画布重新布局。撤销栈存“文档 + 选中”的
/// 快照（文档不可变、未改动的子树共享，快照很便宜），上限 [_historyLimit]
/// 步；同一节点连续输入在 [_coalesceWindow] 内合并成一步。
class MindMapEditingController extends ChangeNotifier {
  MindMapEditingController(MindMapDocument document, {this.readOnly = false})
    : _document = document;

  static const int _historyLimit = 100;
  static const Duration _coalesceWindow = Duration(milliseconds: 1200);

  final bool readOnly;

  /// 文档因编辑（含撤销 / 重做）而变化时调用；载入与 [reset] 不调用。
  ValueChanged<MindMapDocument>? onChanged;

  /// 画布上根的各个分支此刻画在哪一侧（见 `MindMapScene.rootSides`），由
  /// 持有画布的工作区接上；大纲视图、没接时为 null 或空，不固定任何分支。
  /// 用户指定一侧的操作经它先把已有分支固定在原地（见
  /// [MindMapOps.pinRootSides]）。
  Map<String, String>? Function()? placedRootSides;

  MindMapDocument _document;
  MindMapDocument get document => _document;

  String? _selectedId;
  String? get selectedId =>
      _selectedId != null && _document.index.contains(_selectedId!)
      ? _selectedId
      : null;

  String? _editingId;
  String? get editingId =>
      _editingId != null && _document.index.contains(_editingId!)
      ? _editingId
      : null;

  /// 下一次重新布局是否带转场动画（打字时为假：节点随字变宽直接到位，
  /// 输入框才不会追着节点晃）。画布读过后自行复位。
  bool animateNextLayout = true;

  /// 每次文档变化加一（画布据此判断要不要重新布局）。
  int revision = 0;

  final List<_Snapshot> _undo = <_Snapshot>[];
  final List<_Snapshot> _redo = <_Snapshot>[];
  Object? _lastCoalesceKey;
  DateTime _lastCommitAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// 是不是平衡结构（根在中间、分支分左右两侧）。
  bool get _balanced =>
      MindMapStructure.resolve(_document.structure) == MindMapStructure.mindMap;

  /// 中心主题的操作给不给“向左 / 向右添加”：平衡结构的画布上才有（大纲里
  /// 看不出左右，照旧是子主题 / 同级）。
  bool get canChooseSide => _balanced && !_outlineView;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// 正在编辑的主题文字输入框（画布或大纲的），格式条经它设样式。
  final MindMapTextSession textSession = MindMapTextSession();

  bool _outlineView = false;

  /// 工作区显示大纲而不是画布（会话里的临时状态，不写进文档）。放在会话
  /// 里而不是工作区：宿主顶栏的“导出导图”据此默认选中大纲的格式。
  bool get outlineView => _outlineView;
  set outlineView(bool value) {
    if (value == _outlineView) return;
    _outlineView = value;
    notifyListeners();
  }

  @override
  void dispose() {
    textSession.dispose();
    super.dispose();
  }

  /// 换成外部给的文档（重新载入），清空撤销栈，不回调 [onChanged]。
  void reset(MindMapDocument document) {
    _document = document;
    _undo.clear();
    _redo.clear();
    _lastCoalesceKey = null;
    _editingId = null;
    revision++;
    animateNextLayout = false;
    notifyListeners();
  }

  /// 提交一次改动。[coalesce] 相同且间隔很短的连续提交合并为一步撤销。
  void commit(
    MindMapDocument next, {
    String? select,
    Object? coalesce,
    bool animate = true,
  }) {
    if (readOnly || identical(next, _document)) {
      if (select != null && select != _selectedId) this.select(select);
      return;
    }
    final now = DateTime.now();
    final merge =
        coalesce != null &&
        coalesce == _lastCoalesceKey &&
        now.difference(_lastCommitAt) < _coalesceWindow &&
        _undo.isNotEmpty;
    if (!merge) {
      _undo.add(_Snapshot(_document, _selectedId));
      if (_undo.length > _historyLimit) _undo.removeAt(0);
    }
    _redo.clear();
    _lastCoalesceKey = coalesce;
    _lastCommitAt = now;
    _document = next;
    if (select != null) _selectedId = select;
    revision++;
    animateNextLayout = animate;
    onChanged?.call(next);
    notifyListeners();
  }

  void undo() => _travel(_undo, _redo);
  void redo() => _travel(_redo, _undo);

  void _travel(List<_Snapshot> from, List<_Snapshot> to) {
    if (readOnly || from.isEmpty) return;
    final snapshot = from.removeLast();
    to.add(_Snapshot(_document, _selectedId));
    _document = snapshot.document;
    _selectedId = snapshot.selectedId;
    _editingId = null;
    _lastCoalesceKey = null;
    revision++;
    animateNextLayout = true;
    onChanged?.call(_document);
    notifyListeners();
  }

  void select(String? id) {
    if (id == _selectedId && _editingId == null) return;
    if (id != _editingId) _editingId = null;
    _selectedId = id;
    notifyListeners();
  }

  void startEditing(String id) {
    if (readOnly || !_document.index.contains(id)) return;
    _selectedId = id;
    _editingId = id;
    _lastCoalesceKey = null;
    notifyListeners();
  }

  void stopEditing() {
    if (_editingId == null) return;
    _editingId = null;
    _lastCoalesceKey = null;
    notifyListeners();
  }

  // ---------------- 常用编辑 ----------------

  void setText(String id, String text) => commit(
    MindMapOps.setText(_document, id, text),
    coalesce: ('text', id),
    animate: false,
  );

  /// 输入框里改字或设样式（局部样式随文字一起写）：打字时同一节点连续
  /// 输入合并为一步撤销，设样式（[format]）各是一步。
  void setRichText(
    String id,
    String text,
    List<InlineTextRun> runs, {
    bool format = false,
  }) => commit(
    MindMapOps.setRichText(_document, id, text, runs),
    coalesce: format ? null : ('text', id),
    animate: false,
  );

  /// 给 [parentId]（缺省为选中的节点，没有选中时为根）加子节点，选中它并
  /// 进入编辑。返回新节点 id。
  String? addChild({String? parentId, bool edit = true}) {
    final parent = parentId ?? selectedId ?? _document.root.id;
    final (next, id) = MindMapOps.addChild(_document, parent);
    if (id == null) return null;
    _editingId = null;
    commit(next, select: id);
    if (edit) startEditing(id);
    return id;
  }

  /// 在选中节点旁加同级节点（选中的是根时加子节点）。选中的是根的分支时
  /// 先把各分支固定在画面上的一侧，新的同级就落在选中分支那一侧。
  String? addSibling({bool before = false, bool edit = true}) {
    final anchor = selectedId ?? _document.root.id;
    final base = _document.index.parentOf(anchor) == _document.root.id
        ? _pinPlacedSides()
        : _document;
    final (next, id) = MindMapOps.addSibling(base, anchor, before: before);
    if (id == null) return null;
    _editingId = null;
    commit(next, select: id);
    if (edit) startEditing(id);
    return id;
  }

  /// 在中心主题的 [side]（`kMindMapSideLeft` / `kMindMapSideRight`）一侧
  /// 加一个分支、选中并进入编辑（平衡结构的“向左 / 向右添加”）；已有分支
  /// 先固定在画面上的一侧，不随新分支换边。连同固定是一步撤销。
  String? addBranch(String side, {bool edit = true}) {
    final (next, id) = MindMapOps.addChild(
      _pinPlacedSides(),
      _document.root.id,
      side: side,
    );
    if (id == null) return null;
    _editingId = null;
    commit(next, select: id);
    if (edit) startEditing(id);
    return id;
  }

  MindMapDocument _pinPlacedSides() {
    final sides = placedRootSides?.call();
    if (sides == null || !_balanced) return _document;
    return MindMapOps.pinRootSides(_document, sides);
  }

  /// 删除选中的节点（根不删），选中改到相邻的同级或父节点。[keepEditing]
  /// 时接着编辑新选中的主题（键盘弹着时从附件条删除：不结束编辑，键盘就
  /// 不收起）。
  void deleteSelected({bool keepEditing = false}) {
    final id = selectedId;
    if (id == null) return;
    final index = _document.index;
    final parent = index.parentOf(id);
    if (parent == null) return;
    final siblings = index[parent]!.children;
    final position = index.positionOf(id);
    final nextSelection = position + 1 < siblings.length
        ? siblings[position + 1].id
        : position > 0
        ? siblings[position - 1].id
        : parent;
    _editingId = keepEditing ? nextSelection : null;
    _lastCoalesceKey = null;
    commit(
      MindMapOps.removeNodes(_document, <String>[id]),
      select: nextSelection,
    );
  }

  void toggleCollapsed(String id) {
    final node = _document.index[id];
    if (node == null || node.children.isEmpty) return;
    commit(MindMapOps.setCollapsed(_document, id, !node.collapsed));
  }

  /// 按落点挪动节点。落点指定了一侧（拖到根的左边或右边）时先把其余分支
  /// 固定在画面上的一侧，只有被拖的这个换边。
  void move(String id, MindMapDropTarget target) {
    final base = target.side == null ? _document : _pinPlacedSides();
    final next = MindMapOps.moveNode(
      base,
      id,
      target.parentId,
      target.index,
      side: target.side,
    );
    // 落点没变时不为固定其余分支单独记一步撤销。
    commit(identical(next, base) ? _document : next, select: id);
  }

  /// 改一个节点（样式、贴纸、标签、备注、链接、待办……），一步撤销；
  /// [coalesce] 相同的连续改动（如备注打字）合并为一步。
  void updateNode(
    String id,
    MindMapNode Function(MindMapNode node) update, {
    Object? coalesce,
  }) => commit(
    MindMapOps.updateNode(_document, id, update),
    coalesce: coalesce,
    animate: coalesce == null,
  );

  /// 切换待办完成状态（不是待办的节点不动）。
  void toggleTask(String id) => updateNode(id, (node) {
    if (!node.isTask) return node;
    return node.copyWith(
      task: <String, Object?>{...?node.task, 'done': !node.taskDone},
    );
  });

  /// 改导图级的设置（结构、主题、连线、间距、彩虹、点阵）。
  void updateDocument(MindMapDocument Function(MindMapDocument) update) =>
      commit(update(_document));
}

final class _Snapshot {
  const _Snapshot(this.document, this.selectedId);

  final MindMapDocument document;
  final String? selectedId;
}

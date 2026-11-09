import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/foundation.dart';

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../models/diary_thumbnail_rows.dart';
import 'diary_block_reorder.dart';
import 'diary_table_editing.dart';
import 'diary_toggle_state.dart';

/// 段落选择模式的选择状态：选中了哪些块、从哪一块开始连选、进入时键盘
/// 是否弹着。挂在 `DiaryEditorController.blockSelection` 上。
///
/// - 选中的单位是“块”（各自连同子树）：表格、收起的折叠块各算一块，格子
///   与收起的内容不单独选；并排的几张小图算一块（一起选、一起取消）。
/// - [roots] 始终规整为最上层的块、按文档先后：选了父块就含它的子块，
///   子块不再单列（见 [diaryBlockRoots]）。
/// - 模式期间正文没有选区：进入时清掉，上游点按、长按落下的选区由编辑
///   控制器挡掉（见 `_DiaryEditorState.updateSelectionWithReason`）；别处把
///   选区设成非空（撤销、页面动作）时由控制器调用 [exit] 退出。
/// - 退出后由正文的段落选择层按 [takeExit] 决定光标与键盘（只有它知道焦点
///   与键盘），这里只记下退出方式与当时选中的块。
///
/// 输入：编辑状态（读文档、监听事务）；输出：[active] 与选择变化的通知；
/// 不改文档。
class DiaryBlockSelection extends ChangeNotifier {
  DiaryBlockSelection(this._state) {
    _transactions = _state.transactionStream.listen((event) {
      if (event.$1 == af.TransactionTime.after) _prune();
    });
  }

  final af.EditorState _state;
  late final StreamSubscription<af.EditorTransactionValue> _transactions;

  final ValueNotifier<bool> _active = ValueNotifier<bool>(false);

  /// 是否处在段落选择模式。页面与工具栏只在进出时重建，不随每次点选。
  ValueListenable<bool> get active => _active;
  bool get isActive => _active.value;

  List<af.Node> _roots = const [];

  /// 选中的块：最上层的块，按文档先后。
  List<af.Node> get roots => _roots;
  int get count => _roots.length;

  /// 上次点选（或连选起点）的块：Shift + 点按从它连到点的那一块。
  af.Node? _anchor;
  af.Node? get anchor => _anchor;

  bool _keyboardWasVisible = false;

  /// 进入时软键盘是否弹着：「完成」后据此决定是否重新弹出。
  bool get keyboardWasVisible => _keyboardWasVisible;

  (DiaryBlockSelectionExit, List<af.Node>)? _exit;

  /// 进入段落选择模式并选中 [nodes]；已在模式里时换成这些块。正文选区随即
  /// 清掉（输入法断开、软键盘收起）。
  void enter(Iterable<af.Node> nodes, {required bool keyboardVisible}) {
    final units = [for (final node in nodes) ..._members(node)];
    if (!isActive) _keyboardWasVisible = keyboardVisible;
    _exit = null;
    _roots = diaryBlockRoots(units);
    _anchor = units.isEmpty ? null : units.last;
    _active.value = true;
    if (_state.selection != null) {
      unawaited(_state.updateSelectionWithReason(null));
    }
    notifyListeners();
  }

  /// 退出段落选择模式。之后的光标与键盘由段落选择层按 [how] 处理。
  void exit([DiaryBlockSelectionExit how = DiaryBlockSelectionExit.done]) {
    if (!isActive) return;
    _exit = (how, _roots);
    _roots = const [];
    _anchor = null;
    _active.value = false;
    notifyListeners();
  }

  /// 取走最近一次退出的方式与当时选中的块（只取一次）。
  (DiaryBlockSelectionExit, List<af.Node>)? takeExit() {
    final exit = _exit;
    _exit = null;
    return exit;
  }

  /// [node] 自己被选中。
  bool isSelected(af.Node node) => _roots.contains(node);

  /// [node] 因为祖先被选中而连带选中。
  bool isCovered(af.Node node) =>
      _roots.any((root) => root != node && root.isParentOf(node));

  /// 点按 [unit]：没选中（也没被祖先连带）时选中它，否则取消——点在被
  /// 连带的子块上取消的是那个祖先。
  void toggle(af.Node unit) {
    if (!isActive) return;
    final members = _members(unit);
    final covering = _coveringRoots(members);
    _roots = covering.isNotEmpty
        ? [
            for (final root in _roots)
              if (!covering.contains(root)) root,
          ]
        : diaryBlockRoots([..._roots, ...members]);
    _anchor = unit;
    notifyListeners();
  }

  /// Shift + 点按：从 [anchor] 到 [unit]（阅读顺序，含两端）的块全部选中。
  /// 没有起点时等同点按。
  void selectRange(af.Node unit) {
    final anchor = _anchor;
    if (anchor == null || anchor.parent == null) {
      toggle(unit);
      return;
    }
    _roots = rangeApplied(base: _roots, from: anchor, to: unit, select: true);
    notifyListeners();
  }

  /// 在 [base] 上把 [from]–[to]（阅读顺序，含两端）这一段全部选中或取消，
  /// 返回新的选择。页边距里滑动连选时，每一帧都以开始滑动时的选择为底重新
  /// 算，滑回去的块恢复原状。
  List<af.Node> rangeApplied({
    required List<af.Node> base,
    required af.Node from,
    required af.Node to,
    required bool select,
  }) {
    final units = diaryBlockSelectionUnits(_state.document.root);
    var start = units.indexOf(from);
    var end = units.indexOf(to);
    if (start < 0 || end < 0) return base;
    if (start > end) (start, end) = (end, start);
    final range = [
      for (final unit in units.sublist(start, end + 1)) ..._members(unit),
    ];
    if (select) return diaryBlockRoots([...base, ...range]);
    final covering = _coveringRoots(range, within: base);
    return [
      for (final root in base)
        if (!covering.contains(root)) root,
    ];
  }

  /// 把选择换成 [roots]（页边距里连选的每一帧、批量操作换了块之后）。
  void replace(Iterable<af.Node> roots) {
    if (!isActive) return;
    _roots = diaryBlockRoots(roots);
    notifyListeners();
  }

  /// 全选：所有顶层块。
  void selectAll() => replace(_state.document.root.children);

  /// 全部取消，仍留在模式里。
  void clear() => replace(const []);

  /// 所有顶层块都已选中。
  bool get isAllSelected {
    final top = _state.document.root.children;
    return top.isNotEmpty && top.every(_roots.contains);
  }

  /// [members] 里任一块被选中或被祖先连带时，对应的那些已选块。
  Set<af.Node> _coveringRoots(
    List<af.Node> members, {
    List<af.Node>? within,
  }) => {
    for (final root in within ?? _roots)
      if (members.any((member) => member == root || root.isParentOf(member)))
        root,
  };

  /// 一起选、一起取消的块：并排的几张小图为整排，其余为它自己。
  static List<af.Node> _members(af.Node unit) {
    final row = diaryThumbnailRowOf(unit);
    final parent = unit.parent;
    if (row == null || parent == null || row.end - row.start < 2) {
      return [unit];
    }
    return parent.children.sublist(row.start, row.end);
  }

  /// 事务之后：去掉已不在文档里的块，按文档先后重排（移动改变了先后）。
  void _prune() {
    if (_roots.isEmpty && _anchor == null) return;
    final next = diaryBlockRoots(_roots);
    if (_anchor?.parent == null) _anchor = null;
    if (listEquals(next, _roots)) return;
    _roots = next;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_transactions.cancel());
    _active.dispose();
    super.dispose();
  }
}

/// 退出段落选择模式的方式，决定之后正文的光标与键盘。
enum DiaryBlockSelectionExit {
  /// 「完成」/ Enter：光标回到第一块末尾，进入时键盘弹着就重新弹出。
  done,

  /// 返回键 / Esc：光标同样回去，键盘保持收起。
  dismiss,

  /// 别处接手（点标题、撤销、页面动作、删除后）：不动正文选区。
  release,
}

/// 可选的块，按阅读顺序（先序）：收起的折叠块里的内容看不见、表格的格子与
/// 格内段落不单独选，都不在里面（与段落移动的缝同一规则，见
/// `DiaryBlockGaps`）。
List<af.Node> diaryBlockSelectionUnits(af.Node root) {
  final units = <af.Node>[];
  void visit(Iterable<af.Node> nodes) {
    for (final node in nodes) {
      units.add(node);
      if (!isDiaryToggleCollapsed(node) && node.type != kDiaryBlockTable) {
        visit(node.children);
      }
    }
  }

  visit(root.children);
  return units;
}

/// [node]（点中的块、选区碰到的块）对应的可选单位：格子与格内段落为整个
/// 表格。
af.Node diaryBlockSelectionUnitOf(af.Node node) => diaryTableOf(node) ?? node;

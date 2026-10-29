import 'package:flutter/widgets.dart';

import '../viewmodels/notebook_tree.dart';
import '../viewmodels/notebook_tree_rows.dart';
import '../viewmodels/notebook_view.dart';

/// 管理页的收起与拖动折叠：这一帧藏起哪些行、拖动有子本的本子时整组收进来、
/// 本子到了收起的上级下面时自动展开。
///
/// - 输入：每次构建的书架树与用户的收起状态（`notebookManageCollapsedProvider`）；
///   列表的拿起 / 松手 / 放下；
/// - 输出：[resolve] 给出这一帧按哪些本子收起来排、藏起哪些行；
/// - 副作用：要自动展开的上级在这一帧之后经 [onReveal] 写回（构建期间不能
///   改 provider）。拖动状态变化后由页面自己 setState。
///
/// 拖动的时序：拿起时把被拖那本的子孙收进来（不改用户的收起状态）；落回原位
/// 时列表不会再报告放下，松手就放出来（[dropsInPlace]）；移动了的等放下动画
/// 结束、按新顺序重建时再放出来——松手时就展开会把落点前的行往下推，正在落下
/// 的那一行会落到错位的地方。
class NotebookManageFolding {
  NotebookManageFolding({required this.onReveal});

  /// 把这些上级展开（页面写回 provider，须自己判断 mounted）。
  final void Function(Set<String> ids) onReveal;

  String? _dragFolded;
  int? _dragIndex;

  // 上一次构建时每本的上级；首次构建前为 null，只记录。
  Map<String, String?>? _lastParents;

  // 已决定展开、还没写回的上级：写回前再次构建也按展开排。
  final Set<String> _revealing = <String>{};

  /// 这一帧的收起情况：[collapsed] 为按收起排的本子（行尾按钮的状态），
  /// [folded] 为藏起来的行（收起的、正在拖动的本子的子孙）。
  ///
  /// 本子换了上级（移动到…、编辑页改上级、撤销删除）或新出现（新建子本）时，
  /// 它上面收起着的上级这一帧就按展开排：不然它刚到那里就被藏起来，像是
  /// 消失了，或者先收起一下再展开。
  ({Set<String> collapsed, Set<String> folded}) resolve(
    NotebookTree tree,
    Set<String> stored,
  ) {
    final revealed = _revealMoved(tree, stored);
    final collapsed = revealed.isEmpty ? stored : stored.difference(revealed);
    final dragFolded = _dragFolded;
    return (
      collapsed: collapsed,
      folded: notebookFoldedIds(tree, <String>{...collapsed, ?dragFolded}),
    );
  }

  Set<String> _revealMoved(NotebookTree tree, Set<String> collapsed) {
    final last = _lastParents;
    _lastParents = <String, String?>{
      for (final notebook in tree.notebooks) notebook.id: notebook.parentId,
    };
    if (last == null || collapsed.isEmpty) return _revealing;
    final reveal = <String>{
      for (final notebook in tree.notebooks)
        if (notebook.parentId != null &&
            (!last.containsKey(notebook.id) ||
                last[notebook.id] != notebook.parentId))
          for (final ancestor in tree.ancestorsOf(notebook.id))
            if (collapsed.contains(ancestor.id)) ancestor.id,
    };
    if (reveal.difference(_revealing).isEmpty) return _revealing;
    final scheduled = _revealing.isNotEmpty;
    _revealing.addAll(reveal);
    if (!scheduled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ids = _revealing.toSet();
        _revealing.clear();
        onReveal(ids);
      });
    }
    return _revealing;
  }

  /// 拿起分组里的第 [index] 行；返回 true 时页面须重建（子孙要收进来）。
  bool startDrag(NotebookView notebook, int index) {
    _dragIndex = index;
    final folded = notebook.hasChildren ? notebook.id : null;
    if (folded == _dragFolded) return false;
    _dragFolded = folded;
    return true;
  }

  /// 松手，[insertIndex] 为列表未修正的插入位置。落回原位（之后不会再有
  /// 放下的回调）时返回 true，页面就此调用 [unfold]。
  bool dropsInPlace(int insertIndex) {
    final start = _dragIndex;
    _dragIndex = null;
    return start == null || insertIndex == start || insertIndex == start + 1;
  }

  /// 放出拖动时收进来的子孙；没有收进来的时返回 null。[moved] 时返回这些
  /// 子孙：它们在新位置重新挂载（列表按行号区分条目），页面标成“出现”从
  /// 0 高度展开，而不是直接弹出来。
  Set<String>? unfold(NotebookTree tree, {required bool moved}) {
    final id = _dragFolded;
    if (id == null) return null;
    _dragFolded = null;
    if (!moved) return const <String>{};
    return <String>{for (final notebook in tree.descendantsOf(id)) notebook.id};
  }
}

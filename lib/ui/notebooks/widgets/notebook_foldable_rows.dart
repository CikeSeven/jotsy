import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../widgets/list_item_presence.dart';
import '../providers/notebook_providers.dart';
import '../viewmodels/notebook_tree_rows.dart';
import 'notebook_tree_toggle.dart';

export 'notebook_tree_toggle.dart' show NotebookRowToggle;

/// 可收起的树形列表的一行：[toggle] 为 null 时这一行下面没有列出来的子本。
typedef NotebookFoldableRowBuilder =
    Widget Function(
      BuildContext context,
      NotebookTreeRow row,
      NotebookRowToggle? toggle,
    );

/// 选本列表（选本面板、发布面板子页、上级选择面板、画廊筛选菜单、AI 回顾与
/// 隐私、小组件的选本面板）的可收起树形行，竖排成一列。
///
/// - 输入：按树序列出的 [rows]（`notebookTreeRows`）、[reveal]（选中的本子）
///   与共用的收起状态 [notebookTreeCollapsedProvider]；
/// - 输出：每行经 [itemBuilder] 画出，下面有列出来的子本的行带上
///   [NotebookRowToggle]；被收起的子孙经 [ListItemPresence] 收到 0 高度并
///   淡出（展开时从 0 展开），同时让出焦点、不给读屏；
/// - 副作用：展开 / 收起写回 [notebookTreeCollapsedProvider]（与管理页共用
///   一份，在哪收起别处也收起）。
///
/// 露出选中项：[reveal] 里的本子第一次出现在列表里时，它收起着的上级在这个
/// 列表里按展开排（不写回共用状态）——打开面板就看得到当前选的是哪本，
/// 不会勾在一本藏起来的子本上。之后用户自己收起那一级照常收起；同一本不再
/// 重复露出。新建后选中的本子随数据流出现时同样露出。
///
/// 收起只改高度、行一直留在原处（按本子 id 区分），列表的行数与各行的状态
/// （勾选补间等）不随收起变化。
class NotebookFoldableRows extends ConsumerStatefulWidget {
  const NotebookFoldableRows({
    super.key,
    required this.rows,
    required this.itemBuilder,
    this.reveal = const <String>{},
    this.glass = false,
  });

  final List<NotebookTreeRow> rows;
  final NotebookFoldableRowBuilder itemBuilder;
  final Set<String> reveal;

  /// 行主体是否为玻璃表面（交给 [ListItemPresence.glass]）。
  final bool glass;

  @override
  ConsumerState<NotebookFoldableRows> createState() =>
      _NotebookFoldableRowsState();
}

class _NotebookFoldableRowsState extends ConsumerState<NotebookFoldableRows> {
  /// 为露出选中项而在这个列表里按展开排的上级。
  final Set<String> _revealed = <String>{};

  /// 已经露出过的选中项（出现在列表里之后才算）。
  final Set<String> _seen = <String>{};

  @override
  void initState() {
    super.initState();
    _revealNew();
  }

  @override
  void didUpdateWidget(NotebookFoldableRows oldWidget) {
    super.didUpdateWidget(oldWidget);
    _revealNew();
  }

  void _revealNew() {
    if (widget.reveal.isEmpty) return;
    final listed = <String>{for (final row in widget.rows) row.notebook.id};
    for (final id in widget.reveal) {
      if (_seen.contains(id) || !listed.contains(id)) continue;
      _seen.add(id);
      _revealed.addAll(notebookRowAncestors(widget.rows, id));
    }
  }

  void _toggle(String id, {required bool expanded}) {
    final notifier = ref.read(notebookTreeCollapsedProvider.notifier);
    if (!expanded) {
      notifier.expand(<String>[id]);
      return;
    }
    // 收起：露出时按展开排的这一级不再例外；共用状态里没有时再加上。
    if (_revealed.remove(id)) setState(() {});
    if (!ref.read(notebookTreeCollapsedProvider).contains(id)) {
      notifier.collapseAll(<String>[id]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stored = ref.watch(notebookTreeCollapsedProvider);
    final collapsed = _revealed.isEmpty ? stored : stored.difference(_revealed);
    final fold = notebookRowsFold(widget.rows, collapsed);
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final row in widget.rows)
          _row(context, row, fold.parents, collapsed, fold.folded, duration),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    NotebookTreeRow row,
    Set<String> parents,
    Set<String> collapsed,
    Set<String> folded,
    Duration duration,
  ) {
    final id = row.notebook.id;
    final hidden = folded.contains(id);
    final expanded = !collapsed.contains(id);
    return ListItemPresence(
      key: ValueKey<String>(id),
      visible: !hidden,
      appearing: false,
      duration: duration,
      glass: widget.glass,
      child: ExcludeFocus(
        excluding: hidden,
        child: ExcludeSemantics(
          excluding: hidden,
          child: widget.itemBuilder(
            context,
            row,
            parents.contains(id)
                ? NotebookRowToggle(
                    expanded: expanded,
                    onToggle: () => _toggle(id, expanded: expanded),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

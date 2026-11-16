import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../../notebooks/providers/notebook_providers.dart';
import '../../notebooks/sections/notebook_choice_sheet.dart';
import '../../notebooks/viewmodels/notebook_tree.dart';
import '../../notebooks/viewmodels/notebook_tree_rows.dart';
import '../../notebooks/viewmodels/notebook_view.dart';
import '../../settings/widgets/settings_nav_tile.dart';

/// 快速记录“写日记”写进哪个日记本：一行显示当前选择，点开底部面板挑选。
///
/// 只列能写进去的本子（普通、非私密含继承、未合上）：私密日记本里的日记从
/// 桌面上一点就能新建，等于在桌面上留了一个私密本子的入口，所以不提供。
/// 选中的本子后来不能写了（删除、合上、变私密）时这一行显示“不指定”，
/// 小组件与打开时也都按不指定处理。
class HomeWidgetNotebookChoice extends ConsumerWidget {
  const HomeWidgetNotebookChoice({
    super.key,
    required this.notebookId,
    required this.onChanged,
  });

  final String? notebookId;
  final ValueChanged<String?> onChanged;

  static bool _writable(NotebookView notebook) =>
      notebook.isManual && !notebook.isPrivate && !notebook.isClosed;

  /// 挑选：“不指定”与能写进去的本子（树序缩进、可收起；上级不能写时子本
  /// 往外提一级）。
  Future<void> _pick(
    BuildContext context,
    NotebookTree? tree,
    String? current,
  ) async {
    final l10n = context.l10n;
    final picked = await showNotebookChoiceSheet(
      context,
      title: l10n.homeWidgetQuickNotebook,
      rows: tree == null
          ? const <NotebookTreeRow>[]
          : notebookTreeRows(tree, include: _writable),
      selectedId: current,
      lead: NotebookChoiceLead(
        label: l10n.homeWidgetQuickNotebookNone,
        icon: FontAwesomeIcons.ban,
      ),
      leadSelected: current == null,
      iconOf: (_) => FontAwesomeIcons.book,
    );
    if (picked == null) return;
    onChanged(picked.notebookId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tree = ref.watch(notebookTreeProvider);
    final id = notebookId;
    final selected = id == null ? null : tree?[id];
    final current = selected != null && _writable(selected) ? selected : null;
    return SettingsNavTile(
      icon: FontAwesomeIcons.book,
      title: l10n.homeWidgetQuickNotebook,
      value: current?.name ?? l10n.homeWidgetQuickNotebookNone,
      onTap: () => _pick(context, tree, current?.id),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../../notebooks/providers/notebook_providers.dart';
import '../../notebooks/viewmodels/notebook_view.dart';
import '../../settings/widgets/settings_nav_tile.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';

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

  Future<void> _pick(
    BuildContext context,
    List<NotebookView> notebooks,
    String? current,
  ) async {
    final l10n = context.l10n;
    // 空串表示“不指定”：底部面板被划掉关闭时返回 null，要与之区分。
    final picked = await showAppModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (BuildContext sheetContext) {
        final theme = Theme.of(sheetContext);
        final colors = theme.colorScheme;
        Widget check(bool selected) => selected
            ? FaIcon(FontAwesomeIcons.check, size: 14, color: colors.primary)
            : const SizedBox.shrink();
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 24),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  l10n.homeWidgetQuickNotebook,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const FaIcon(FontAwesomeIcons.ban, size: 16),
                title: Text(l10n.homeWidgetQuickNotebookNone),
                trailing: check(current == null),
                onTap: () => Navigator.of(sheetContext).pop(''),
              ),
              for (final notebook in notebooks)
                ListTile(
                  contentPadding: EdgeInsetsDirectional.only(
                    start: 24.0 + notebook.depth * 16,
                    end: 24,
                  ),
                  leading: const FaIcon(FontAwesomeIcons.book, size: 16),
                  title: Text(notebook.name),
                  trailing: check(notebook.id == current),
                  onTap: () => Navigator.of(sheetContext).pop(notebook.id),
                ),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    onChanged(picked.isEmpty ? null : picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notebooks = <NotebookView>[
      for (final notebook in ref.watch(notebooksProvider).value ?? const [])
        if (_writable(notebook)) notebook,
    ];
    final current = notebooks.where((n) => n.id == notebookId).firstOrNull;
    return SettingsNavTile(
      icon: FontAwesomeIcons.book,
      title: l10n.homeWidgetQuickNotebook,
      value: current?.name ?? l10n.homeWidgetQuickNotebookNone,
      onTap: () => _pick(context, notebooks, current?.id),
    );
  }
}

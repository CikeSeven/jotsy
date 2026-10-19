import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../viewmodels/notebook_view.dart';
import '../widgets/notebook_cover_tile.dart';

/// 对一个日记本可做的操作（书架长按菜单与管理页“更多”面板共用）。
enum NotebookAction { edit, pin, unpin, close, reopen, merge, convert, delete }

/// 书架长按菜单的四项：编辑 / 置顶或取消置顶 / 合上或重新打开 / 删除。
List<NotebookAction> notebookQuickActions(NotebookView notebook) =>
    <NotebookAction>[
      NotebookAction.edit,
      notebook.isPinned ? NotebookAction.unpin : NotebookAction.pin,
      notebook.isClosed ? NotebookAction.reopen : NotebookAction.close,
      NotebookAction.delete,
    ];

String notebookActionLabel(AppLocalizations l10n, NotebookAction action) =>
    switch (action) {
      NotebookAction.edit => l10n.commonEdit,
      NotebookAction.pin => l10n.notebookActionPin,
      NotebookAction.unpin => l10n.notebookActionUnpin,
      NotebookAction.close => l10n.notebookActionClose,
      NotebookAction.reopen => l10n.notebookActionReopen,
      NotebookAction.merge => l10n.notebookActionMerge,
      NotebookAction.convert => l10n.notebookActionConvert,
      NotebookAction.delete => l10n.commonDelete,
    };

FaIconData notebookActionIcon(NotebookAction action) => switch (action) {
  NotebookAction.edit => FontAwesomeIcons.penToSquare,
  NotebookAction.pin => FontAwesomeIcons.thumbtack,
  NotebookAction.unpin => FontAwesomeIcons.thumbtackSlash,
  NotebookAction.close => FontAwesomeIcons.boxArchive,
  NotebookAction.reopen => FontAwesomeIcons.bookOpen,
  NotebookAction.merge => FontAwesomeIcons.codeMerge,
  NotebookAction.convert => FontAwesomeIcons.book,
  NotebookAction.delete => FontAwesomeIcons.trashCan,
};

Future<T?> _showSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: builder,
  );
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.s,
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 管理页行尾“更多”的底部面板：编辑、置顶、合并到…、合上 / 重新打开、
/// 转为普通日记本（仅智能本）、删除（error 色）。
/// 项目多且带说明，按 DESIGN.md §5.4 用面板而不是弹出菜单。
Future<NotebookAction?> showNotebookActionsSheet(
  BuildContext context, {
  required NotebookView notebook,
}) {
  return _showSheet<NotebookAction>(context, (BuildContext sheetContext) {
    final l10n = sheetContext.l10n;
    final scheme = Theme.of(sheetContext).colorScheme;
    final actions = <(NotebookAction, String?, bool)>[
      (NotebookAction.edit, null, true),
      (
        notebook.isPinned ? NotebookAction.unpin : NotebookAction.pin,
        null,
        true,
      ),
      if (notebook.isManual) (NotebookAction.merge, null, true),
      notebook.isClosed
          ? (NotebookAction.reopen, null, true)
          : (NotebookAction.close, l10n.notebookActionCloseHint, true),
      if (notebook.isSmart)
        (NotebookAction.convert, l10n.notebookActionConvertHint, true),
      (NotebookAction.delete, null, true),
    ];
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: AppSpacing.l + MediaQuery.paddingOf(sheetContext).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SheetTitle(notebook.name),
          for (final (action, subtitle, enabled) in actions)
            ListTile(
              enabled: enabled,
              titleAlignment: ListTileTitleAlignment.center,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
              ),
              iconColor: action == NotebookAction.delete ? scheme.error : null,
              textColor: action == NotebookAction.delete ? scheme.error : null,
              leading: FaIcon(notebookActionIcon(action), size: 18),
              title: Text(notebookActionLabel(l10n, action)),
              subtitle: subtitle == null ? null : Text(subtitle),
              onTap: () => Navigator.of(sheetContext).pop(action),
            ),
        ],
      ),
    );
  });
}

/// “合并到…”：列出其他普通日记本，点一本返回它；关闭返回 null。
Future<NotebookView?> showNotebookMergeTargetSheet(
  BuildContext context, {
  required List<NotebookView> candidates,
  required Map<String, int> counts,
}) {
  return _showSheet<NotebookView>(context, (BuildContext sheetContext) {
    final l10n = sheetContext.l10n;
    final theme = Theme.of(sheetContext);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      builder: (BuildContext context, ScrollController controller) {
        return ListView(
          controller: controller,
          padding: EdgeInsets.only(
            bottom: AppSpacing.l + MediaQuery.paddingOf(context).bottom,
          ),
          children: <Widget>[
            _SheetTitle(l10n.notebookMergeSheetTitle),
            if (candidates.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  l10n.notebookMergeEmpty,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (final notebook in candidates)
              ListTile(
                titleAlignment: ListTileTitleAlignment.center,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.xs,
                ),
                leading: NotebookCoverTile.mini(
                  icon: notebook.icon,
                  color: notebook.color,
                  coverPath: notebook.coverPath,
                  closed: notebook.isClosed,
                ),
                title: Text(
                  notebook.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  l10n.notebookEntryCount(counts[notebook.id] ?? 0),
                ),
                onTap: () => Navigator.of(sheetContext).pop(notebook),
              ),
          ],
        );
      },
    );
  });
}

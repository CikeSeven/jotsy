import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../widgets/expressive_choice_tile.dart';
import '../viewmodels/notebook_view.dart';

/// 删除日记本的确认框。返回 null 为取消；否则为是否连同日记移进回收站。
///
/// 普通日记本给两个选项：默认“只删除日记本”（日记仍在全部日记里），或
/// “连同日记移到回收站”（选中时确认键变为 error 色）。智能日记本没有收录
/// 关系，只说明日记不受影响。
Future<bool?> showNotebookDeleteDialog(
  BuildContext context, {
  required NotebookView notebook,
  required int count,
}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext _) =>
        _NotebookDeleteDialog(notebook: notebook, count: count),
  );
}

class _NotebookDeleteDialog extends StatefulWidget {
  const _NotebookDeleteDialog({required this.notebook, required this.count});

  final NotebookView notebook;
  final int count;

  @override
  State<_NotebookDeleteDialog> createState() => _NotebookDeleteDialogState();
}

class _NotebookDeleteDialogState extends State<_NotebookDeleteDialog> {
  bool _trashDiaries = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final manual = widget.notebook.isManual;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.notebookDeleteTitle(widget.notebook.name)),
      content: manual
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ExpressiveChoiceTile(
                  label: l10n.notebookDeleteKeepDiaries,
                  description: l10n.notebookDeleteKeepDiariesHint(widget.count),
                  selected: !_trashDiaries,
                  onTap: () => setState(() => _trashDiaries = false),
                ),
                ExpressiveChoiceTile(
                  label: l10n.notebookDeleteWithDiaries,
                  description: l10n.notebookDeleteWithDiariesHint,
                  selected: _trashDiaries,
                  destructive: true,
                  onTap: () => setState(() => _trashDiaries = true),
                ),
              ],
            )
          : Text(l10n.notebookDeleteSmartHint),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: _trashDiaries ? scheme.error : scheme.primary,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          onPressed: () => Navigator.of(context).pop(_trashDiaries),
          child: Text(l10n.commonDelete),
        ),
      ],
    );
  }
}

/// 合并的确认框：“把「A」的 N 篇日记并入「B」并删除「A」？”。确认返回 true。
Future<bool> showNotebookMergeConfirmDialog(
  BuildContext context, {
  required NotebookView source,
  required NotebookView target,
  required int count,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final l10n = dialogContext.l10n;
      final scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(l10n.notebookMergeConfirmTitle),
        content: Text(
          l10n.notebookMergeConfirm(source.name, count, target.name),
        ),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: scheme.primary,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.notebookMergeAction),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

/// 智能日记本转为普通日记本的确认框：“把「X」转为普通日记本？现在符合条件的
/// N 篇会收进来……”。不可撤销，确认键为主色（不删除任何数据）。确认返回 true。
Future<bool> showNotebookConvertConfirmDialog(
  BuildContext context, {
  required NotebookView notebook,
  required int count,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final l10n = dialogContext.l10n;
      final scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(l10n.notebookConvertTitle(notebook.name)),
        content: Text(l10n.notebookConvertMessage(count)),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: scheme.primary,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.notebookConvertAction),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

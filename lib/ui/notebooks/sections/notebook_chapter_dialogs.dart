import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../widgets/app_modal/app_dialog.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';

/// 新建 / 重命名章节的弹窗：一个名称输入框（去首尾空白后 1–40 字，可重名）。
/// 返回规整后的名称，取消返回 null。[initial] 不为空时是重命名。
Future<String?> showNotebookChapterTitleDialog(
  BuildContext context, {
  String? initial,
}) {
  return showAppDialog<String>(
    context: context,
    builder: (BuildContext _) => _ChapterTitleDialog(initial: initial),
  );
}

class _ChapterTitleDialog extends StatefulWidget {
  const _ChapterTitleDialog({this.initial});

  final String? initial;

  @override
  State<_ChapterTitleDialog> createState() => _ChapterTitleDialogState();
}

class _ChapterTitleDialogState extends State<_ChapterTitleDialog> {
  // 控制器跟随对话框生命周期释放：关闭动画期间仍可能重建。
  late final TextEditingController _title = TextEditingController(
    text: widget.initial ?? '',
  )..addListener(() => setState(() {}));

  bool get _canSubmit => _title.text.trim().isNotEmpty;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop(_title.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final renaming = widget.initial != null;
    return AlertDialog(
      title: Text(
        renaming
            ? l10n.notebookChapterRenameTitle
            : l10n.notebookContentsNewChapter,
      ),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _title,
          autofocus: true,
          maxLength: NotebookChapter.maxTitleLength,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l10n.notebookChapterTitleLabel,
            hintText: l10n.notebookChapterTitleHint,
          ),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: scheme.primary,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          onPressed: _canSubmit ? _submit : null,
          child: Text(renaming ? l10n.commonSave : l10n.commonCreate),
        ),
      ],
    );
  }
}

/// 删除章节的确认：“删除章节「X」？其中的 N 篇回到未分章，日记不会被删除”。
/// 确认键为 error 色。确认返回 true。
Future<bool> showNotebookChapterDeleteDialog(
  BuildContext context, {
  required String title,
  required int count,
}) async {
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final l10n = dialogContext.l10n;
      final scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        content: Text(l10n.notebookChapterDeleteConfirm(title, count)),
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
              foregroundColor: scheme.error,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

/// “移到章节…”的小面板：各章（按顺序）+ 未分章。返回选中的目标
/// （`chapterId` 为 null 即未分章），关闭面板返回 null。
Future<({String? chapterId})?> showNotebookChapterPickerSheet(
  BuildContext context, {
  required List<NotebookChapter> chapters,
}) {
  return showAppModalBottomSheet<({String? chapterId})>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) {
      final theme = Theme.of(sheetContext);
      final scheme = theme.colorScheme;
      final l10n = sheetContext.l10n;
      Widget option(String label, String? chapterId, FaIconData icon) =>
          ListTile(
            key: ValueKey<String>(
              'notebook_chapter_pick_${chapterId ?? '_unassigned'}',
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
            ),
            leading: FaIcon(icon, size: 16, color: scheme.onSurfaceVariant),
            title: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.of(sheetContext).pop((chapterId: chapterId)),
          );
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.s,
              ),
              child: Text(
                l10n.notebookContentsMoveSheetTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: AppSpacing.l),
                children: <Widget>[
                  for (final chapter in chapters)
                    option(chapter.title, chapter.id, FontAwesomeIcons.folder),
                  option(
                    l10n.notebookChapterUnassigned,
                    null,
                    FontAwesomeIcons.folderMinus,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

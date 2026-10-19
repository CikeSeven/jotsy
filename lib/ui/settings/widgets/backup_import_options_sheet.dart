import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/backup_import_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/expressive_choice_tile.dart';
import '../../widgets/expressive_state_blend.dart';
import 'backup_import_folder_section.dart';
import 'journal_import_source_labels.dart';

/// 打开导入方式面板：概述导入文件并返回所选 [BackupImportMode]，取消返回 null。
///
/// 默认选中最安全的“合并”。会改写本机数据的方式以 error 色标出，确认按钮
/// 随之从“导入”换成 error 色的“继续”——它只进入下一步，覆盖仍要经严重警告
/// 确认。只有合并一种方式（文件里没有本机已存在的日记，且不是完整备份）时
/// 不显示单选列表，只说明合并的效果。
///
/// 传入 [folderChoice]（其他应用的导出带有来源日记本 / 文件夹时）才多出
/// “原来的日记本 / 文件夹”一节，所选方式写回 [folderChoice]，概要与说明
/// 按该方式的预检结果显示；不传时面板与以前完全相同。
Future<BackupImportMode?> showBackupImportOptionsSheet(
  BuildContext context, {
  required BackupArchivePreview preview,
  BackupImportFolderChoice? folderChoice,
}) {
  return showModalBottomSheet<BackupImportMode>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    // 三个带说明的选项在矮屏或大字号下会超出默认 9/16 屏高，放开上限按内容
    // 撑高，仍超出屏幕时由内部滚动兜底。
    isScrollControlled: true,
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) =>
        BackupImportOptionsSheet(preview: preview, folderChoice: folderChoice),
  );
}

/// 导入方式面板内容；选中态只在面板内维护，确认时随路由结果返回。
class BackupImportOptionsSheet extends StatefulWidget {
  const BackupImportOptionsSheet({
    super.key,
    required this.preview,
    this.folderChoice,
  });

  final BackupArchivePreview preview;
  final BackupImportFolderChoice? folderChoice;

  @override
  State<BackupImportOptionsSheet> createState() =>
      _BackupImportOptionsSheetState();
}

class _BackupImportOptionsSheetState extends State<BackupImportOptionsSheet> {
  BackupImportMode _mode = BackupImportMode.merge;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final folderChoice = widget.folderChoice;
    final preview = folderChoice?.preview ?? widget.preview;
    final modes = preview.availableModes;
    final overwrites = _mode.overwritesLocalData;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.backupImportOptionsTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            _ArchiveSummary(preview: preview),
            if (folderChoice != null)
              BackupImportFolderSection(
                folderCount: folderChoice.folderCount,
                selected: folderChoice.selected,
                onChanged: (mode) =>
                    setState(() => folderChoice.selected = mode),
              ),
            const SizedBox(height: AppSpacing.l),
            if (modes.length > 1)
              for (final mode in modes)
                ExpressiveChoiceTile(
                  label: _modeLabel(l10n, mode),
                  description: _modeDescription(l10n, mode, preview),
                  selected: _mode == mode,
                  destructive: mode.overwritesLocalData,
                  onTap: () => setState(() => _mode = mode),
                )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Text(
                  l10n.backupImportModeMergeDescription,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.m),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.commonCancel),
                ),
                const SizedBox(width: AppSpacing.s),
                ExpressiveStateBlend(
                  active: overwrites,
                  builder: (BuildContext context, double t, Widget? child) {
                    return TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Color.lerp(
                          colorScheme.primary,
                          colorScheme.error,
                          t,
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(_mode),
                      child: Text(
                        overwrites
                            ? l10n.commonContinue
                            : l10n.dataMgmtImportAction,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _modeLabel(AppLocalizations l10n, BackupImportMode mode) {
  return switch (mode) {
    BackupImportMode.merge => l10n.backupImportModeMerge,
    BackupImportMode.mergeOverwrite => l10n.backupImportModeOverwriteExisting,
    BackupImportMode.replaceAll => l10n.backupImportModeReplaceAll,
  };
}

String _modeDescription(
  AppLocalizations l10n,
  BackupImportMode mode,
  BackupArchivePreview preview,
) {
  final description = _baseModeDescription(l10n, mode, preview);
  // 同一个日记本的定义也会被替换（名称、封面、章节等），在说明末尾补一行；
  // 日记本重复本身不决定是否提供这种方式。
  if (mode == BackupImportMode.mergeOverwrite &&
      preview.existingNotebookCount > 0) {
    return '$description\n'
        '${l10n.backupImportModeOverwriteNotebooksExtra(preview.existingNotebookCount)}';
  }
  return description;
}

String _baseModeDescription(
  AppLocalizations l10n,
  BackupImportMode mode,
  BackupArchivePreview preview,
) {
  return switch (mode) {
    BackupImportMode.merge => l10n.backupImportModeMergeDescription,
    // 只有纪念日重复时单独一句；日记与纪念日都有重复时在日记说明后补一行。
    BackupImportMode.mergeOverwrite when preview.existingDiaryCount == 0 =>
      l10n.backupImportModeOverwriteAnniversariesOnly(
        preview.existingAnniversaryCount,
      ),
    BackupImportMode.mergeOverwrite when preview.existingAnniversaryCount > 0 =>
      '${l10n.backupImportModeOverwriteExistingDescription(preview.existingDiaryCount)}\n'
          '${l10n.backupImportModeOverwriteAnniversariesExtra(preview.existingAnniversaryCount)}',
    BackupImportMode.mergeOverwrite =>
      l10n.backupImportModeOverwriteExistingDescription(
        preview.existingDiaryCount,
      ),
    BackupImportMode.replaceAll => l10n.backupImportModeReplaceAllDescription,
  };
}

/// 文件概要：类型（其他应用的导出注明来源）、单篇时的标题、日记与标签数、
/// 是否含设置、与本机重复数、将被跳过的缺失媒体数。
class _ArchiveSummary extends StatelessWidget {
  const _ArchiveSummary({required this.preview});

  final BackupArchivePreview preview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isFullBackup = preview.kind == BackupArchiveKind.fullBackup;
    final journalSource = preview.journalSource;
    final (icon, kindLabel) = switch (preview.kind) {
      BackupArchiveKind.fullBackup => (
        FontAwesomeIcons.database,
        l10n.backupImportKindFull,
      ),
      BackupArchiveKind.journalExport when journalSource != null => (
        FontAwesomeIcons.rightToBracket,
        l10n.backupImportKindJournal(
          journalImportSourceName(l10n, journalSource),
        ),
      ),
      _ => (FontAwesomeIcons.fileZipper, l10n.backupImportKindDiary),
    };
    final soleTitle = preview.soleDiaryTitle?.trim();
    final detailStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      height: 1.35,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: FaIcon(
            icon,
            size: 16,
            color: colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(width: AppSpacing.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                kindLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (soleTitle != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  soleTitle.isEmpty ? l10n.autoT0065 : soleTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 2),
              Text(
                l10n.backupImportSummary(preview.diaryCount, preview.tagCount),
                style: detailStyle,
              ),
              if (isFullBackup)
                Text(l10n.backupImportIncludesSettings, style: detailStyle),
              if (preview.existingDiaryCount > 0)
                Text(
                  l10n.backupImportExistingCount(preview.existingDiaryCount),
                  style: detailStyle?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (preview.anniversaryCount > 0)
                Text(
                  l10n.backupImportAnniversaryCount(preview.anniversaryCount),
                  style: detailStyle,
                ),
              if (preview.existingAnniversaryCount > 0)
                Text(
                  l10n.backupImportExistingAnniversaryCount(
                    preview.existingAnniversaryCount,
                  ),
                  style: detailStyle?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (preview.missingMediaCount > 0)
                Text(
                  l10n.backupImportMissingMedia(preview.missingMediaCount),
                  style: detailStyle,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

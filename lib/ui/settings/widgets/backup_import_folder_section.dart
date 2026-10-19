import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/backup_import_models.dart';
import '../../../core/services/journal_import_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/expressive_button_group.dart';
import 'choice_sheet_parts.dart';

/// 导入方式面板里“原来的日记本 / 文件夹”一节的输入与结果。
///
/// 只有其他应用的导出、且解析出来源日记本 / 文件夹时，调用方才构造它并传给
/// `chooseBackupImportMode`；备份、日记包与没有文件夹的导出不传，面板与
/// 以前完全相同。面板确认后 [selected] 即用户的选择（取消时内容无意义）。
///
/// 不同落地方式的标签数、已存在的日记本数不同，[previewFor] 给出对应方式的
/// 预检结果（会话里已预先算好，同步取用），面板的概要与覆盖说明、覆盖警告
/// 都按当前所选方式显示。
class BackupImportFolderChoice {
  BackupImportFolderChoice({
    required this.folderCount,
    required this.previewFor,
    required JournalImportFolderMode initial,
  }) : selected = initial;

  /// 来源里不同的日记本 / 文件夹个数（说明文字里的 N）。
  final int folderCount;
  final BackupArchivePreview Function(JournalImportFolderMode mode) previewFor;

  /// 当前所选方式，由面板写入。
  JournalImportFolderMode selected;

  BackupArchivePreview get preview => previewFor(selected);
}

/// 三段按钮 + 随所选方式变化的一行说明。
class BackupImportFolderSection extends StatelessWidget {
  const BackupImportFolderSection({
    super.key,
    required this.folderCount,
    required this.selected,
    required this.onChanged,
  });

  final int folderCount;
  final JournalImportFolderMode selected;
  final ValueChanged<JournalImportFolderMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final hint = switch (selected) {
      JournalImportFolderMode.notebooks =>
        l10n.backupImportFolderModeNotebooksHint(folderCount),
      JournalImportFolderMode.tags => l10n.backupImportFolderModeTagsHint,
      JournalImportFolderMode.both => l10n.backupImportFolderModeBothHint,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ChoiceSheetSectionHeader(
          icon: FontAwesomeIcons.folderOpen,
          label: l10n.backupImportFolderModeTitle,
        ),
        ExpressiveButtonGroup<JournalImportFolderMode>(
          // 三段都只有两三个字，按短标签估算，320dp 窄屏下也保持横排。
          minSegmentWidth: 80,
          segments: <ButtonSegment<JournalImportFolderMode>>[
            ButtonSegment<JournalImportFolderMode>(
              value: JournalImportFolderMode.notebooks,
              label: Text(l10n.backupImportFolderModeNotebooks),
            ),
            ButtonSegment<JournalImportFolderMode>(
              value: JournalImportFolderMode.tags,
              label: Text(l10n.backupImportFolderModeTags),
            ),
            ButtonSegment<JournalImportFolderMode>(
              value: JournalImportFolderMode.both,
              label: Text(l10n.backupImportFolderModeBoth),
            ),
          ],
          selected: <JournalImportFolderMode>{selected},
          onSelectionChanged: (Set<JournalImportFolderMode> selection) =>
              onChanged(selection.single),
        ),
        const SizedBox(height: AppSpacing.s),
        // 三种说明长短不同（窄屏下可能一行或两行），高度变化走补间，不让
        // 下方的导入方式列表跳动。
        AnimatedSize(
          duration: ExpressiveMotion.durationNonZero(
            context,
            ExpressiveMotion.medium,
          ),
          curve: ExpressiveMotion.effects,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              hint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

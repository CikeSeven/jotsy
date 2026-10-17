import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/journal_import_cloud_cookies.dart';
import '../../../core/services/journal_import_models.dart';
import '../../../l10n/app_localizations.dart';
import 'choice_sheet_parts.dart';
import 'journal_import_source_labels.dart';

/// 面板分组（顺序即展示顺序）：日记应用、笔记应用逐项列出导出方式；手机与
/// WPS 云笔记都是在应用内登录官方云服务后直接读取，说明放在分组标题下，
/// 各项以两列紧凑按钮排列，避免七条相同的说明把面板拉得过长。
const List<JournalImportSource> _journalApps = [
  JournalImportSource.dayOne,
  JournalImportSource.journey,
  JournalImportSource.diarium,
  JournalImportSource.daylio,
  JournalImportSource.appleJournal,
  JournalImportSource.diaro,
];

const List<JournalImportSource> _noteApps = [
  JournalImportSource.evernote,
  JournalImportSource.googleKeep,
  JournalImportSource.joplin,
  JournalImportSource.memos,
  JournalImportSource.markdown,
];

const List<JournalImportSource> _phoneNotes = [
  JournalImportSource.xiaomiNotes,
  JournalImportSource.huaweiNotepad,
  JournalImportSource.oppoNotes,
  JournalImportSource.vivoNotes,
  JournalImportSource.honorNotes,
  JournalImportSource.meizuNotes,
  JournalImportSource.wpsNotes,
];

/// 打开来源应用面板，返回所选应用；取消返回 null。
///
/// 点选即返回，不需要再确认：此时还没读取任何文件，后续的文件选择、预检与
/// 导入方式确认都可以取消。每项下方说明该应用怎样导出、可选哪些文件类型。
Future<JournalImportSource?> showJournalImportSourceSheet(
  BuildContext context,
) {
  return showModalBottomSheet<JournalImportSource>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    // 来源较多，按内容撑高并在内部滚动；最高占屏幕 88%，上方始终留出可点按
    // 关闭的遮罩，不让面板看起来像一个新页面。宽度沿用 Material 3 默认的
    // 640 上限（传入 constraints 会替换默认值）。
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxWidth: 640,
      maxHeight: MediaQuery.sizeOf(context).height * 0.88,
    ),
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) => const JournalImportSourceSheet(),
  );
}

class JournalImportSourceSheet extends StatelessWidget {
  const JournalImportSourceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    void pick(JournalImportSource source) => Navigator.of(context).pop(source);
    Widget tile(JournalImportSource source) => _SourceTile(
      icon: journalImportSourceIcon(source),
      name: journalImportSourceName(l10n, source),
      hint: journalImportSourceHint(l10n, source) ?? '',
      onTap: () => pick(source),
    );
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
                  l10n.journalImportSourceTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Text(
                l10n.journalImportSourceHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ChoiceSheetSectionHeader(
              icon: FontAwesomeIcons.book,
              label: l10n.journalImportGroupJournals,
            ),
            for (final source in _journalApps) tile(source),
            ChoiceSheetSectionHeader(
              icon: FontAwesomeIcons.noteSticky,
              label: l10n.journalImportGroupNotes,
            ),
            for (final source in _noteApps) tile(source),
            // 云端笔记需要网页视图登录，只在 Android 与 iOS 上提供。
            if (CloudLoginCookies.supported) ...<Widget>[
              ChoiceSheetSectionHeader(
                icon: FontAwesomeIcons.mobileScreenButton,
                label: l10n.journalImportGroupPhoneNotes,
              ),
              ChoiceSheetSectionHint(l10n.journalImportPhoneNotesHint),
              ChoiceSheetCompactGrid<JournalImportSource>(
                items: _phoneNotes,
                nameOf: (source) => journalImportSourceName(l10n, source),
                onPick: pick,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.name,
    required this.hint,
    required this.onTap,
  });

  final FaIconData icon;
  final String name;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.xs,
        ),
        // 说明常折成两三行；图标与右侧箭头仍相对整项垂直居中，不贴上沿
        // （DESIGN.md §5.4）。
        titleAlignment: ListTileTitleAlignment.center,
        onTap: onTap,
        leading: Container(
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
        title: Text(
          name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 16.5,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        subtitle: Text(
          hint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        trailing: FaIcon(
          FontAwesomeIcons.angleRight,
          size: 14,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/journal_import_models.dart';
import '../../../l10n/app_localizations.dart';

/// 来源应用的展示名称：应用名是专有名词不翻译，Apple 手记按系统中文名。
String journalImportSourceName(
  AppLocalizations l10n,
  JournalImportSource source,
) {
  return switch (source) {
    JournalImportSource.dayOne => 'Day One',
    JournalImportSource.journey => 'Journey',
    JournalImportSource.diarium => 'Diarium',
    JournalImportSource.daylio => 'Daylio',
    JournalImportSource.appleJournal => l10n.journalImportAppleJournal,
  };
}

String _sourceHint(AppLocalizations l10n, JournalImportSource source) {
  return switch (source) {
    JournalImportSource.dayOne => l10n.journalImportDayOneHint,
    JournalImportSource.journey => l10n.journalImportJourneyHint,
    JournalImportSource.diarium => l10n.journalImportDiariumHint,
    JournalImportSource.daylio => l10n.journalImportDaylioHint,
    JournalImportSource.appleJournal => l10n.journalImportAppleJournalHint,
  };
}

FaIconData _sourceIcon(JournalImportSource source) {
  return switch (source) {
    JournalImportSource.dayOne => FontAwesomeIcons.bookOpen,
    JournalImportSource.journey => FontAwesomeIcons.route,
    JournalImportSource.diarium => FontAwesomeIcons.calendarDays,
    JournalImportSource.daylio => FontAwesomeIcons.faceSmile,
    JournalImportSource.appleJournal => FontAwesomeIcons.apple,
  };
}

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
    // 五个带说明的选项在矮屏或大字号下会超出默认高度上限，按内容撑高并在
    // 内部滚动兜底。
    isScrollControlled: true,
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
            const SizedBox(height: AppSpacing.m),
            for (final source in JournalImportSource.values)
              _SourceTile(
                icon: _sourceIcon(source),
                name: journalImportSourceName(l10n, source),
                hint: _sourceHint(l10n, source),
                onTap: () => Navigator.of(context).pop(source),
              ),
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
        // 说明可能折成多行，图标对齐首行。
        titleAlignment: ListTileTitleAlignment.top,
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

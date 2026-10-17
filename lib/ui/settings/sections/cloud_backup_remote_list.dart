import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/cloud_backup_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/delayed_loading_indicator.dart';

/// 远程备份列表区块。
///
/// 状态：首次读取中（[loading] 且列表为空）显示延迟出现的加载指示；读取
/// 失败显示 [error]；否则显示备份或空状态。数量变化时高度平滑过渡。
class CloudBackupRemoteList extends StatelessWidget {
  const CloudBackupRemoteList({
    super.key,
    required this.backups,
    required this.loading,
    required this.onRestore,
    required this.onDelete,
    this.error,
  });

  final List<CloudBackupEntry> backups;
  final bool loading;
  final String? error;
  final ValueChanged<CloudBackupEntry> onRestore;
  final ValueChanged<CloudBackupEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final Widget body;
    if (loading && backups.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.l),
        child: Center(child: DelayedLoadingIndicator()),
      );
    } else if (error != null && backups.isEmpty) {
      body = Text(
        error!,
        style: mutedStyle?.copyWith(color: colorScheme.error),
      );
    } else if (backups.isEmpty) {
      body = Text(l10n.cloudBackupNoBackups, style: mutedStyle);
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final entry in backups) _tile(context, entry)],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.cloudBackupBackupList, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.s),
        AnimatedSize(
          duration: ExpressiveMotion.durationNonZero(
            context,
            ExpressiveMotion.medium,
          ),
          curve: ExpressiveMotion.effects,
          alignment: Alignment.topCenter,
          child: body,
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, CloudBackupEntry entry) {
    final l10n = context.l10n;
    final time = entry.createdAt ?? entry.updatedAt;
    final subtitle = <String>[
      if (time != null) l10n.cloudBackupBackupTime(_formatDateTime(time)),
      if (entry.size != null)
        l10n.cloudBackupBackupSize(_formatBytes(entry.size!)),
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const FaIcon(FontAwesomeIcons.fileZipper, size: 16),
      title: Text(entry.fileName),
      subtitle: subtitle.isEmpty ? null : Text(subtitle.join(' · ')),
      trailing: Wrap(
        spacing: 2,
        children: <Widget>[
          IconButton(
            tooltip: l10n.cloudBackupRestoreAction,
            onPressed: () => onRestore(entry),
            icon: const FaIcon(FontAwesomeIcons.rotateLeft, size: 14),
          ),
          IconButton(
            tooltip: l10n.cloudBackupDeleteAction,
            onPressed: () => onDelete(entry),
            icon: const FaIcon(FontAwesomeIcons.trashCan, size: 14),
          ),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(1)} GB';
  }

  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

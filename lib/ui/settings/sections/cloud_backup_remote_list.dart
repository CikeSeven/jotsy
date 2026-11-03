import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/cloud_backup_incremental_prune.dart';
import '../../../core/services/cloud_backup_models.dart';
import '../../../core/services/cloud_backup_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../widgets/cloud_backup_labels.dart';

/// 远程备份列表区块：完整备份 ZIP 与增量备份混在一个列表里，按时间新的
/// 在前；增量备份以图层图标与“增量备份”标题区分。
///
/// 状态：首次读取中（[loading] 且列表为空）显示延迟出现的加载指示；读取
/// 失败显示 [error]；否则显示备份或空状态。数量变化时高度平滑过渡。
class CloudBackupRemoteList extends StatelessWidget {
  const CloudBackupRemoteList({
    super.key,
    required this.listing,
    required this.loading,
    required this.onRestore,
    required this.onDelete,
    required this.onRestoreIncremental,
    required this.onDeleteIncremental,
    this.error,
  });

  final CloudBackupListing? listing;
  final bool loading;
  final String? error;
  final ValueChanged<CloudBackupEntry> onRestore;
  final ValueChanged<CloudBackupEntry> onDelete;
  final ValueChanged<IncrementalSnapshotRef> onRestoreIncremental;
  final ValueChanged<IncrementalSnapshotRef> onDeleteIncremental;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final items = _items(listing);
    final Widget body;
    if (loading && items.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.l),
        child: Center(child: DelayedLoadingIndicator()),
      );
    } else if (error != null && items.isEmpty) {
      body = Text(
        error!,
        style: mutedStyle?.copyWith(color: colorScheme.error),
      );
    } else if (items.isEmpty) {
      body = Text(l10n.cloudBackupNoBackups, style: mutedStyle);
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items)
            switch (item) {
              _ZipItem(:final entry) => _zipTile(context, entry),
              _IncrementalItem(:final snapshot) => _incrementalTile(
                context,
                snapshot,
              ),
            },
        ],
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

  static List<_Item> _items(CloudBackupListing? listing) {
    if (listing == null) return const <_Item>[];
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    final items = <_Item>[
      for (final entry in listing.zips)
        _ZipItem(entry, entry.createdAt ?? entry.updatedAt ?? epoch),
      for (final snapshot in listing.incremental.snapshots)
        _IncrementalItem(snapshot),
    ];
    // 稳定排序：时间相同的保持各自原有的先后。
    final indexed = items.indexed.toList()
      ..sort((a, b) {
        final byTime = b.$2.time.compareTo(a.$2.time);
        return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
      });
    return [for (final (_, item) in indexed) item];
  }

  Widget _zipTile(BuildContext context, CloudBackupEntry entry) {
    final l10n = context.l10n;
    final time = entry.createdAt ?? entry.updatedAt;
    final subtitle = <String>[
      if (time != null) l10n.cloudBackupBackupTime(formatCloudBackupTime(time)),
      if (entry.size != null)
        l10n.cloudBackupBackupSize(formatCloudBackupBytes(entry.size!)),
    ];
    return _tile(
      context,
      icon: FontAwesomeIcons.fileZipper,
      title: entry.fileName,
      subtitle: subtitle.isEmpty ? null : subtitle.join(' · '),
      onRestore: () => onRestore(entry),
      onDelete: () => onDelete(entry),
    );
  }

  Widget _incrementalTile(
    BuildContext context,
    IncrementalSnapshotRef snapshot,
  ) {
    final l10n = context.l10n;
    final snap = snapshot.snapshot;
    final subtitle = <String>[
      l10n.cloudBackupBackupTime(formatCloudBackupTime(snapshot.time)),
      if (snap == null)
        l10n.cloudIncrementalEntryMissing
      else if (snap.size != null)
        l10n.cloudBackupBackupSize(formatCloudBackupBytes(snap.size!)),
    ];
    return _tile(
      context,
      icon: FontAwesomeIcons.layerGroup,
      title: l10n.cloudIncrementalEntryTitle,
      subtitle: subtitle.join(' · '),
      onRestore: snap == null ? null : () => onRestoreIncremental(snapshot),
      onDelete: () => onDeleteIncremental(snapshot),
    );
  }

  Widget _tile(
    BuildContext context, {
    required FaIconData icon,
    required String title,
    required String? subtitle,
    required VoidCallback? onRestore,
    required VoidCallback onDelete,
  }) {
    final l10n = context.l10n;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: FaIcon(icon, size: 16),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: Wrap(
        spacing: 2,
        children: <Widget>[
          IconButton(
            tooltip: l10n.cloudBackupRestoreAction,
            onPressed: onRestore,
            icon: const FaIcon(FontAwesomeIcons.rotateLeft, size: 14),
          ),
          IconButton(
            tooltip: l10n.cloudBackupDeleteAction,
            onPressed: onDelete,
            icon: const FaIcon(FontAwesomeIcons.trashCan, size: 14),
          ),
        ],
      ),
    );
  }
}

sealed class _Item {
  const _Item();

  DateTime get time;
}

class _ZipItem extends _Item {
  const _ZipItem(this.entry, this.time);

  final CloudBackupEntry entry;

  @override
  final DateTime time;
}

class _IncrementalItem extends _Item {
  const _IncrementalItem(this.snapshot);

  final IncrementalSnapshotRef snapshot;

  @override
  DateTime get time => snapshot.time;
}

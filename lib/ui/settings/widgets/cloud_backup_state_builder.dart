import 'package:flutter/material.dart';

import '../../../core/services/cloud_backup_incremental_state.dart';
import '../../../core/services/cloud_backup_service.dart';
import '../../../l10n/app_localizations.dart';
import 'cloud_backup_labels.dart';

/// 按备份位置读取增量备份的本机状态并跟随更新（自动备份写入状态后
/// [CloudBackupLocalState.revision] 递增，这里重新读取）。
class CloudBackupTargetStateBuilder extends StatefulWidget {
  const CloudBackupTargetStateBuilder({
    super.key,
    required this.service,
    required this.targetId,
    required this.builder,
  });

  final CloudBackupService service;
  final String targetId;
  final Widget Function(BuildContext context, CloudBackupTargetState state)
  builder;

  @override
  State<CloudBackupTargetStateBuilder> createState() =>
      _CloudBackupTargetStateBuilderState();
}

class _CloudBackupTargetStateBuilderState
    extends State<CloudBackupTargetStateBuilder> {
  CloudBackupLocalState? _localState;
  CloudBackupTargetState _state = const CloudBackupTargetState();

  @override
  void initState() {
    super.initState();
    widget.service.localState().then((state) {
      if (!mounted) return;
      _localState = state;
      state.revision.addListener(_reload);
      _reload();
    });
  }

  @override
  void dispose() {
    _localState?.revision.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final state = await widget.service.readTargetState(widget.targetId);
    if (mounted) setState(() => _state = state);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _state);
}

/// 备份位置列表里的一行自动备份状态：只在开着自动备份、且已自动备份过时
/// 显示；失败与“需要手动备份”用 error 色。
class CloudAutoBackupTileStatus extends StatelessWidget {
  const CloudAutoBackupTileStatus({
    super.key,
    required this.service,
    required this.targetId,
  });

  final CloudBackupService service;
  final String targetId;

  @override
  Widget build(BuildContext context) {
    return CloudBackupTargetStateBuilder(
      service: service,
      targetId: targetId,
      builder: (context, state) {
        final status = state.lastAuto;
        final target = service.targets.targetById(targetId);
        if (status == null || target == null || !target.options.autoBackup) {
          return const SizedBox.shrink();
        }
        final l10n = context.l10n;
        final colorScheme = Theme.of(context).colorScheme;
        final (text, warn) = switch (status.outcome) {
          CloudAutoBackupOutcome.uploaded ||
          CloudAutoBackupOutcome.unchanged => (
            l10n.cloudAutoBackupTileOk(formatCloudBackupTime(status.at)),
            false,
          ),
          CloudAutoBackupOutcome.needsManual => (
            l10n.cloudAutoBackupTileNeedsManual,
            true,
          ),
          CloudAutoBackupOutcome.failed => (
            l10n.cloudAutoBackupTileFailed,
            true,
          ),
        };
        return Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: warn ? colorScheme.error : colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }
}

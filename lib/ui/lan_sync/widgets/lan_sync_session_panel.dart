import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../models/lan_sync_session_view.dart';
import 'lan_sync_labels.dart';

/// 正在同步的设备卡片里、行下方展开的会话面板。
///
/// 目前只显示阶段文字；连线跑道、阶段条与媒体进度（DESIGN.md §5.27“同步中”）
/// 由后续任务在这个组件里补齐，卡片的边框与展开动画不变。读屏读出阶段。
class LanSyncSessionPanel extends StatelessWidget {
  const LanSyncSessionPanel({super.key, required this.session});

  final LanSyncSessionView session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Semantics(
        liveRegion: true,
        child: Text(
          lanSyncStageLabel(context.l10n, session.stage),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

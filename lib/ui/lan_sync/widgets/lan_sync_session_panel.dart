// 正在同步的设备卡片里、行下方展开的会话面板（DESIGN.md §5.28“同步中”）：
// 连线面板 + 计数 → 阶段条 → 进度区。同步页的设备卡片与设备详情页共用。
//
// 跑道是否流动（见 [lanSyncLaneActivity]）：连接与比对阶段两边都在交换清单，
// 两条跑道都流动；从传输阶段起只有确实有日记在那个方向上传的跑道流动，
// 另一条静止变淡（DESIGN“没有该方向的数据时那条跑道静止变淡”）。
//
// 读屏：连线面板是装饰；阶段条与进度区合成一句“阶段，已完成 N%”（没有
// 媒体进度时只读阶段），挂 liveRegion，阶段或百分比变化时读出。

import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../models/lan_sync_platform.dart';
import '../models/lan_sync_session_view.dart';
import 'lan_sync_flow_panel.dart';
import 'lan_sync_labels.dart';
import 'lan_sync_session_progress.dart';
import 'lan_sync_stage_bar.dart';

/// 两条跑道是否流动：返回（发送, 接收）。
({bool sending, bool receiving}) lanSyncLaneActivity(
  LanSyncSessionView session,
) {
  if (session.stage.index < LanSyncSessionStage.transferring.index) {
    return (sending: true, receiving: true);
  }
  return (
    sending: session.sentDiaries > 0,
    receiving: session.receivedDiaries > 0,
  );
}

class LanSyncSessionPanel extends StatelessWidget {
  const LanSyncSessionPanel({
    super.key,
    required this.session,
    required this.localPlatform,
    required this.peerPlatform,
    required this.peerName,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
  });

  final LanSyncSessionView session;
  final LanSyncPlatform localPlatform;
  final LanSyncPlatform peerPlatform;

  /// 对方的显示名（备注名优先）。
  final String peerName;

  /// 设备卡片里行下方左右 16、底部 16；设备详情页的英雄卡自带内边距。
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lanes = lanSyncLaneActivity(session);
    final stage = lanSyncStageLabel(l10n, session.stage);
    final progress = session.mediaProgress;
    final semantics = lanSyncShowsMediaProgress(session) && progress != null
        ? l10n.lanSyncSessionSemantics(stage, (progress * 100).floor())
        : stage;
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LanSyncFlowPanel(
            localPlatform: localPlatform,
            peerPlatform: peerPlatform,
            peerName: peerName,
            sent: session.sentDiaries,
            received: session.receivedDiaries,
            sending: lanes.sending,
            receiving: lanes.receiving,
          ),
          const SizedBox(height: 18),
          Semantics(
            container: true,
            liveRegion: true,
            label: semantics,
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  LanSyncStageBar(stage: session.stage),
                  const SizedBox(height: 18),
                  LanSyncSessionProgress(session: session),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

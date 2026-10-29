// “我的设备”分组：已配对的设备按控制器给出的顺序排列。
//
// 不在同步的相邻设备合在一张分组卡片里（行间细线缩进到文字起点）；正在
// 同步的设备单独成一张卡片：边框换成 1.5dp `primary` 55%，行下方的会话面板
// 在卡片出现时从 0 高度展开并淡入（`ListItemPresence`，`medium`）。会话结束后
// 设备回到分组卡片里。卡片按 deviceId 带 key，状态变化时不串到别的设备上。

import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../widgets/list_item_presence.dart';
import '../models/lan_sync_platform.dart';
import '../models/lan_sync_view_state.dart';
import '../widgets/lan_sync_device_row.dart';
import '../widgets/lan_sync_peer_row.dart';
import '../widgets/lan_sync_section_header.dart';
import '../widgets/lan_sync_session_panel.dart';

class LanSyncPairedSection extends StatelessWidget {
  const LanSyncPairedSection({
    super.key,
    required this.peers,
    required this.localPlatform,
    required this.now,
    required this.onSync,
    required this.onCancel,
    required this.onReview,
    this.onOpen,
  });

  final List<LanSyncPeerView> peers;

  /// 本机平台（会话面板左侧“本机”的图标）。
  final LanSyncPlatform localPlatform;
  final DateTime now;
  final ValueChanged<String> onSync;
  final ValueChanged<String> onCancel;
  final ValueChanged<String> onReview;

  /// 点按设备行（进入设备详情页）；null 时行不可点。
  final ValueChanged<String>? onOpen;

  Widget _row(LanSyncPeerView peer) {
    final onOpen = this.onOpen;
    return LanSyncPeerRow(
      key: ValueKey<String>('lanSyncPeer:${peer.deviceId}'),
      peer: peer,
      now: now,
      onSync: () => onSync(peer.deviceId),
      onCancel: () => onCancel(peer.deviceId),
      onReview: () => onReview(peer.deviceId),
      onOpen: onOpen == null ? null : () => onOpen(peer.deviceId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[];
    var group = <LanSyncPeerView>[];
    void flushGroup() {
      if (group.isEmpty) return;
      final members = group;
      cards.add(
        AppCardSurface(
          key: ValueKey<String>('lanSyncGroup:${members.first.deviceId}'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (var i = 0; i < members.length; i++) ...<Widget>[
                if (i > 0)
                  const SettingsCardGroupDivider(
                    indent: LanSyncDeviceRow.textStart,
                  ),
                _row(members[i]),
              ],
            ],
          ),
        ),
      );
      group = <LanSyncPeerView>[];
    }

    for (final peer in peers) {
      final session = peer.session;
      if (session == null) {
        group.add(peer);
        continue;
      }
      flushGroup();
      cards.add(
        _SessionCard(
          key: ValueKey<String>('lanSyncSession:${peer.deviceId}'),
          row: _row(peer),
          panel: LanSyncSessionPanel(
            session: session,
            localPlatform: localPlatform,
            peerPlatform: peer.platform,
            peerName: peer.displayName,
          ),
        ),
      );
    }
    flushGroup();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LanSyncSectionHeader(
          title: context.l10n.lanSyncSectionMyDevices,
          trailing: Text(
            context.l10n.lanSyncDeviceCount(peers.length),
            style: LanSyncSectionHeader.trailingStyle(context),
          ),
        ),
        for (var i = 0; i < cards.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 12),
          cards[i],
        ],
      ],
    );
  }
}

/// 正在同步的设备卡片：1.5dp `primary` 55% 边框 + 行下方展开的会话面板。
///
/// 边框画在前景（foregroundDecoration）上，经典与玻璃两种卡片都一样；经典
/// 卡片自己的 0.8dp 微边框随之关掉，不叠两道线。
class _SessionCard extends StatelessWidget {
  const _SessionCard({super.key, required this.row, required this.panel});

  final Widget row;
  final Widget panel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const radius = BorderRadius.all(Radius.circular(AppRadii.card));
    return Container(
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.55),
          width: 1.5,
        ),
      ),
      child: AppCardSurface(
        border: BorderSide.none,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            row,
            ListItemPresence(
              visible: true,
              appearing: true,
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.medium,
              ),
              child: panel,
            ),
          ],
        ),
      ),
    );
  }
}

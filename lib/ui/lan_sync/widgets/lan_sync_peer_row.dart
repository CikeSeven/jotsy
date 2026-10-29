// 已配对设备的一行（DESIGN.md §5.27 设备行）。副标题与尾部按状态切换，
// 优先级从高到低：
// 1. 正在同步：副标题为 `primary` w600 阶段文字，尾部灰色文本“取消”；
// 2. 需要确认：副标题为 `error` 色“需要你确认”，尾部色调按钮“查看”；
// 3. 在线：`primary` w600“在线” + “· X 前已同步”，尾部色调按钮“同步”；
// 4. 离线：“离线 · X 前已同步”，尾部 `angleRight` 14。

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../models/lan_sync_view_state.dart';
import 'lan_sync_device_row.dart';
import 'lan_sync_device_tile.dart';
import 'lan_sync_labels.dart';

class LanSyncPeerRow extends StatelessWidget {
  const LanSyncPeerRow({
    super.key,
    required this.peer,
    required this.now,
    required this.onSync,
    required this.onCancel,
    required this.onReview,
    this.onOpen,
  });

  final LanSyncPeerView peer;

  /// 换算“X 前”的当前时间（由页面在构建时给出，测试可固定）。
  final DateTime now;
  final VoidCallback onSync;
  final VoidCallback onCancel;
  final VoidCallback onReview;

  /// 点按整行进入设备详情页；null 时整行不可点。
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final session = peer.session;
    final lastSync = lanSyncLastSyncLabel(l10n, peer.lastSyncAt, now);
    const emphasis = FontWeight.w600;

    final InlineSpan subtitle;
    final Widget trailing;
    if (session != null) {
      subtitle = TextSpan(
        text: lanSyncStageLabel(l10n, session.stage),
        style: TextStyle(color: colors.primary, fontWeight: emphasis),
      );
      trailing = TextButton(
        style: TextButton.styleFrom(foregroundColor: colors.onSurfaceVariant),
        onPressed: onCancel,
        child: Text(l10n.commonCancel),
      );
    } else if (peer.needsAttention) {
      subtitle = TextSpan(
        text: l10n.lanSyncNeedsAttention,
        style: TextStyle(color: colors.error, fontWeight: emphasis),
      );
      trailing = LanSyncRowButton(
        label: l10n.lanSyncReview,
        onPressed: onReview,
      );
    } else if (peer.online) {
      subtitle = TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: l10n.lanSyncOnline,
            style: TextStyle(color: colors.primary, fontWeight: emphasis),
          ),
          TextSpan(text: ' · $lastSync'),
        ],
      );
      trailing = LanSyncRowButton(
        label: l10n.lanSyncSyncButton,
        icon: const FaIcon(FontAwesomeIcons.arrowsRotate, size: 16),
        onPressed: onSync,
      );
    } else {
      subtitle = TextSpan(text: '${l10n.lanSyncOffline} · $lastSync');
      trailing = FaIcon(
        FontAwesomeIcons.angleRight,
        size: 14,
        color: colors.onSurfaceVariant,
      );
    }

    return LanSyncDeviceRow(
      tile: LanSyncDeviceTile(platform: peer.platform, active: peer.online),
      title: peer.displayName,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onOpen,
    );
  }
}

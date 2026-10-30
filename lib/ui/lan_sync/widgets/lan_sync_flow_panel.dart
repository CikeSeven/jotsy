// 会话面板顶部的连线面板（DESIGN.md §5.28“同步中”）：左“本机”、右对方，
// 中间两条跑道；面板下方居中两组计数“↑ 发送 N 篇 / ↓ 接收 N 篇”。
//
// 凹槽底色经 [lanSyncWellColor]（暗色卡片本身就是 surfaceContainerLow，字面
// 取它会看不见）；两端设备块是“卡片色”，经 `ExpressiveSurfaces.cardColor`。
// 设备块与跑道是装饰，读屏不读；计数照常读出。

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_surfaces.dart';
import '../models/lan_sync_platform.dart';
import 'lan_sync_flow_lanes.dart';
import 'lan_sync_labels.dart';
import 'lan_sync_well_color.dart';

class LanSyncFlowPanel extends StatelessWidget {
  const LanSyncFlowPanel({
    super.key,
    required this.localPlatform,
    required this.peerPlatform,
    required this.peerName,
    required this.sent,
    required this.received,
    required this.sending,
    required this.receiving,
  });

  final LanSyncPlatform localPlatform;
  final LanSyncPlatform peerPlatform;
  final String peerName;

  /// 已发出 / 已收到的日记篇数。
  final int sent;
  final int received;

  /// 两条跑道是否流动（由会话面板按阶段与计数判断）。
  final bool sending;
  final bool receiving;

  static const double _block = 52;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    final counterStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: lanSyncWellColor(context),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _DeviceBlock(
                  platform: localPlatform,
                  label: l10n.lanSyncFlowLocal,
                ),
                Expanded(
                  child: SizedBox(
                    height: _block,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Center(
                        child: LanSyncFlowLanes(
                          sending: sending,
                          receiving: receiving,
                        ),
                      ),
                    ),
                  ),
                ),
                _DeviceBlock(platform: peerPlatform, label: peerName),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 18,
          runSpacing: 4,
          children: <Widget>[
            Text(
              l10n.lanSyncFlowSent(sent),
              style: counterStyle?.copyWith(color: colors.primary),
            ),
            Text(
              l10n.lanSyncFlowReceived(received),
              style: counterStyle?.copyWith(color: colors.tertiary),
            ),
          ],
        ),
      ],
    );
  }
}

/// 52dp 18 圆角卡片色图标块 + 12 / w600 灰色标签（名称过长时省略）。
class _DeviceBlock extends StatelessWidget {
  const _DeviceBlock({required this.platform, required this.label});

  final LanSyncPlatform platform;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SizedBox(
      width: 72,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: LanSyncFlowPanel._block,
            height: LanSyncFlowPanel._block,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ExpressiveSurfaces.cardColor(colors),
              borderRadius: BorderRadius.circular(18),
            ),
            child: FaIcon(
              lanSyncPlatformIcon(platform),
              size: 22,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

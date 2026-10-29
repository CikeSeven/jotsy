import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../lan_sync/models/lan_sync_view_state.dart';
import '../../lan_sync/pages/lan_sync_page.dart';
import '../../lan_sync/providers/lan_sync_providers.dart';
import '../../lan_sync/widgets/lan_sync_labels.dart';

/// 设置 → 数据与隐私里的“局域网同步”入口（DESIGN.md §5.27）。
///
/// 副标题随同步状态：有同步等待确认时为 `error` 色“有一次同步需要你确认”；
/// 已配对时为“已配对 N 台 · X 前已同步”（都没同步过为“还没有同步过”）；
/// 否则为一句功能说明。是否显示（`AppPlatform.supportsLanSync`）由调用方决定。
class SettingsLanSyncTile extends ConsumerWidget {
  const SettingsLanSyncTile({super.key, this.clock = DateTime.now});

  /// 换算“X 前”用的当前时间；测试可固定。
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.watch(lanSyncControllerProvider);
    return ValueListenableBuilder<LanSyncViewState>(
      valueListenable: controller.state,
      builder: (BuildContext context, LanSyncViewState state, Widget? child) {
        final colors = Theme.of(context).colorScheme;
        final String subtitle;
        TextStyle? subtitleStyle;
        if (state.needsAttention) {
          subtitle = l10n.lanSyncEntrySubtitleAttention;
          subtitleStyle = TextStyle(color: colors.error);
        } else if (state.peers.isEmpty) {
          subtitle = l10n.lanSyncEntrySubtitleUnpaired;
        } else {
          final last = state.lastSyncAt;
          subtitle = last == null
              ? l10n.lanSyncEntrySubtitlePairedNever(state.peers.length)
              : l10n.lanSyncEntrySubtitlePaired(
                  state.peers.length,
                  lanSyncRelativeTime(l10n, last, clock()),
                );
        }
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: const FaIcon(FontAwesomeIcons.wifi, size: 16),
          title: Text(l10n.lanSyncTitle),
          subtitle: Text(subtitle, style: subtitleStyle),
          trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const LanSyncPage(),
              ),
            );
          },
        );
      },
    );
  }
}
